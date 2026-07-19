# BCS3 Retro-Computing FPGA System Core

This repository contains a high-fidelity, fully synchronous SystemVerilog emulation of the **BCS3 System** architecture (an architectural variation of classic Z80-based microcomputers). 

The entire core collapses multiple historical clock boundaries into a single master clock domain, utilizing synchronous clock-enable mechanisms.

---

## 1. Core Variations: The Two System Versions

The repository splits the BCS3 Emulation Project into two distinct architectural hardware flavors, depending on whether your software demands standard industrial text uniformity or advanced, hardware-driven dynamic display manipulation.

### Version 1: The Standard Cor
This is the vanilla, deterministic configuration. It enforces a predictable memory layout and strict screen boundaries, minimizing logic consumption on the FPGA.
* **Screen Layout:** Rigid **28 columns by 12 rows** of text.
* **Memory Model:** Completely **static addressing** initializing on a fixed base pointer vector at `10'h050`. It has no dynamic or volatile hardware modifications.
* **System RAM:** Equipped with a **4 KB RAM** .
* **Font Pack:** Uses the standardized **`char_24` ROM** matrix, painting character pixels on an 8x10 tile block.
* **Architecture:** Includes integrated bus multiplexer registers straight inside the video component block, simplifying the outer top-level wire mapping.

### Version 2: The "Hack" Core
This is the heavily modified, highly advanced expansion variant. It incorporates complex internal hardware sniffing loops during the vertical blanking period to unlock automated display scrolling without wasting Z80 CPU cycles.
* **Screen Layout:** Expanded view pane consisting of **29 columns by 12 rows** of text (using a wider 30-byte pitch layout).
* **Hardware-Driven Scrolling:** The video controller actively intercepts the Z80 cursor registers during `vblank`. If software moves the cursor past the bottom line, an internal hardware pointer registerdynamically adjusts the VRAM display matrix downward.
* **System RAM:** Features an expanded **16 KB RAM** to accommodate large historical system programs.
* **Font Pack:** Deploys a custom, advanced graphics character pack inside the **`char_33` ROM** array, expanding the machine’s pseudo-graphic tile parameters.
* **Architecture:** The expansion bus data multiplexer is externalized to the top-level wire layer, allowing for more intricate component stacking and debugging hooks.

---

## 2. CPU & System Clock Architecture

* **Core CPU:** Driven by a fully synchronous `T80se` core, emulating the East German **U880** processor (Zilog Z80 compatible).
* **Master Clock & Engine:** The entire design operates inside a single **5 MHz** master clock. 
* **CPU Execution Speed:** A synchronous fractional pulse generator scales the effective execution speed down to exactly **2.5 MHz** to match the original system speed.

---

## 3. Memory Configuration & ROM Modules

The core features a flexible address decoder managed by hardware switches and software banking:
* **WRAM & VRAM:** Video memory is implemented as true Dual-Port RAM, allowing the CPU to write text data while the video engine simultaneously reads pixel patterns.
* **Integrated ROM Modules:** The system includes multiple selectable firmware versions (such as **SE24** for the Standard version and **SE33** for the Hack version).

---

## 4. Peripherals & Sound System

* **Hardware Cores:** Standard Z80 CTC and PIO units handle system timing and I/O communication, wired together in a priority interrupt daisy-chain.
* **Tape I/O (Cassette Interface):** Fully supports loading and saving data via a digital cassette simulation layer. The data output line (`UART_TX`) synthesizes an FSK signal via a flip-flop toggled by the CTC zero-crossing output. Incoming digitized audio streams (`UART_RX`) are read back through the memory-mapped keyboard register block.

---

## 5. Advanced Keyboard Decoder & Map

The core features a highly optimized keyboard decoder that acts as a smart bridge between a modern **PS/2 keyboard (German Layout)** and the historical operating system. It bypasses historical multi-key finger-combos by mapping keys natively and automating the required internal `Shift` states for direction control.

### Keyboard Mapping Table (Modern PC ? BCS3 Target Character)

| Modern Key (German Layout) | Target Character / System Function |
| :--- | :--- |
| **`A`** .. **`Z`** | Standard Alphabetical (`A` .. `Z` / capital or lowercase depending on shift) |
| **`0`** .. **`9`** | Numbers (`0` .. `9`) |
| **`SPACE`** | Space / Leertaste |
| **`ENTER`** | Enter / Eingabetaste |
| **`BACKSPACE`** | Backspace / Löschtaste |
| **`ARROW RIGHT` (?)** | Move Right / Cursor Rechts (via mapped Key `I`) |
| **`L / R SHIFT`** | Shift Function / Umschalten |

### Special Control Features

* **Native German QWERTZ Realignment:** The matrix assignments for keys **`Y`** and **`Z`** are internally cross-mapped, allowing modern physical German layouts to display correctly within the host system's target layout parameters.
* **Dual-Shift Integration:** The decoder intercepts both left and right `SHIFT` keys simultaneously and maps them to the identical matrix position for enhanced operational flexibility.
* **PS/2 Clock Filter:** Uses an aggressive 4-stage shift filter to debounce the incoming clock signal, ensuring immune edge detection against high-frequency physical electrical noise.
* **Integrated Cassette Stream:** Serialized digitized cassette audio data (`UART_RX`) is actively monitored during keyboard register bus reads at address range `0x1000`.