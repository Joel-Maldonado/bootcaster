; VGA mode 13h. 320x200, one byte per pixel, 256 colors, and the whole screen
; is just a flat 64,000 byte array at A000:0000. I draw into a back buffer in
; normal RAM and copy it over once a frame.

VGA_SEG    equ 0xA000
BACK_SEG   equ 0x2000           ; back buffer at physical 0x20000
SCREEN_W   equ 320
SCREEN_H   equ 200

video_init:
    mov ax, 0x0013
    int 0x10
    ret

; Wait for vertical retrace to start (bit 3 of port 0x3DA) so the copy
; happens between frames and doesn't tear.
wait_vretrace:
    mov dx, 0x3DA
.in_retrace:                    ; already in one? wait for it to end first
    in al, dx
    test al, 8
    jnz .in_retrace
.not_yet:
    in al, dx
    test al, 8
    jz .not_yet
    ret

; Copy the back buffer to the screen.
present:
    push ds
    push es
    call wait_vretrace
    mov ax, BACK_SEG
    mov ds, ax
    mov ax, VGA_SEG
    mov es, ax
    xor si, si
    xor di, di
    mov cx, SCREEN_W * SCREEN_H / 4
    rep movsd
    pop es
    pop ds
    ret
