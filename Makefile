NASM ?= nasm
QEMU ?= qemu-system-i386

bootcaster.img: $(wildcard src/*.asm)
	$(NASM) -f bin -I src/ -o $@ src/boot.asm

run: bootcaster.img
	$(QEMU) -drive format=raw,file=$<

clean:
	rm -f bootcaster.img

.PHONY: run clean
