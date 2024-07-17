; note: we use 24.8 fixed point numbers frequently

const BLUE: 0xFF996644 ; a nice blue
const SPRITE_OFFSET_X: 16
const SPRITE_OFFSET_Y: 30
const NEKO_SPEED: 13
const OVERLAY: 28
const AWAKE_LENGTH: 8
const UNCHILL_DIST_SQ: 49

neko_entry:
    ; create neko overlay. if it already exists, then exit
    mov r0, OVERLAY
    mov r2, 0x80000300
    add r2, r0
    icl ; start critical section: claiming overlay and adding vsync callback
    in r1, r2
    cmp r1, 0
    ifnz ise
    ifnz call end_current_task
    call enable_overlay
    mov r0, 32
    mov r1, 32
    mov r2, OVERLAY
    call resize_overlay
    mov [PREV_VSYNC], [0x3FC]
    mov [0x3FC], neko_vsync
    ise ; end critical section
neko_loop:
    ; only run every 8 frames
    mov r0, [EVERY_N_FRAMES]
    sub r0, 1
    cmp r0, 0
    ifz mov r0, 8
    mov [EVERY_N_FRAMES], r0
    ifnz rjmp neko_loop_end
    mov r0, [NEKO_STATE]
    cmp r0, 0
    ifz rjmp run_awake_neko
    cmp r0, 1
    ifz rjmp run_move_neko
    rjmp run_chill_neko

set_awake:
    mov [NEKO_STATE], 0
    mov [STATE_FRAME], AWAKE_LENGTH
run_awake_neko:
    sub [STATE_FRAME], 1
    cmp [STATE_FRAME], 0
    ifz rjmp set_move
draw_awake_neko:
    mov r0, sprite_awake
    rjmp draw_neko

set_move:
    mov [NEKO_STATE], 1
    mov r0, sprite_awake
    rjmp draw_neko
    
run_move_neko:
    xor [STATE_FRAME], 1
    ; get distance from neko to mouse
    call get_mouse_position
    sla r0, 8
    sla r1, 8
    sub r0, [NEKO_X]
    sub r1, [NEKO_Y]
    ; calculate sprite angle
    mov r5, 0
    ; separate R, UR, U, UL from L, DL, D, DR
    mov r4, r0
    sra r4, 1
    sub r4, r1
    cmp r4, 0x80000000
    ifgteq add r5, 4
    ; separate R, UR, L, DL from U, UL, D, DR
    mov r4, r0
    sla r4, 1
    add r4, r1
    cmp r4, 0x80000000
    ifgteq add r5, 2
    ; separate R, U, L, D from UR, UL, DL, DR
    mov r4, r0
    sla r4, 1
    sub r4, r1
    sra r4, 4
    mov r6, r0
    sra r6, 1
    add r6, r1
    sra r6, 4
    imul r4, r6
    cmp r4, 0x80000000
    ifgteq add r5, 1
    ; calculate distance
    mov r2, r0
    mov r3, r1
    sra r2, 4
    sra r3, 4
    imul r2, r2
    imul r3, r3
    add r2, r3
    ; estimate square root
    mov r3, r2
    sra r3, 1
    mov r31, 20
    ; rjmp sqrt_end
sqrt:
    cmp r3, 0
    ifz rjmp set_chill
    mov r4, r2
    idiv r4, r3
    sla r4, 8
    add r4, r3
    sra r4, 1
    mov r3, r4
    loop sqrt
