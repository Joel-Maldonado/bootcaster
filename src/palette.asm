; Our own 256 colors, written straight to the VGA DAC: send the first index
; to port 0x3C8, then red, green, blue for each color to port 0x3C9 (six
; bits each, 0-63; the index advances by itself).
;
; Colors 0-127 are four ramps of 32 shades, one per wall material.
; Colors 128-255 repeat them at half brightness, so setting bit 7 of any
; texel gives the shadowed version of the same color.

PAL_BUF equ 0x2000              ; 128 * 3 bytes of scratch, under the stack

RAMP_BRICK equ 0
RAMP_STONE equ 32
RAMP_TILE  equ 64
RAMP_WOOD  equ 96
SHADOW     equ 0x80

palette_init:
    mov si, ramps
    mov di, PAL_BUF
    mov cx, 4
.ramp:
    xor bx, bx                  ; BL = shade, 0 to 31
.shade:
    push cx
    push si
    mov cx, 3                   ; red, green, blue
.channel:
    mov al, [si + 3]            ; start + (end - start) * shade / 31
    sub al, [si]
    mul bl
    mov dl, 31
    div dl
    add al, [si]
    mov [di], al
    inc di
    inc si
    loop .channel
    pop si
    pop cx
    inc bl
    cmp bl, 32
    jb .shade
    add si, 6
    loop .ramp

    mov dx, 0x3C8
    xor al, al
    out dx, al
    inc dx
    mov si, PAL_BUF
    mov cx, 128 * 3
.bright:
    lodsb
    out dx, al
    loop .bright
    mov si, PAL_BUF
    mov cx, 128 * 3
.dark:
    lodsb
    shr al, 1
    out dx, al
    loop .dark
    ret

; Darkest and brightest RGB of each ramp, 0-63 per channel.
ramps:
    db  6,  1,  1,   60, 26, 16     ; brick
    db  5,  5,  6,   54, 54, 56     ; stone
    db  2,  3, 10,   24, 40, 63     ; tile
    db  8,  4,  1,   58, 40, 18     ; wood
