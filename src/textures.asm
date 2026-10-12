; Four 64x64 wall textures, generated at boot instead of stored on disk:
; brick, stone, tile and wood. Each texel is a palette index. Texture n
; starts at TEX_SEG:n*4096 and is stored row by row.
;
; The grain comes from a 16-bit Galois LFSR, the same shift register you'd
; build out of flip-flops and XOR gates.

TEX_SEG  equ 0x3000             ; physical 0x30000
TEX_SIZE equ 64

make_textures:
    push es
    mov ax, TEX_SEG
    mov es, ax
    xor di, di
    mov si, texel_makers
.texture:
    xor dx, dx                  ; y
.row:
    xor cx, cx                  ; x
.texel:
    call [si]
    stosb
    inc cx
    cmp cx, TEX_SIZE
    jb .texel
    inc dx
    cmp dx, TEX_SIZE
    jb .row
    add si, 2
    cmp si, texel_makers_end
    jb .texture
    pop es
    ret

texel_makers:
    dw brick_texel, stone_texel, tile_texel, wood_texel
texel_makers_end:

; Each maker gets CX = x and DX = y, returns the palette index in AL, and may
; change AX and BX.

; Rows of 16-pixel bricks, every other row shifted half a brick, with
; mortar between them and a lit top edge and shadowed bottom edge.
brick_texel:
    mov bx, dx
    and bx, 15                  ; y inside this row of bricks
    cmp bx, 2
    jb .mortar
    mov ax, dx
    and ax, 16                  ; odd rows: shift by 16
    add ax, cx
    and ax, 31                  ; x inside this brick
    cmp ax, 2
    jb .mortar
    call lfsr_next
    and al, 7
    add al, RAMP_BRICK + 14
    cmp bx, 2
    jne .not_top
    add al, 6
.not_top:
    cmp bx, 15
    jne .done
    sub al, 7
.done:
    ret
.mortar:
    call lfsr_next
    and al, 3
    add al, RAMP_STONE + 9
    ret

; Big 32x32 blocks with dark seams, each block a slightly different shade.
stone_texel:
    test dx, 31
    jz .seam
    mov ax, dx
    and ax, 32                  ; offset every other row of blocks
    shr ax, 1
    add ax, cx
    test ax, 31
    jz .seam
    mov bx, ax
    shr bx, 5                   ; block column
    imul bx, 3
    mov ax, dx
    shr ax, 5                   ; block row
    imul ax, 5
    add bx, ax
    and bx, 6                   ; per-block shade offset
    call lfsr_next
    and al, 7
    add al, bl
    add al, RAMP_STONE + 10
    ret
.seam:
    mov al, RAMP_STONE + 3
    ret

; 16x16 glazed tiles: grout lines, bright top-left bevel, dark bottom-right.
tile_texel:
    mov ax, cx
    and ax, 15
    mov bx, dx
    and bx, 15
    test ax, ax
    jz .grout
    test bx, bx
    jz .grout
    cmp ax, 1
    je .bright
    cmp bx, 1
    je .bright
    cmp ax, 15
    je .dark
    cmp bx, 15
    je .dark
    call lfsr_next
    and al, 3
    add al, RAMP_TILE + 18
    ret
.bright:
    mov al, RAMP_TILE + 28
    ret
.dark:
    mov al, RAMP_TILE + 9
    ret
.grout:
    mov al, RAMP_STONE + 6
    ret

; Vertical planks: a streak per column for grain, and a dark ring line that
; sits at a different height on each plank.
wood_texel:
    test cx, 15
    jz .seam
    mov ax, cx
    imul ax, 7
    and ax, 7
    add ax, RAMP_WOOD + 13
    mov bx, cx
    shr bx, 4                   ; which plank
    imul bx, 9
    add bx, dx
    and bx, 31
    cmp bx, 2
    jae .no_ring
    sub ax, 6
.no_ring:
    mov bx, ax
    call lfsr_next
    and al, 1
    add al, bl
    ret
.seam:
    mov al, RAMP_WOOD + 3
    ret

; Advance the LFSR (taps 16, 14, 13, 11) and return its new value in AX.
lfsr_next:
    shr word [lfsr], 1
    jnc .no_tap
    xor word [lfsr], 0xB400
.no_tap:
    mov ax, [lfsr]
    ret

lfsr: dw 0xACE1                 ; any seed but zero
