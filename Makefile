NASM ?= nasm
QEMU ?= qemu-system-i386
NASMFLAGS := -f bin -I src/ $(if $(STATS),-DSTATS)

bootcaster.img: $(wildcard src/*.asm)
	$(NASM) $(NASMFLAGS) -o $@ src/boot.asm

run: bootcaster.img
	$(QEMU) -drive format=raw,file=$<

clean:
	rm -f bootcaster.img

.PHONY: run clean
