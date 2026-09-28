; Stage 2: entered from the boot sector with CS = DS = ES = SS = 0.

main:
    call video_init

    ; Test pattern: color = x + y, so every palette entry shows up as a stripe.
    push es
    mov ax, BACK_SEG
    mov es, ax
    xor di, di
    xor dx, dx                  ; y
.row:
    xor cx, cx                  ; x
.col:
    mov al, cl
    add al, dl
    stosb
    inc cx
    cmp cx, SCREEN_W
    jb .col
    inc dx
    cmp dx, SCREEN_H
    jb .row
    pop es

    call present
    jmp halt

%include "video.asm"
