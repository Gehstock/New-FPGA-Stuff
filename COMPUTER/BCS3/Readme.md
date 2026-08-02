# BCS3 Retro-Computing FPGA System Core

This repository contains a high-fidelity, fully synchronous SystemVerilog emulation of the **BCS3 System** architecture (an architectural variation of classic Z80-based microcomputers). 


## 1. Core Variations: The Two System Versions

The repository splits the BCS3 Emulation Project into two distinct architectural hardware flavors, depending on whether your software demands standard industrial text uniformity or advanced, hardware-driven dynamic display manipulation.

### Version 1: The Standard Core
This is the vanilla, deterministic configuration. It enforces a predictable memory layout and strict screen boundaries, minimizing logic consumption on the FPGA.
* **Screen Layout:** Rigid **28 columns by 12 rows** of text.
* **System RAM:** Equipped with a **4 KB RAM** .
* **Integrated ROM Modules:**SE33** 
* **Font Pack:** Uses the standardized **`char_24` ROM** matrix, painting character pixels on an 8x10 tile block.

### Version 2: The "Hack" Core
This is the heavily modified, highly advanced expansion variant. It incorporates complex internal hardware sniffing loops during the vertical blanking period to unlock automated display scrolling without wasting Z80 CPU cycles.
* **Screen Layout:** Expanded view pane consisting of **29 columns by 12 rows** of text (using a wider 30-byte pitch layout).
* **Hardware-Driven Scrolling:** The video controller actively intercepts the Z80 cursor registers during `vblank`. If software moves the cursor past the bottom line, an internal hardware pointer registerdynamically adjusts the VRAM display matrix downward.
* **System RAM:** Features an expanded **16 KB RAM**.
* **Integrated ROM Modules:**SE33** 
* **Font Pack:** Deploys a custom, advanced graphics character pack inside the **`char_33` ROM** array, expanding the machine’s pseudo-graphic tile parameters.


---

## 2. CPU & System Clock Architecture

* **Core CPU:** Driven by a fully synchronous `T80se` core, emulating the East German **U880** processor (Zilog Z80 compatible).
* **Master Clock & Engine:** The entire design operates inside a single **5 MHz** master clock. 
* **CPU Execution Speed:** A synchronous fractional pulse generator scales the effective execution speed down to exactly **2.5 MHz** to match the original system speed.


---

## 3. Peripherals & Sound System

* **Hardware Cores:** Standard Z80 CTC and PIO units handle system timing and I/O communication, wired together in a priority interrupt daisy-chain.
* **Tape I/O (Cassette Interface):** Fully supports loading and saving data via a digital cassette simulation layer. The data output line (`UART_TX`) synthesizes an FSK signal via a flip-flop toggled by the CTC zero-crossing output. Incoming digitized audio streams (`UART_RX`) are read back through the memory-mapped keyboard register block.

---

## 4. Advanced Keyboard Decoder & Map

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

