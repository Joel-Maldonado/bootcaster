; bootcaster: a raycaster that boots on bare metal.
;
; The BIOS copies the first 512-byte sector of the boot disk to 0x7C00 and
; jumps there in 16-bit real mode. Nothing else is set up: no stack we can
; trust, no segments, no OS. This sector's only job is to load the rest of
; the program (everything after it in this file) to 0x7E00 and jump to it.

bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; stack grows down from just below our code
    sti
    cld
    mov [boot_drive], dl    ; the BIOS tells us which disk we booted from

    ; INT 13h extensions read by LBA, so we never have to think about
    ; cylinders, heads and sectors. Check that the BIOS has them.
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

    jmp 0x0000:main         ; far jump, so CS is 0 from here on

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

; Print a zero-terminated string at DS:SI with the BIOS teletype call.
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

; Disk address packet for INT 13h AH=42h.
dap:
    db 0x10, 0
    dw STAGE2_SECTORS
    dw 0x7E00, 0            ; destination offset, segment
    dq 1                    ; first LBA: the sector right after this one

boot_drive: db 0
msg_no_lba: db "bootcaster: BIOS has no INT 13h extensions", 0
msg_disk:   db "bootcaster: disk read failed", 0

    times 510 - ($ - $$) db 0
    dw 0xAA55               ; the BIOS only boots sectors that end in 55 AA

; ---------------------------------------------------------------------------
; Everything below here is loaded by the code above.

stage2_start:
%include "main.asm"
stage2_end:

    times (512 - ($ - $$) % 512) % 512 db 0    ; pad to whole sectors
STAGE2_SECTORS equ (stage2_end - stage2_start + 511) / 512
