; Stage 2: entered from the boot sector with CS = DS = ES = SS = 0.

main:
    mov si, msg_stage2
    call print
    jmp halt

msg_stage2: db "bootcaster: stage 2 is running", 13, 10, 0
