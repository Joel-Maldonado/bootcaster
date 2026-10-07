; Keyboard. The BIOS (INT 16h) only hands over keystrokes: no key-up events,
; and a held key repeats at the typematic rate after a delay, one key at a
; time. To walk and turn at once we need to know which keys are down right
; now, so we take over IRQ 1 and read scan codes from the keyboard
; controller ourselves.

KEY_ESC   equ 0x01
KEY_W     equ 0x11
KEY_A     equ 0x1E
KEY_S     equ 0x1F
KEY_D     equ 0x20
KEY_UP    equ 0x48
KEY_LEFT  equ 0x4B
KEY_RIGHT equ 0x4D
KEY_DOWN  equ 0x50

TURN_SPEED equ 256              ; binary angle per frame, about 1.4 degrees
MOVE_SPEED equ 0x0800           ; 1/32 of a tile per frame
RADIUS     equ 0x4000           ; stay a quarter tile away from walls

keyboard_init:
    cli
    mov word [9 * 4], keyboard_irq      ; IRQ 1 is interrupt vector 9
    mov word [9 * 4 + 2], 0
    sti
    ret

; Each key sends its scan code when pressed and the same code with bit 7 set
; when released. Arrow keys send an 0xE0 prefix first, which we skip: the
; byte after it matches the keypad key in the same spot.
keyboard_irq:
    push ax
    push bx
    in al, 0x60
    cmp al, 0xE0
    je .done
    xor bx, bx
    mov bl, al
    and bl, 0x7F
    shr al, 7
    xor al, 1                   ; 1 = down, 0 = up
    mov [cs:keys + bx], al
.done:
    mov al, 0x20
    out 0x20, al                ; tell the interrupt controller we're done
    pop bx
    pop ax
    iret

handle_input:
    cmp byte [keys + KEY_ESC], 0
    jne reboot

    cmp byte [keys + KEY_LEFT], 0
    je .not_left
    sub word [player_angle], TURN_SPEED
.not_left:
    cmp byte [keys + KEY_RIGHT], 0
    je .not_right
    add word [player_angle], TURN_SPEED
.not_right:

    xor ebx, ebx                ; forward speed
    xor ecx, ecx                ; sideways speed
    mov al, [keys + KEY_W]
    or al, [keys + KEY_UP]
    jz .not_forward
    add ebx, MOVE_SPEED
.not_forward:
    mov al, [keys + KEY_S]
    or al, [keys + KEY_DOWN]
    jz .not_back
    sub ebx, MOVE_SPEED
.not_back:
    cmp byte [keys + KEY_D], 0
    je .not_right_strafe
    add ecx, MOVE_SPEED
.not_right_strafe:
    cmp byte [keys + KEY_A], 0
    je .not_left_strafe
    sub ecx, MOVE_SPEED
.not_left_strafe:

    ; Walk along the view direction (cos, sin) and strafe along the
    ; direction to its right (-sin, cos).
    mov si, [player_angle]
    call sin_cos
    mov [.cos], eax
    mov [.sin], edx
    call fixmul
    mov [.move_x], eax          ; cos * forward
    mov eax, [.sin]
    call fixmul
    mov [.move_y], eax          ; sin * forward
    mov ebx, ecx
    mov eax, [.sin]
    neg eax
    call fixmul
    add [.move_x], eax          ; - sin * sideways
    mov eax, [.cos]
    call fixmul
    add [.move_y], eax          ; + cos * sideways
    mov eax, [.move_x]
    mov edx, [.move_y]
    jmp try_move
.cos:    dd 0
.sin:    dd 0
.move_x: dd 0
.move_y: dd 0

; Move the player by (EAX, EDX). Each axis is checked on its own, a radius
; ahead of where we'd end up, so you slide along walls instead of sticking.
try_move:
    mov esi, [player_x]
    add esi, eax
    mov ecx, RADIUS
    test eax, eax
    jns .x_probe
    neg ecx
.x_probe:
    add esi, ecx
    mov edi, [player_y]
    call map_index
    cmp byte [map + bx], 0
    jne .y_axis
    add [player_x], eax
.y_axis:
    mov edi, [player_y]
    add edi, edx
    mov ecx, RADIUS
    test edx, edx
    jns .y_probe
    neg ecx
.y_probe:
    add edi, ecx
    mov esi, [player_x]
    call map_index
    cmp byte [map + bx], 0
    jne .done
    add [player_y], edx
.done:
    ret

; Esc pulses the CPU's reset line through the keyboard controller.
reboot:
    mov al, 0xFE
    out 0x64, al
    jmp halt

keys: times 128 db 0
