# bootcaster

A Wolfenstein-style raycaster that boots straight from a disk image. No OS and
no libraries: a 512-byte boot sector, about 2 KB more of 16-bit x86 code,
the BIOS, and the VGA card.

![Tile, stone, wood and brick walls](screenshot.png)

The whole image is 3 KB. Everything you see is made at boot: the sine
table (with the x87), the 256-color palette, and four 64x64 wall textures
(from a 16-bit LFSR).

## Build and run

You need [NASM](https://nasm.us) and, to run it, QEMU.

```
make          # builds bootcaster.img
make run      # boots it in qemu-system-i386
```

| Key | |
|---|---|
| W / S, Up / Down | walk |
| A / D | strafe |
| Left / Right | turn |
| Esc | reboot (pulses the reset line through the keyboard controller) |

`make -B STATS=1` builds a version that prints the frame rate and the number
of DDA steps per frame to port 0xE9 once a second. QEMU can show that with
`-debugcon stdio`:

```
qemu-system-i386 -drive format=raw,file=bootcaster.img -debugcon stdio
```

## Real hardware

I've only run it in QEMU 10.2. In theory you can `dd` the image to a USB
stick and boot it on a PC with legacy BIOS (or CSM) boot. It needs a 386 or
newer with an FPU, VGA, and a BIOS that supports the INT 13h extensions, which
anything booting from USB should have.

## How it works

| File | |
|---|---|
| `src/boot.asm` | Boot sector. Sets up segments and a stack, loads the rest of the image with INT 13h AH=42h, jumps to it. |
| `src/main.asm` | Init and the frame loop. |
| `src/video.asm` | Mode 13h, a back buffer at 0x20000, copied to 0xA0000 on vertical retrace. |
| `src/math.asm` | 16.16 fixed point, and a 1024-entry sine table built with `fsin`. |
| `src/raycast.asm` | One ray per column, stepped through the map with DDA. Distance is measured along the view direction so walls don't bend. |
| `src/palette.asm` | Four 32-shade ramps, and a half-brightness copy so bit 7 means "in shadow". |
| `src/textures.asm` | Brick, stone, tile and wood, generated texel by texel. |
| `src/input.asm` | An IRQ 1 handler that tracks which keys are held, and movement with wall sliding. |
| `src/timer.asm` | The 8254 at 1 kHz, so movement speed doesn't depend on frame rate. |

Memory, all physical addresses:

| | |
|---|---|
| 0x01000 | sine table (4 KB) |
| 0x02000 | palette scratch |
| 0x07C00 | boot sector, stack below it |
| 0x07E00 | everything else |
| 0x20000 | back buffer (64,000 bytes) |
| 0x30000 | textures (16 KB) |
| 0xA0000 | VGA framebuffer |

## License

MIT
