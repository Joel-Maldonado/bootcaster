; bootcaster, a raycaster that boots with no OS under it.
;
; The BIOS copies the first 512 bytes of the disk to 0x7C00 and jumps here in
; 16-bit real mode, and that's pretty much all you get. The segments could be
; anything and there's no stack you can trust. So all this sector does is load
; the rest of the file to 0x7E00 and jump to it.

bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; stack grows down from right under us
    sti
    cld
    mov [boot_drive], dl    ; BIOS leaves the boot drive in DL, hang on to it

    ; The INT 13h extensions let you read by LBA so I don't have to mess with
    ; cylinders, heads and sectors. Make sure the BIOS actually has them.
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc no_lba
    cmp bx, 0xAA55
    jne no_lba

    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0x0000:main         ; far jump so CS is 0 from here on

no_lba:
    mov si, msg_no_lba
    jmp fail
disk_error:
    mov si, msg_disk
fail:
    call print
halt:
    hlt
    jmp halt

; Print the zero terminated string at DS:SI with the BIOS teletype call
print:
    mov ah, 0x0E
.next:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .next
.done:
    ret

; Disk address packet for INT 13h AH=42h
dap:
    db 0x10, 0
    dw STAGE2_SECTORS
    dw 0x7E00, 0            ; destination offset, segment
    dq 1                    ; first LBA: the sector right after this one

boot_drive: db 0
msg_no_lba: db "bootcaster: BIOS has no INT 13h extensions", 0
msg_disk:   db "bootcaster: disk read failed", 0

    times 510 - ($ - $$) db 0
    dw 0xAA55               ; the BIOS won't boot it unless it ends in 55 AA

; ---------------------------------------------------------------------------
; Everything past here is stage 2, which the code above loads.

stage2_start:
%include "main.asm"
stage2_end:

    times (512 - ($ - $$) % 512) % 512 db 0    ; pad out to a whole sector
STAGE2_SECTORS equ (stage2_end - stage2_start + 511) / 512
