module Mole(
	output        LED,						
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        AUDIO_L,
	output        AUDIO_R,	
	input         SPI_SCK,
	output        SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,
	input         CLOCK_27,
	output		  UART_TX
);

`include "rtl\build_id.sv" 

localparam CONF_STR = {
	"Mole;;",
//	"O2,Rotate Controls,Off,On;",
	"O34,Scanlines,Off,25%,50%,75%;",
//	"O5,Blend,Off,On;",
	"O6,Passing Point,300,400;",
	"O7,Coinage,1C_1C,1C_2C;",
	"O8,Cabinet,Upright,Cocktail;",
	"O9A,Unknown,A,B,C,D;",
	"OBC,Unknown,A,B,C,D;",
	"T0,Reset;",
	"V,v1.15.",`BUILD_DATE
};

wire       rotate = status[2];
wire [1:0] scanlines = status[4:3];
wire       blend = status[5];
wire       cabinet = status[8];

assign LED = 1;
assign AUDIO_R = AUDIO_L;

wire clk_sys, clk_fpga;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_fpga),//40
	.c1(clk_sys)//4
);

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire        ps2_kbd_clk;
wire        ps2_kbd_data;

user_io #(.STRLEN(($size(CONF_STR)>>3)))user_io(
	.clk_sys        (clk_fpga       ),
	.conf_str       (CONF_STR       ),
	.SPI_CLK        (SPI_SCK        ),
	.SPI_SS_IO      (CONF_DATA0     ),
	.SPI_MISO       (SPI_DO         ),
	.SPI_MOSI       (SPI_DI         ),
	.buttons        (buttons        ),
	.switches       (switches       ),
	.scandoubler_disable (scandoublerD	  ),
	.ypbpr          (ypbpr          ),
	.no_csync       (no_csync       ),
	.ps2_kbd_clk	(ps2_kbd_clk),
	.ps2_kbd_data	(ps2_kbd_data),
	.status         (status         )
);
	
wire [9:0] audio;
wire       hs, vs, hb, vb;
wire  	  r, g, b;
wire			coin_input, start1_button, start2_button;
wire  [9:1] p1_buttons, p2_buttons;

mole_top mole_top (
    .clk_sys		(clk_sys),
    .rst_n			(~(status[0] | buttons[1])),
    .dip_switches		({2'b00, status[12:11], status[10:9], status[7], status[6]}),
	 .p1_buttons		(p1_buttons),
    .p2_buttons		(p2_buttons),
    .coin_input		(coin_input),
    .start1_button	(start1_button),
    .start2_button	(start2_button),// only Cocktail mode
    .cabinet	(cabinet),
    .video_hs		(hs),
    .video_vs		(vs),
	 .video_hb		(hb),
	 .video_vb		(vb),
    .video_r		(r),
	 .video_g		(g),
	 .video_b		(b),
    .audio			(audio)
);

mole_inputs mole_inputs (
    .clk_sys(clk_sys),
    .rst_n(~(status[0] | buttons[1])),
    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    .p1_buttons(p1_buttons),
    .p2_buttons(p2_buttons),
    .coin_input(coin_input),
    .start1_button(start1_button),
    .start2_button(start2_button)
);

mist_video #(.COLOR_DEPTH(1), .SD_HCNT_WIDTH(10)) mist_video(
	.clk_sys        ( clk_fpga         ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( r                ),
	.G              ( g                ),
	.B              ( b                ),
	.HSync          ( hs               ),
	.VSync          ( vs               ),
	.HBlank(hb),
	.VBlank(vb),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.ce_divider     ( 1'b0             ),
	.rotate         ( { 1'b1, rotate } ),
	.scandoubler_disable( scandoublerD ),
	.scanlines      ( scanlines        ),
	.blend          ( blend            ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
);

dac #(.C_bits(10))dac_l(
	.clk_i(clk_fpga),
	.res_n_i(1'b1),
	.dac_i(audio),
	.dac_o(AUDIO_L)
	);



endmodule
