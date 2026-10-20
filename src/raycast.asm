; One ray per screen column, cast with DDA. Instead of creeping forward in tiny
; steps it jumps straight from one grid line to the next, whichever one
; (vertical or horizontal) the ray gets to first. Every step lands on a tile
; edge, so it can't skip a wall or go past one.
;
; The rays are spread across a camera plane instead of equal angles, and the
; wall distance is measured along the view direction. That's what keeps flat
; walls flat (my first version used angles and every wall bulged).

PLANE       equ 43254           ; 0.66 in 16.16, roughly a 66 degree FOV
MIN_DIST    equ 0x100           ; don't divide by ~0 right up against a wall
CEIL_COLOR  equ SHADOW | (RAMP_STONE + 7)
FLOOR_COLOR equ SHADOW | (RAMP_WOOD + 9)

render:
    push es
    mov ax, BACK_SEG
    mov es, ax
    mov ax, TEX_SEG
    mov fs, ax
%ifdef STATS
    mov dword [stat_steps], 0
%endif

    ; Camera for this frame. A unit direction vector, plus a plane that's
    ; perpendicular to it. How wide the plane is sets the FOV.
    mov si, [player_angle]
    call sin_cos                ; EAX = cos, EDX = sin
    mov [dir_x], eax
    mov [dir_y], edx
    mov ebx, PLANE
    push eax
    mov eax, edx
    neg eax
    call fixmul
    mov [plane_x], eax          ; -sin * 0.66
    pop eax
    call fixmul
    mov [plane_y], eax          ; cos * 0.66

    mov word [col], 0
.column:
    ; camera_x goes from -1 on the left edge to +1 on the right
    movsx eax, word [col]
    shl eax, 1
    sub eax, SCREEN_W
    shl eax, 16
    cdq
    mov ebx, SCREEN_W
    idiv ebx
    mov ebx, eax
    mov eax, [plane_x]
    call fixmul
    add eax, [dir_x]
    mov [ray_x], eax
    mov eax, [plane_y]
    call fixmul
    add eax, [dir_y]
    mov [ray_y], eax

    mov eax, [ray_x]
    mov ecx, [player_x]
    call axis_setup
    mov [delta_x], ebx
    mov [side_x], eax
    mov [step_x], dx
    mov eax, [ray_y]
    mov ecx, [player_y]
    call axis_setup
    mov [delta_y], ebx
    mov [side_y], eax
    mov [step_y], dx

    mov ax, [player_x + 2]      ; high word of a 16.16 number is the tile
    mov [map_x], ax
    mov ax, [player_y + 2]
    mov [map_y], ax

.step:
    STAT_INC stat_steps
    mov eax, [side_x]
    cmp eax, [side_y]
    jae .step_y
    add eax, [delta_x]
    mov [side_x], eax
    mov ax, [step_x]
    add [map_x], ax
    mov byte [side], 0
    jmp .check
.step_y:
    mov eax, [side_y]
    add eax, [delta_y]
    mov [side_y], eax
    mov ax, [step_y]
    add [map_y], ax
    mov byte [side], 1
.check:
    mov bx, [map_y]
    shl bx, 4                   ; * MAP_W
    add bx, [map_x]
    mov al, [map + bx]
    test al, al
    jz .step

    ; Hit a wall. Undo the last step to get the distance to the grid line we
    ; crossed, then figure out where along the wall the ray landed, which is
    ; the texture column. Walls facing along y get the darker half of the
    ; palette so you can actually see the corners.
    dec al
    movzx bx, al
    shl bx, 12                  ; texture = wall type - 1, 4 KB each
    mov [tex_base], bx
    cmp byte [side], 0
    jne .y_side
    mov ecx, [side_x]
    sub ecx, [delta_x]
    mov byte [shade], 0
    mov eax, [ray_y]
    mov ebx, ecx
    call fixmul
    add eax, [player_y]
    cmp dword [ray_x], 0
    jg .mirror
    jmp .have_hit
.y_side:
    mov ecx, [side_y]
    sub ecx, [delta_y]
    mov byte [shade], SHADOW
    mov eax, [ray_x]
    mov ebx, ecx
    call fixmul
    add eax, [player_x]
    cmp dword [ray_y], 0
    jl .mirror
    jmp .have_hit
