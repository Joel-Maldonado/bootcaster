; `make STATS=1` prints a few counters to port 0xE9. QEMU's -debugcon turns
; that port into a log, and on a real PC the writes just go nowhere.

%ifdef STATS

; Print the string at SI, then EAX in decimal, then a newline
stat_print:
    pushad
.label:
    lodsb
    test al, al
    jz .number
    out 0xE9, al
    jmp .label
.number:
    mov bp, sp
    mov eax, [bp + 28]          ; caller's EAX, saved by pushad
    mov ebx, 10
    xor cx, cx
.divide:
    xor edx, edx
    div ebx
    push dx
    inc cx
    test eax, eax
    jnz .divide
.digit:
    pop ax
    add al, '0'
    out 0xE9, al
    loop .digit
    mov al, 10
    out 0xE9, al
    popad
    ret

%endif

%macro STAT_INC 1
%ifdef STATS
    inc dword [%1]
%endif
%endmacro
