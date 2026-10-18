
Mole Attack Arcade Core for MiST

This repository contains the  FPGA core for the arcade game Mole Attack, released in 1982 by Yachiyo Electronics Co., LTD

🛠️ Original Hardware Specifications

• Central Processing Unit (CPU): MOS 6502 @ 2.0 MHz (emulated via T65 core)
• System RAM: 1024 Bytes (1 KB) main work RAM (0000–03FF)
• Audio Hardware: General Instrument AY-3-8910 / YM2149 @ 2.0 MHz
• Video Resolution: Tilemap-based with 40×25 tiles (each tile is 8×8 pixels)
• Color Depth: 3 bits per pixel (planar layout)

🎮 Controls & Keyboard Mapping

The gameplay utilizes a unique 3×3 hammer pad layout (Whack-a-Mole). To accurately reproduce this configuration on modern USB or PS/2 keyboards, the core implements the following mapping:

Row 3 (Top)

• Hole 7 (Top Left): Key Q (Player 1) / Numpad 7 (Player 2) only in Cocktail Mode
• Hole 8 (Top Center): Key W (Player 1) / Numpad 8 (Player 2)
• Hole 9 (Top Right): Key E (Player 1) / Numpad 9 (Player 2)

Row 2 (Center)

• Hole 4 (Center Left): Key A (Player 1) / Numpad 4 (Player 2)
• Hole 5 (Center Center): Key S (Player 1) / Numpad 5 (Player 2)
• Hole 6 (Center Right): Key D (Player 1) / Numpad 6 (Player 2)

Row 1 (Bottom)

• Hole 1 (Bottom Left): Key Z (Player 1) / Numpad 1 (Player 2)
• Hole 2 (Bottom Center): Key X (Player 1) / Numpad 2 (Player 2)
• Hole 3 (Bottom Right): Key C (Player 1) / Numpad 3 (Player 2)

System Controls

• Insert Coin: ESC
• Player 1 Start: 1
• Player 2 Start: 2



ToDo: Sound
