`include "rtl\build_id.v"

module Nitedrvr_MiST(
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

localparam CONF_STR = {
	"NITEDRVR;;",
	"O12,Track,Novice,Expert,Pro,Service;",
	"O3,Bezel,On,Off;",
	"T0,Reset;",
	"V,v1.00.",`BUILD_DATE
};

wire       blend         = 1'b0;
assign 	   AUDIO_R       = AUDIO_L;

wire clk_sys, clk_core;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_sys),
	.c1(clk_core)
);

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire  [31:0] joystick_0;
wire  [31:0] joystick_1;
wire        scandoublerD;
wire        ypbpr;
wire  [7:0] audio;
wire        hs, vs, hb, vb;
wire 	[3:0] r, g, b;
assign		LED = 1'b1;
wire        key_strobe;
wire        key_pressed;
wire  [7:0] key_code;
wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
wire [1:0] track_select = status[2:1];
wire       novice        = (track_select == 2'b00);
wire       expert        = (track_select == 2'b01);
wire       pro           = (track_select == 2'b10);//  if not selected novice or expert
wire       dip_service   = (track_select == 2'b11);

nitedrvr_top nitedrvr_core (
    .clk_sys(clk_core),
    .rst_n(~(buttons[1] | status[0])),
    .dip_service(dip_service),
    .IN0({2'b00, expert, novice, ~m_fireA, ~m_one_player, ~m_coin2, ~m_coin1}),
    .gearup(m_up),
    .geardown(m_down),
	 .bezel_active(~status[3]),
    .steer_left_btn(m_left),
    .steer_right_btn(m_right),
    .video_h_sync(hs),
    .video_v_sync(vs),
	 .video_h_blank(hb),
    .video_v_blank(vb),
    .video_r(r),
	 .video_g(g),
	 .video_b(b),
    .audio_out(audio)
);

mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(10)) mist_video(
	.clk_sys        ( clk_sys          ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( r            		),
	.G              ( g            		),
	.B              ( b            		),
	.HSync          ( hs               ),
	.VSync          ( vs               ),
	.HBlank         ( hb               ),
	.VBlank         ( vb               ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.ce_divider		( 0				   ),
	.scandoubler_disable( scandoublerD ),
	.scanlines      ( 2'b00            ),
	.blend          ( blend            ),
	.ypbpr          ( ypbpr            )
);

user_io #(.STRLEN(($size(CONF_STR)>>3)))user_io(
	.clk_sys        (clk_sys        ),
	.conf_str       (CONF_STR       ),
	.SPI_CLK        (SPI_SCK        ),
	.SPI_SS_IO      (CONF_DATA0     ),
	.SPI_MISO       (SPI_DO         ),
	.SPI_MOSI       (SPI_DI         ),
	.buttons        (buttons        ),
	.switches       (switches       ),
	.scandoubler_disable (scandoublerD	),
	.ypbpr          (ypbpr          ),
	.key_strobe     (key_strobe     ),
	.key_pressed    (key_pressed    ),
	.key_code       (key_code       ),
	.joystick_0     (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.status         (status         )
);

dac #(.C_bits(8)) dac (
	.clk_i(clk_sys),
	.res_n_i(1'b1),
	.dac_i(audio),
	.dac_o(AUDIO_L)
);

arcade_inputs #(.START1(10), .START2(12), .COIN1(11)) inputs (
	.clk         ( clk_sys     ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.rotate      ( 1'b0        ),
	.orientation ( 2'b10       ),
	.joyswap     ( 1'b0        ),
	.oneplayer   ( 1'b1        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

endmodule