.mirror:
    not eax                     ; or textures come out mirrored on two sides
.have_hit:
    shr ax, 10                  ; top 6 bits of the fraction = column 0-63
    add [tex_base], ax

    cmp ecx, MIN_DIST
    jae .dist_ok
    mov ecx, MIN_DIST
.dist_ok:
    mov eax, SCREEN_H << 16
    xor edx, edx
    div ecx
    mov ecx, eax                ; wall height in pixels
    test ecx, ecx
    jnz .has_height
    inc ecx
.has_height:
    mov eax, TEX_SIZE << 16
    xor edx, edx
    div ecx
    mov [tex_step], eax         ; texels per screen pixel, 16.16

    mov ebx, SCREEN_H
    sub ebx, ecx
    sar ebx, 1                  ; top of the wall (negative if off screen)
    mov edx, ebx
    add edx, ecx                ; bottom
    xor eax, eax
    test ebx, ebx
    jns .top_ok
    mov eax, ebx                ; skip the part that's above the screen
    neg eax
    imul eax, [tex_step]
    xor ebx, ebx
.top_ok:
    mov [tex_pos], eax
    cmp edx, SCREEN_H
    jle .bottom_ok
    mov edx, SCREEN_H
.bottom_ok:
    call draw_column

    inc word [col]
    cmp word [col], SCREEN_W
    jb .column
    pop es
    ret

; DDA setup for one axis.
; In:  EAX = ray component on this axis, ECX = player position (16.16)
; Out: EBX = delta (distance along the ray between two grid lines)
;      EAX = distance along the ray to the first grid line
;      DX  = which way to step in the map (+1 or -1)
axis_setup:
    push eax
    test eax, eax
    jns .positive
    neg eax
.positive:
    cmp eax, 2                  ; ray is basically parallel to these lines
    jb .never
    mov ebx, eax
    mov edx, 1
    xor eax, eax
    div ebx                     ; |1 / ray| in 16.16 is 2^32 / |ray|
    cmp eax, 0x7FFFFFFF
    jbe .have_delta
.never:
    mov eax, 0x7FFFFFFF
.have_delta:
    mov ebx, eax
    pop eax
    and ecx, 0xFFFF             ; how far into the current tile we are
    test eax, eax
    js .backward
    neg ecx
    add ecx, 0x10000            ; going forward, the next line is 1 - that away
    mov dx, 1
    jmp .first_line
.backward:
    mov dx, -1
.first_line:
    push dx
    mov eax, ecx
    call fixmul
    pop dx
    ret

; Draw column [col] into the back buffer. Ceiling above BX, textured wall from
; BX to DX, floor below that. Needs ES = back buffer and FS = textures.
draw_column:
    mov di, [col]
    mov cx, bx
    jcxz .wall
.ceiling:
    mov byte [es:di], CEIL_COLOR
    add di, SCREEN_W
    loop .ceiling
.wall:
    mov cx, dx
    sub cx, bx
    jcxz .floor
    mov ebp, [tex_pos]
    mov si, [tex_base]
    mov ah, [shade]
.texel:
    mov ebx, ebp
    shr ebx, 16
    and bx, TEX_SIZE - 1        ; texture row
    shl bx, 6
    add bx, si
    mov al, [fs:bx]
    or al, ah
    mov [es:di], al
    add di, SCREEN_W
    add ebp, [tex_step]
    loop .texel
.floor:
    mov cx, SCREEN_H
    sub cx, dx
    jcxz .done
.floor_loop:
    mov byte [es:di], FLOOR_COLOR
    add di, SCREEN_W
    loop .floor_loop
.done:
    ret

col:         dw 0
dir_x:       dd 0
dir_y:       dd 0
plane_x:     dd 0
plane_y:     dd 0
ray_x:       dd 0
ray_y:       dd 0
delta_x:     dd 0
delta_y:     dd 0
side_x:      dd 0
side_y:      dd 0
step_x:      dw 0
step_y:      dw 0
map_x:       dw 0
map_y:       dw 0
side:        db 0
shade:       db 0               ; 0, or SHADOW for y-facing walls
tex_base:    dw 0               ; texture start + column
tex_step:    dd 0
tex_pos:     dd 0
