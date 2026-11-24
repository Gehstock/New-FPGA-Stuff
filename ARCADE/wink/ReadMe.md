# Wink (Midcoin, 1985) – Arcade FPGA Core

FPGA implementation of the rare 1985 Italian arcade game **Wink** by **Midcoin**

## Hardware Specifications

* **Main CPU:** Zilog Z80 @ 3.072 MHz (`12.288 MHz / 4`)
* **Sound CPU:** Zilog Z80 @ 1.536 MHz (`12.288 MHz / 8`)
* **Sound Chip:** General Instrument AY-3-8912 (YM2149) @ 1.536 MHz with 15.6 kHz sync clock
* **Video:**
  * Resolution: 256 × 256 pixels (Horizontal)
  * Graphics: 8×8 planar 3bpp background tiles with split-screen and register banking
  * Palette: 16 colors (`xBRG_444` format)
* **Memory & Protection:**
  * 32 KB encrypted Main ROM (`init_wink` address bit-swap & byte decryption)
  * 8 KB Sound ROM & 24 KB Tile ROMs
  * 2 KB NVRAM (`$8000–$87FF`, mirrored at `$9000–$97FF`, cold-boot initialized to `0xFF`)
  * On-board I/O protection latch (`$C0–$DF` / `$E0–$FF`)
