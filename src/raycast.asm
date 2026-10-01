; First attempt: for each screen column, walk a ray forward in small fixed
; steps until it lands inside a wall, and size the wall by how far it went.

FOV        equ 10923            ; 60 degrees as a binary angle
RAY_STEP   equ 2048             ; 1/32 of a tile
MAX_DIST   equ 24 << 16
CEIL_COLOR  equ 0x13
FLOOR_COLOR equ 0x17

render:
    push es
    mov ax, BACK_SEG
    mov es, ax
    mov word [col], 0
.column:
    ; Spread the field of view evenly across the columns.
    mov ax, [col]
    sub ax, SCREEN_W / 2
    mov cx, FOV
    imul cx
    mov cx, SCREEN_W
    idiv cx
    add ax, [player_angle]
    mov si, ax
    call sin_cos
    sar eax, 5                  ; one step is 1/32 of a tile
    sar edx, 5
    mov [ray_dx], eax
    mov [ray_dy], edx

    mov esi, [player_x]
    mov edi, [player_y]
    xor ecx, ecx                ; distance travelled
.march:
    add esi, [ray_dx]
    add edi, [ray_dy]
    add ecx, RAY_STEP
    cmp ecx, MAX_DIST
    jae .miss
    call map_index
    mov al, [map + bx]
    test al, al
    jz .march
    jmp .hit
.miss:
    xor al, al
.hit:
    xor bh, bh
    mov bl, al
    mov al, [wall_colors + bx]
    mov [wall_color], al

    ; Wall height is inversely proportional to distance.
    mov eax, SCREEN_H << 16
    xor edx, edx
    div ecx
    cmp eax, SCREEN_H
    jbe .height_ok
    mov eax, SCREEN_H
.height_ok:
    mov bx, SCREEN_H
    sub bx, ax
    shr bx, 1                   ; top of the wall
    mov dx, bx
    add dx, ax                  ; bottom of the wall
    call draw_column

    inc word [col]
    cmp word [col], SCREEN_W
    jb .column
    pop es
    ret

; Fill column [col] of the back buffer: ceiling above BX, wall from BX to DX,
; floor below. ES must point at the back buffer.
draw_column:
    mov di, [col]
    xor cx, cx
.ceiling:
    cmp cx, bx
    jae .wall
    mov byte [es:di], CEIL_COLOR
    add di, SCREEN_W
    inc cx
    jmp .ceiling
.wall:
    mov al, [wall_color]
.wall_loop:
    cmp cx, dx
    jae .floor
    mov [es:di], al
    add di, SCREEN_W
    inc cx
    jmp .wall_loop
.floor:
    cmp cx, SCREEN_H
    jae .done
    mov byte [es:di], FLOOR_COLOR
    add di, SCREEN_W
    inc cx
    jmp .floor
.done:
    ret

col:         dw 0
ray_dx:      dd 0
ray_dy:      dd 0
wall_color:  db 0
wall_colors: db 0, 4, 2, 1, 14   ; default VGA palette: red, green, blue, yellow
