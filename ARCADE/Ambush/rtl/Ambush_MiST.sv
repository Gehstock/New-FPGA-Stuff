module Ambush_MiST(
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
	input         CLOCK_27
);

`include "rtl\build_id.sv" 

localparam CONF_STR = {
	"Ambush;;",
	"O12,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"O34,Lives,3,4,5,6;",
	"O5,Allow Continue,No,Yes;",
 	"O6,Service/FreePlay,No,Yes;",
	"O7,Coinage,No,Yes;",
 	"O8,Difficulty,Easy,Hard;",
   "O9,Bonus_Life,120000,80000;",
   "OA,Cabinet,Cocktail,Upright;",
	"T0,Reset;",
	"V,v1.10.",`BUILD_DATE
};

assign LED = 1'b1;
assign AUDIO_R = AUDIO_L;
wire clk_36, clk_18, locked;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_36),//36.864
	.c1(clk_18),//18.432
	.locked(locked)
	);


wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [11:0] kbjoy;
wire [31:0] joystick_0;
wire [31:0] joystick_1;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire        key_pressed;
wire  [7:0] key_code;
wire        key_strobe;
wire  [8:0]	audio;
wire	[2:0] Vid_r, Vid_g, Vid_b;
wire hs, vs, cs, hb, vb;


Ambush_Top Ambush_Top (
	.clk_sys					( clk_18 ),         
	.reset					( status[0] || buttons[1]),
	.BUTTONS					(~{m_coin1, m_coin2, m_one_player, m_two_players, m_fire2A, m_fire2B, m_fireA, m_fireB}),
	.JOYSTICK				(~{m_right2, m_left2, m_down2, m_up2, m_right, m_left, m_down, m_up}),
	.SW1						(~{status[4:3],status[5],status[6],status[7],status[8],status[9],status[10]} ),
	.hsync					( hs ),
	.vsync					( vs ),
	.hblank					( hb ),
	.vblank					( vb ),
	.video_r					( Vid_r ),
	.video_g					( Vid_g ),
	.video_b					( Vid_b ),
	.audio					( audio )
	);

user_io #(
	.STRLEN(($size(CONF_STR)>>3)))
user_io(
	.clk_sys        (clk_36         ),
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
	
mist_video #(
	.COLOR_DEPTH(3), 
	.SD_HCNT_WIDTH(9)) 
mist_video(
	.clk_sys        ( clk_36           ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R					 ( Vid_r ),
	.G					 ( Vid_g ),
	.B					 ( Vid_b ),
	.HSync          ( hs               ),
	.VSync          ( vs               ),
	.HBlank          ( hb               ),
	.VBlank          ( vb               ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.scanlines      ( status[2:1]      ),
//	.rotate         ( { 1'b1, rotate } ),
//	.ce_divider     ( 1'b1             ),
//	.blend          ( status[6]        ),
	.scandoubler_disable(scandoublerD  ),
	.no_csync       ( no_csync         ),
	.ypbpr          ( ypbpr            )
	);

dac #(
	.C_bits(9))
dac_l(
	.clk_i(clk_36),
	.res_n_i(1),
	.dac_i(audio),
	.dac_o(AUDIO_L)
	);

wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs inputs (
	.clk         ( clk_36      ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
//	.rotate      ( rotate      ),
//	.orientation ( 2'b11       ),
	.joyswap     ( 1'b0        ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

endmodule 