move_neko:
    div r2, r3
    div r2, NEKO_SPEED
    cmp r2, 0
    ifz rjmp set_chill
    idiv r0, r2
    idiv r1, r2
    mov r2, [NEKO_X]
    mov r3, [NEKO_Y]
    add r2, r0
    add r3, r1
    ; check if sprite going off screen
    mov r11, 0
    mov r12, r2
    sra r12, 8
    sub r12, SPRITE_OFFSET_X
    add r12, 32
    cmp r12, 640
    ifgteq mov r12, 640
    ifgteq add r12, SPRITE_OFFSET_X
    ifgteq sub r12, 32
    ifgteq sla r12, 8
    ifgteq mov r2, r12
    ifgteq or r11, 1
    mov r12, r2
    sra r12, 8
    cmp r12, SPRITE_OFFSET_X
    iflt mov r12, SPRITE_OFFSET_X
    iflt sla r12, 8
    iflt mov r2, r12
    iflt or r11, 1
    mov r13, r3
    sra r13, 8
    sub r13, 46 ; SPRITE_OFFSET_Y + 16 (height of menubar)
    cmp r13, 0x80000000
    ifgteq mov r13, 46
    ifgteq sla r13, 8
    ifgteq mov r3, r13
    ifgteq or r11, 2
    imul r0, r0 ; poor man's absolute value
    imul r1, r1
    cmp r0, 0x00010000
    iflt or r11, 1
    cmp r1, 0x00010000
    iflt or r11, 2
    cmp r11, 3
    ifz rjmp set_chill
    mov [NEKO_X], r2
    mov [NEKO_Y], r3
draw_move_neko:
    ; switch sprite
    mov r0, r5
    mul r0, 0x2000
    add r0, sprite_move
    ; alternate sprites per frame
    cmp [STATE_FRAME], 0
    ifz add r0, 0x1000
    rjmp draw_neko

set_chill:
    ; teleport neko to mouse
    call get_mouse_position
    mov [PMOUSE_X], r0
    mov [PMOUSE_Y], r1
    cmp r0, SPRITE_OFFSET_X
    iflt mov r0, SPRITE_OFFSET_X
    cmp r0, 624 ; 640 - 32 + SPRITE_OFFSET_X
    ifgt mov r0, 624
    cmp r1, 46 ; SPRITE_OFFSET_Y + menubar
    iflt mov r1, 46
    cmp r1, 480 ; 480 - 32 + SPRITE_OFFSET_Y
    ifgt mov r1, 480
    sla r0, 8
    sla r1, 8
    mov [NEKO_X], r0
    mov [NEKO_Y], r1
    mov [NEKO_STATE], 2
    mov [STATE_FRAME], 0xFFFFFFFF
    rjmp draw_chill_neko

run_chill_neko:
    call get_mouse_position
    push r1
    push r0
    sub r0, [PMOUSE_X]
    sub r1, [PMOUSE_Y]
    imul r0, r0
    imul r1, r1
    add r0, r1
    cmp r0, UNCHILL_DIST_SQ
    ifgteq rjmp set_awake
    pop r0
    pop r1
    mov [PMOUSE_X], r0
    mov [PMOUSE_Y], r1
draw_chill_neko:
    mov r1, [STATE_FRAME]
    add r1, 1
    mov [STATE_FRAME], r1
    cmp r1, 48
    ifgteq rjmp draw_chill_sleep_neko
    cmp r1, 36
    ifgteq mov r0, sprite_yawn2
    ifgteq rjmp draw_neko
    cmp r1, 8
    iflt mov r0, sprite_yawn1
    iflt rjmp draw_neko
    mov r0, r1
    and r0, 1
    sla r0, 12
    cmp r1, 28
    ifgteq add r0, sprite_scratch
    ifgteq rjmp draw_neko
    ; wash or claw
    mov r2, [NEKO_X]
    sra r2, 8
    cmp r2, 624 ; 640 - 32 + SPRITE_OFFSET_X
    ifgteq mov r1, sprite_claw_right
    ifgteq rjmp draw_chill_neko_done
    cmp r2, SPRITE_OFFSET_X
    iflteq mov r1, sprite_claw_left
    iflteq rjmp draw_chill_neko_done
    mov r2, [NEKO_Y]
    sra r2, 8
    cmp r2, 46 ; SPRITE_OFFSET_Y + menubar
    iflteq mov r1, sprite_claw_up
    iflteq rjmp draw_chill_neko_done
    cmp r2, 479 ; 480 + 32 - SPRITE_OFFSET_Y - 2?
    ifgteq mov r1, sprite_claw_down
    ifgteq rjmp draw_chill_neko_done
    mov r1, sprite_wash
