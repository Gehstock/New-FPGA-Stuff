## Space Raider - MiST timing constraints

set_time_format -unit ns -decimal_places 3

create_clock -name {CLOCK_27} -period 37.037 -waveform { 0.000 18.518 } [get_ports {CLOCK_27}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.833 41.666 } [get_ports {SPI_SCK}]

derive_pll_clocks
derive_clock_uncertainty

# PLL outputs: clk[0] = 80 MHz system/SDRAM controller, clk[1] = 20 MHz game, clk[2] = 80 MHz -2.5ns SDRAM chip clock
set sys_clk   {pll|altpll_component|auto_generated|pll1|clk[0]}
set game_clk  {pll|altpll_component|auto_generated|pll1|clk[1]}
set sdram_clk {pll|altpll_component|auto_generated|pll1|clk[2]}

create_generated_clock -name SDRAM_CLK -source [get_pins $sdram_clk] [get_ports {SDRAM_CLK}]

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks [list $sys_clk $game_clk $sdram_clk]]

# SDRAM (MT48LC16M16, CL2)
set_input_delay  -clock SDRAM_CLK -max 6.4  [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock SDRAM_CLK -min 3.2  [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock SDRAM_CLK -max 1.5  [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_DQ[*] SDRAM_DQML SDRAM_DQMH SDRAM_nWE SDRAM_nCAS SDRAM_nRAS SDRAM_nCS SDRAM_CKE}]
set_output_delay -clock SDRAM_CLK -min -0.8 [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_DQ[*] SDRAM_DQML SDRAM_DQMH SDRAM_nWE SDRAM_nCAS SDRAM_nRAS SDRAM_nCS SDRAM_CKE}]
# read data is registered one clock after the SDRAM edge that launched it
set_multicycle_path -from [get_clocks {SDRAM_CLK}] -to [get_clocks $sys_clk] -setup -end 2

# 80 MHz -> 20 MHz: SDRAM ROM data/tags and OSD/status signals feeding the game.
# The CPUs only sample ROM data a full clk_sys after the tag matches (WAIT_n is registered),
# everything else is quasi static.
set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $game_clk] -setup -start 4
set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $game_clk] -hold  -start 3

# asynchronous / static outputs
set_false_path -to [get_ports {VGA_* AUDIO_L AUDIO_R LED SPI_DO}]
set_false_path -from [get_ports {SPI_DI SPI_SS2 SPI_SS3 SPI_SS4 CONF_DATA0}]
