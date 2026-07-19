# 1. Den physischen Eingangstakt (27 MHz) definieren
create_clock -name clk_ref -period 37.037 [get_ports {CLOCK_27}]

# 2. Den SPI-Takt (vom MiST-User-IO / Controller) als Taktquelle anmelden
# Das beseitigt die Warnungen "Node: SPI_SCK was determined to be a clock..."
# Wir definieren hier eine sichere Frequenz von 16 MHz (62.5 ns)
create_clock -name spi_sck -period 62.500 [get_ports {SPI_SCK}]

# 3. Die Ausgänge der PLL (80 MHz, 12 MHz, 2 MHz) automatisch ableiten
derive_pll_clocks

# 4. Takt-Unsicherheiten (Jitter und Skew) automatisch berechnen lassen
derive_clock_uncertainty

# 5. Timing für Ihre ECHTEN Video-Ausgangspins festlegen
# Quartus zwingt den Fitter nun, das Routing zu den VGA-Pins extrem straff zu halten,
# damit die Pixeldaten exakt synchron mit den Sync-Signalen am Monitor ankommen.
# Betrifft den 12 MHz Pixeltakt (wird intern als clk[1] referenziert)
set_output_delay -clock [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -max 5.0 [get_ports {VGA_HS VGA_VS VGA_R[*] VGA_G[*] VGA_B[*]}]
set_output_delay -clock [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -min -1.0 [get_ports {VGA_HS VGA_VS VGA_R[*] VGA_G[*] VGA_B[*]}]

# 6. Falsche Pfade (False Paths) definieren
# Entlastet den Compiler beim Datenaustausch zwischen der 2 MHz CPU-Welt und der 12 MHz Video-Welt.
# Das VRAM entkoppelt diese Bereiche hardwareseitig, daher darf Quartus hier die Optimierung ignorieren.
set_false_path -from [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[2]}]

# Auch die Kommunikation zwischen dem SPI-Takt (Schnittstelle) und dem System-Takt ist asynchron
set_false_path -from [get_clocks {spi_sck}] -to [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[2]}]