draw_chill_neko_done:
    add r0, r1
    rjmp draw_neko
draw_chill_sleep_neko:
    ; keep from overflowing STATE_FRAME, for posterity
    cmp r1, 64
    ifgteq sub [STATE_FRAME], 8
    mov r0, sprite_sleep
    mov r3, r1
    and r3, 4
    sla r3, 10
    add r0, r3
    rjmp draw_neko
draw_neko:
    mov r1, OVERLAY
    call set_overlay_framebuffer_pointer
    ; move overlay
    mov r0, [NEKO_X]
    mov r1, [NEKO_Y]
    sra r0, 8
    sra r1, 8
    sub r0, SPRITE_OFFSET_X
    sub r1, SPRITE_OFFSET_Y
    mov r2, OVERLAY
    call move_overlay
neko_loop_end:
    mov [HIT_VSYNC], 0
wait_loop:
    call yield_task
    cmp [HIT_VSYNC], 0
    ifnz rjmp neko_loop
    rjmp wait_loop

neko_vsync:
    mov [HIT_VSYNC], 1
    jmp [PREV_VSYNC]

PREV_VSYNC: data.32 0
HIT_VSYNC: data.32 0
FRAME_COUNTER: data.32 0
NEKO_X: data.32 0x00014000 ; x = 320
NEKO_Y: data.32 0x0000F000 ; y = 240
PMOUSE_X: data.32 0
PMOUSE_Y: data.32 0
NEKO_STATE: data.32 0
; 0 - awake
; 1 - move
; 2 - chill
STATE_FRAME: data.32 AWAKE_LENGTH
EVERY_N_FRAMES: data.32 1

    #include "../../fox32rom/fox32rom.def"
    #include "../../fox32os/fox32os.def"

sprite_awake:
    #include "assets_asm/awake.asm"

sprite_yawn1:
    #include "assets_asm/yawn1.asm"
    
sprite_wash:
    #include "assets_asm/wash1.asm"
    #include "assets_asm/wash2.asm"

sprite_claw_right:
    #include "assets_asm/rightclaw1.asm"
    #include "assets_asm/rightclaw2.asm"
sprite_claw_up:
    #include "assets_asm/upclaw1.asm"
    #include "assets_asm/upclaw2.asm"
sprite_claw_left:
    #include "assets_asm/leftclaw1.asm"
    #include "assets_asm/leftclaw2.asm"
sprite_claw_down:
    #include "assets_asm/downclaw1.asm"
    #include "assets_asm/downclaw2.asm"
    
sprite_scratch:
    #include "assets_asm/scratch1.asm"
    #include "assets_asm/scratch2.asm"

sprite_yawn2:
    #include "assets_asm/yawn2.asm"

sprite_sleep:
    #include "assets_asm/sleep1.asm"
    #include "assets_asm/sleep2.asm"

sprite_move:
    #include "assets_asm/right1.asm"
    #include "assets_asm/right2.asm"
    #include "assets_asm/upright1.asm"
    #include "assets_asm/upright2.asm"
    #include "assets_asm/upleft1.asm"
    #include "assets_asm/upleft2.asm"
    #include "assets_asm/up1.asm"
    #include "assets_asm/up2.asm"
    #include "assets_asm/downright1.asm"
    #include "assets_asm/downright2.asm"
    #include "assets_asm/down1.asm"
    #include "assets_asm/down2.asm"
    #include "assets_asm/left1.asm"
    #include "assets_asm/left2.asm"
    #include "assets_asm/downleft1.asm"
    #include "assets_asm/downleft2.asm"
