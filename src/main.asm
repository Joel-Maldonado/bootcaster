; Stage 2: entered from the boot sector with CS = DS = ES = SS = 0.

MAX_FRAME_MS equ 50             ; after a stall, don't teleport

main:
    call make_sin_table
    call video_init
    call keyboard_init
    call timer_init
.frame:
    ; Milliseconds since the last frame, so movement doesn't depend on
    ; how fast this machine draws.
    mov eax, [ticks]
    mov edx, eax
    sub eax, [last_tick]
    mov [last_tick], edx
    cmp eax, MAX_FRAME_MS
    jbe .have_dt
    mov eax, MAX_FRAME_MS
.have_dt:
    mov [frame_ms], ax

    call handle_input
    call render
    call present

%ifdef STATS
    inc dword [frames]
    mov eax, [ticks]
    sub eax, [stat_since]
    cmp eax, TICK_HZ
    jb .frame
    add [stat_since], eax
    mov eax, [frames]
    mov si, msg_fps
    call stat_print
    mov eax, [stat_steps]
    mov si, msg_steps
    call stat_print
    mov dword [frames], 0
%endif
    jmp .frame

player_x:     dd (2 << 16) + 0x8000     ; 2.5 tiles
player_y:     dd (2 << 16) + 0x8000
player_angle: dw 0                      ; facing +x
last_tick:    dd 0
frame_ms:     dw 0

%ifdef STATS
frames:     dd 0
stat_since: dd 0
stat_steps: dd 0                        ; ray steps in the last frame
msg_fps:    db "frames in the last second: ", 0
msg_steps:  db "ray steps per frame: ", 0
%endif

%include "stats.asm"
%include "video.asm"
%include "math.asm"
%include "map.asm"
%include "raycast.asm"
%include "input.asm"
%include "timer.asm"
