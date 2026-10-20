; Keyboard stuff. The BIOS keyboard call (INT 16h) only gives you keystrokes.
; There are no key-ups, and holding a key only repeats it after a delay, one
; key at a time. That's useless if you want to walk and turn at once, so I
; take over IRQ 1 and read the scan codes off the keyboard controller myself.

KEY_ESC   equ 0x01
KEY_W     equ 0x11
KEY_A     equ 0x1E
KEY_S     equ 0x1F
KEY_D     equ 0x20
KEY_UP    equ 0x48
KEY_LEFT  equ 0x4B
KEY_RIGHT equ 0x4D
KEY_DOWN  equ 0x50

TURN_PER_MS equ 25              ; binary angle per ms, ~137 degrees a sec
MOVE_PER_MS equ 197             ; 16.16 tiles per ms, so 3 tiles a sec
RADIUS      equ 0x4000          ; keep a quarter tile away from walls

keyboard_init:
    cli
    mov word [9 * 4], keyboard_irq      ; IRQ 1 = interrupt vector 9
    mov word [9 * 4 + 2], 0
    sti
    ret

; Every key sends its scan code when you press it, and the same code with
; bit 7 set when you let go. Arrow keys send an 0xE0 first, which I just skip,
; since the byte after it is the same as the keypad key in that spot anyway.
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
    out 0x20, al                ; tell the PIC we're done (EOI)
    pop bx
    pop ax
    iret

handle_input:
    cmp byte [keys + KEY_ESC], 0
    jne reboot

    mov ax, [frame_ms]
    imul ax, TURN_PER_MS
    cmp byte [keys + KEY_LEFT], 0
    je .not_left
    sub [player_angle], ax
.not_left:
    cmp byte [keys + KEY_RIGHT], 0
    je .not_right
    add [player_angle], ax
.not_right:

    movzx edx, word [frame_ms]
    imul edx, MOVE_PER_MS       ; how far to move this frame
    xor ebx, ebx                ; forward
    xor ecx, ecx                ; sideways
    mov al, [keys + KEY_W]
    or al, [keys + KEY_UP]
    jz .not_forward
    add ebx, edx
.not_forward:
    mov al, [keys + KEY_S]
    or al, [keys + KEY_DOWN]
    jz .not_back
    sub ebx, edx
.not_back:
    cmp byte [keys + KEY_D], 0
    je .not_right_strafe
    add ecx, edx
.not_right_strafe:
    cmp byte [keys + KEY_A], 0
    je .not_left_strafe
    sub ecx, edx
.not_left_strafe:

    ; Forward is (cos, sin) and right is (-sin, cos)
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

; Move the player by (EAX, EDX). x and y get checked separately, a radius
; ahead of where you'd end up, so you slide along walls instead of sticking.
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

; Esc reboots. Sending 0xFE to the keyboard controller pulses the CPU's
; reset line, which is old school but it works.
reboot:
    mov al, 0xFE
    out 0x64, al
    jmp halt

keys: times 128 db 0
