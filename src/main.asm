; Stage 2: entered from the boot sector with CS = DS = ES = SS = 0.

main:
    call make_sin_table
    call video_init
.frame:
    call handle_input
    call render
    call present
    jmp .frame

player_x:     dd (2 << 16) + 0x8000     ; 2.5 tiles
player_y:     dd (2 << 16) + 0x8000
player_angle: dw 0                      ; facing +x

%include "video.asm"
%include "math.asm"
%include "map.asm"
%include "raycast.asm"
%include "input.asm"
