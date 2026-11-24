# Wall Crash (Midcoin, 1984) – Arcade FPGA Core

FPGA implementation of the 1984 Italian arcade game **Wall Crash** by **Midcoin**

---

## Hardware Specifications

* **Main CPU:** Zilog Z80 @ 3.0 MHz (`48 MHz / 16`)
* **Sound Chip:** General Instrument AY-3-8910 (YM2149) @ 1.5 MHz (`48 MHz / 32`), memory-mapped at `$B500` / `$B600`
* **Video:**
  * Resolution: 256 × 256 pixels (Horizontal, 50.08 Hz PAL raster `384 × 312`)
  * Graphics: 8×8 planar 3bpp background tiles (`$8000–$83FF` VRAM)
  * Palette: 32 colors via resistor-weighted Color PROM (`col.sv`)
* **Memory & Protection:**
  * 16 KB encrypted Main ROM (`$0000–$7FFF`, `XOR 0xAA` + bit-swap decryption)
  * 12 KB Tile ROMs (`3 × 4 KB` planar)
  * 1 KB Work RAM (`$A000–$A3FF`)
  * Memory-mapped I/O (`$B000–$B6FF`)
