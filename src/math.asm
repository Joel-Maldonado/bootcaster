; Fixed point math. Positions and distances are 16.16, so the top 16 bits are
; whole tiles and the bottom 16 are the fraction (0x00018000 is 1.5 tiles).
;
; Angles are 16-bit binary angles where 65536 is a full turn, so they just
; wrap around on their own. The sine table has 1024 entries, indexed by
; angle >> 6.

SIN_TABLE  equ 0x1000           ; 1024 dwords, filled in at boot
ANGLE_BITS equ 10
ANGLES     equ 1 << ANGLE_BITS

; Only place the FPU gets used. Build the sine table once at boot and never
; touch it again.
make_sin_table:
    fninit
    mov di, SIN_TABLE
    xor cx, cx
.next:
    mov [.i], cx
    fild word [.i]
    fmul dword [.step]          ; i * 2pi / 1024
    fsin
    fmul dword [.one]           ; scale to 16.16
    fistp dword [di]
    add di, 4
    inc cx
    cmp cx, ANGLES
    jb .next
    ret
.i:    dw 0
.step: dd 0.0061359231515425649   ; 2pi / 1024
.one:  dd 65536.0

; In: SI = binary angle. Out: EAX = cos, EDX = sin, both 16.16.
sin_cos:
    push bx
    mov bx, si
    shr bx, 16 - ANGLE_BITS
    shl bx, 2
    mov edx, [SIN_TABLE + bx]
    add bx, (ANGLES / 4) * 4      ; cos(a) = sin(a + 90 degrees)
    and bx, (ANGLES - 1) * 4
    mov eax, [SIN_TABLE + bx]
    pop bx
    ret

; EAX = EAX * EBX in 16.16 (trashes EDX)
fixmul:
    imul ebx
    shrd eax, edx, 16
    ret
