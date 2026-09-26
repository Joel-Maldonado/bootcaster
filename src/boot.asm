; bootcaster: a raycaster that boots on bare metal.
;
; The BIOS copies the first 512-byte sector of the boot disk to 0x7C00 and
; jumps there in 16-bit real mode. Nothing else is set up: no stack we can
; trust, no segments, no OS.

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

    mov si, msg_hello
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

msg_hello: db "bootcaster: hello from the boot sector", 13, 10, 0

    times 510 - ($ - $$) db 0
    dw 0xAA55               ; the BIOS only boots sectors that end in 55 AA
