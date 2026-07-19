# Amateurcomputer AC1 FPGA Core

This repository contains a synchronous hardware emulation of the East German 8-bit home computer **Amateurcomputer AC1** (originally published in *Funkamateur* magazine in 1984). The core has been modernized in **SystemVerilog** and extended with historical expansions from 1986/1987.

The design is optimized for stable, single-clock-domain synthesis on modern FPGA hardware

---

## 1. CPU & System Clock Architecture

* **Core CPU:** Driven by a fully synchronous `T80se` core, emulating the East German **U880** processor (Zilog Z80 compatible).
* **Master Clock & Engine:** The entire design operates inside a single **12 MHz** master clock domain. This guarantees glitch-free execution across memory blocks, keyboard matrices, and video generation.
* **CPU Execution Speed:** A synchronous fractional pulse generator scales the effective execution speed down to exactly **2.5 MHz** to match the original AC1 system speed.

## 2. Memory Configuration & ROM Modules

The core features a flexible address decoder managed by hardware switches and software banking:
* **WRAM & VRAM:** Supports memory layouts up to 58 KB RAM. Video memory is implemented as true Dual-Port RAM, allowing the CPU to write text data while the video engine simultaneously reads pixel patterns at 12 MHz.
* **Integrated ROM Modules:** The system includes multiple selectable firmware versions, including **Monitor 16**, **Monitor 32**, and the sophisticated **Monitor SCCH**, alongside the classic **AC1 BASIC** interpreter.
* **CP/M Compatibility:** A dedicated software banking register allows the core to fully disable the boot ROMs, creating a continuous 64 KB RAM block required to run the CP/M operating system.

## 3. Video & Video Mode Expansions

The video unit outputs a monochrome text display mapped from the VRAM, supporting both 64—16 and 64—32 layout formats

## 4. Peripherals & Sound System

* **Hardware Cores:** Standard Z80 CTC and PIO units handle system timing and I/O communication, wired together in a priority interrupt daisy-chain.

* **Tape I/O (Cassette Interface):** Fully supports loading and saving data via a digital cassette simulation layer allowing audio-modulated software data streams to be read and written

### Keyboard Mapping Table

| Modern Key (German Layout) | Target Character / System Function |
| :--- | :--- |
| **`A`** .. **`Z`** | Standard Alphabetical (`A` .. `Z` / capital or lowercase depending on shift) |
| **`0`** .. **`9`** | Numbers (`0` .. `9`) |
| **`SPACE`** | Space / Leertaste |
| **`ENTER`** | Enter / Eingabetaste |
| **`BACKSPACE`** | Backspace / Delete (`DEL`) |
| **`Ä`** | Native German Umlaut **`Ä`** |
| **`Ö`** | Native German Umlaut **`Ö`** |
| **`Ü`** | Native German Umlaut **`Ü`** |
| **`ARROW UP`**  | Move Up |
| **`ARROW DOWN`**  | Move Down (Automatically triggers internal Shift combo) |
|**`ARROW RIGHT`**  | Move Right |
| **`ARROW LEFT`**  | Move Left (Automatically triggers internal Shift combo) |
| **`ESC`** | **Hardware NMI Break** (Executes un-blockable system break/reset) |



**`ToDo`**  -  Fix File Loading, Fix Audio
