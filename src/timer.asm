; IRQ 0 comes from channel 0 of the 8254 timer chip, which counts down from a
; reload value at 1.193182 MHz and interrupts each time it reaches zero. The
; BIOS leaves the reload at 65536, about 18.2 interrupts a second, which is
; too coarse to time a frame. We reload it for a 1 kHz tick and count
; milliseconds ourselves. Nothing else here needs the BIOS's clock.

PIT_HZ  equ 1193182
TICK_HZ equ 1000

timer_init:
    cli
    mov al, 0x36                ; channel 0, low byte then high byte, mode 3
    out 0x43, al
    mov ax, PIT_HZ / TICK_HZ
    out 0x40, al
    mov al, ah
    out 0x40, al
    mov word [8 * 4], timer_irq ; IRQ 0 is interrupt vector 8
    mov word [8 * 4 + 2], 0
    sti
    ret

timer_irq:
    inc dword [cs:ticks]
    push ax
    mov al, 0x20
    out 0x20, al
    pop ax
    iret

ticks: dd 0
