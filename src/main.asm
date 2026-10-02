; Stage 2: entered from the boot sector with CS = DS = ES = SS = 0.

main:
    call make_sin_table
    call video_init
.frame:
    call handle_input
    call render
    call present
%ifdef STATS
    inc word [frames]
    test word [frames], 63      ; report every 64th frame
    jnz .frame
    mov eax, [stat_steps]
    mov si, msg_steps
    call stat_print
%endif
    jmp .frame

player_x:     dd (2 << 16) + 0x8000     ; 2.5 tiles
player_y:     dd (2 << 16) + 0x8000
player_angle: dw 0                      ; facing +x

%ifdef STATS
frames:     dw 0
stat_steps: dd 0                        ; ray steps in the last frame
msg_steps:  db "ray steps per frame: ", 0
%endif

%include "stats.asm"
%include "video.asm"
%include "math.asm"
%include "map.asm"
%include "raycast.asm"
%include "input.asm"
