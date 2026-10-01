; Keyboard through the BIOS: INT 16h hands us one keystroke at a time from its
; buffer. Arrow keys turn and walk.

TURN_STEP equ 1024              ; about 5.6 degrees
MOVE_STEP equ 0x2000            ; 1/8 of a tile

handle_input:
.next_key:
    mov ah, 0x01                ; is a key waiting?
    int 0x16
    jz .done
    xor ah, ah                  ; take it: AH = scan code
    int 0x16
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp ah, 0x48
    je .forward
    cmp ah, 0x50
    je .back
    jmp .next_key
.left:
    sub word [player_angle], TURN_STEP
    jmp .next_key
.right:
    add word [player_angle], TURN_STEP
    jmp .next_key
.forward:
    mov ebx, MOVE_STEP
    call move_player
    jmp .next_key
.back:
    mov ebx, -MOVE_STEP
    call move_player
    jmp .next_key
.done:
    ret

; Move EBX tiles along the view direction, unless that lands inside a wall.
move_player:
    mov si, [player_angle]
    call sin_cos
    push edx
    call fixmul                 ; EAX = cos * distance
    mov esi, [player_x]
    add esi, eax
    pop eax
    call fixmul                 ; EAX = sin * distance
    mov edi, [player_y]
    add edi, eax
    call map_index
    cmp byte [map + bx], 0
    jne .blocked
    mov [player_x], esi
    mov [player_y], edi
.blocked:
    ret
