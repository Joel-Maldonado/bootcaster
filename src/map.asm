; The map. 16x16 tiles, 0 is floor and anything else is a wall (the number
; picks the texture). Keep the border solid or rays will run off the map.

MAP_W equ 16
MAP_H equ 16

map:
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,0,0,0,0,0,0,0,0,2,2,2,2,0,0,1
    db 1,0,0,3,0,0,0,0,0,2,0,0,0,0,0,1
    db 1,0,0,0,0,0,0,0,0,2,0,0,0,0,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,0,0,0,0,4,4,4,0,0,0,0,0,0,0,1
    db 1,0,0,0,0,4,0,0,0,0,0,0,0,3,0,1
    db 1,0,0,0,0,4,0,0,0,0,0,0,0,0,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,2,2,0,0,0,0,0,0,3,0,0,0,0,0,1
    db 1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,2,0,0,0,0,0,0,0,0,0,4,4,0,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,4,4,0,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; Which tile a 16.16 position is in. In: ESI = x, EDI = y.
; Out: BX = offset into map.
map_index:
    push eax
    mov eax, edi
    shr eax, 16
    shl ax, 4                   ; y * MAP_W
    mov ebx, esi
    shr ebx, 16
    add bx, ax
    pop eax
    ret
