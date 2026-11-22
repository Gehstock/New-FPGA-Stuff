module Mouser(
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
	"Mouser;;",
	"O1,Swap Joystick,Off,On;",
	"O2,Rotate Controls,Off,On;",
	"O34,Scanlines,Off,25%,50%,75%;",
	"O5,Blend,Off,On;",
	"O67,Lives,3,4,5,6;",
	"O89,Bonus Live,20000,40000,60000,80000;",
	"OA,Difficulty,Normal,Hard;",
	"OB,Cabinet,Cocktail,Upright;",
	"T0,Reset;",
	"V,v1.15.",`BUILD_DATE
};

wire       rotate = status[2];
wire [1:0] scanlines = status[4:3];
wire [1:0] lives = status[7:6];
wire [1:0] bonus = status[9:8];
wire       blend = status[5];
wire       difficulty = status[10];
wire       joyswap = status[1];
wire       cabinet = status[11];

assign LED = 1;
assign AUDIO_R = AUDIO_L;

wire clk_sys, clk_fpga;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_fpga),//36
	.c1(clk_sys)//12
);

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire        key_strobe;
wire        key_pressed;
wire  [7:0] key_code;

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
	.key_strobe     (key_strobe     ),
	.key_pressed    (key_pressed    ),
	.key_code       (key_code       ),
	.joystick_0     (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.status         (status         )
);
	
wire [9:0] audio;
wire       hs, vs, hb, vb;
wire [2:0] r, g, b;


mouser_top mouser_top (
    .clk_sys		(clk_sys),
    .rst_n			(~(status[0] | buttons[1])),
    .P1				({m_right, m_left, m_down, m_up, m_fireA, 3'b000}),
    .System			({2'b11,~difficulty,1'b1, ~m_two_players, ~m_one_player, ~m_coin2, ~m_coin1}),
    .DSW				({~cabinet, 3'b111, ~bonus, ~lives}),
    .P2				({m_right2, m_left2, m_down2, m_up2, m_fire2A, 3'b000}),
    .video_hs		(hs),
    .video_vs		(vs),
	 .video_hb		(hb),
	 .video_vb		(vb),
    .video_r		(r),
	 .video_g		(g),
	 .video_b		(b),
    .audio			(audio)
);


mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(10)) mist_video(
	.clk_sys        ( clk_fpga         ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( r                ),
	.G              ( g                ),
	.B              ( b                ),
	.HSync          ( hs               ),
	.VSync          ( vs               ),
	.HBlank         ( hb               ),
	.VBlank         ( vb               ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.ce_divider     ( 1'b0             ),
	.rotate         ( { 2'b11 } ),
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

wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
        
arcade_inputs inputs (
	.clk         ( clk_fpga    ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.rotate      ( rotate      ),
	.orientation ( 2'b11       ),
	.joyswap     ( joyswap     ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

endmodule
