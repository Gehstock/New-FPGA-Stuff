module Route16(
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
	"Route16;;",
	"O1,Swap Joystick,Off,On;",
	"O34,Scanlines,Off,25%,50%,75%;",
	"O5,Blend,Off,On;",
	"O6,Service,Off,On;",
	"DIP;",
	"T0,Reset;",
	"V,v1.15.",`BUILD_DATE
};

wire [1:0] scanlines = status[4:3];
wire       blend     = status[5];
wire       joyswap   = status[1];
wire       service   = status[6];

assign LED     = ~ioctl_download;
assign AUDIO_R = AUDIO_L;

wire clk_sys, clk_fpga;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_fpga),
	.c1(clk_sys)
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
wire  [6:0] core_mod;

user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io(
	.clk_sys             (clk_fpga       ),
	.conf_str            (CONF_STR       ),
	.SPI_CLK             (SPI_SCK        ),
	.SPI_SS_IO           (CONF_DATA0     ),
	.SPI_MISO            (SPI_DO         ),
	.SPI_MOSI            (SPI_DI         ),
	.buttons             (buttons        ),
	.switches            (switches       ),
	.scandoubler_disable (scandoublerD   ),
	.ypbpr               (ypbpr          ),
	.no_csync            (no_csync       ),
	.key_strobe          (key_strobe     ),
	.key_pressed         (key_pressed    ),
	.key_code            (key_code       ),
	.joystick_0          (joystick_0     ),
	.joystick_1          (joystick_1     ),
	.status              (status         ),
	.core_mod            (core_mod       )
);

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;

data_io data_io (
	.clk_sys        (clk_sys        ),
	.SPI_SCK        (SPI_SCK        ),
	.SPI_SS2        (SPI_SS2        ),
	.SPI_DI         (SPI_DI         ),
	.ioctl_download (ioctl_download ),
	.ioctl_index    (ioctl_index    ),
	.ioctl_wr       (ioctl_wr       ),
	.ioctl_addr     (ioctl_addr     ),
	.ioctl_dout     (ioctl_dout     )
);
	
wire [9:0] audio;
wire       hs, vs, hb, vb;
wire [2:0] r, g, b;
reg [7:0] p1, p2;

always_comb begin
	case (core_mod[2:0])
		3'd0, 3'd1: begin
			// Route 16 (0) & Route X (1)
			p1 = {m_coin1, service, 1'b0, m_fireA, m_down, m_up, m_left, m_right};
			p2 = {m_one_player, m_two_players, 1'b0, m_fire2A, m_down2, m_up2, m_left2, m_right2};
		end
		3'd2, 3'd3: begin
			// Stratovox / Speak & Rescue (2) & Speak & Help / Space Echo (3)
			p1 = {m_coin1, service, 1'b0, m_fireA, 2'b00, m_left, m_right};
			p2 = {m_one_player, m_two_players, 1'b0, m_fire2A, 2'b00, m_left2, m_right2};
		end
		default: begin
			p1 = {m_coin1, service, 1'b0, m_fireA, m_down, m_up, m_left, m_right};
			p2 = {m_one_player, m_two_players, 1'b0, m_fire2A, m_down2, m_up2, m_left2, m_right2};
		end
	endcase
end


reg [7:0] dip_sw[8] = '{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};
always @(posedge clk_sys) begin
	if (ioctl_wr && (ioctl_index == 8'd254) && !ioctl_addr[24:3])
		dip_sw[ioctl_addr[2:0]] <= ioctl_dout;
end
wire [7:0] sw1 = dip_sw[0];

Route16_Top Route16_Top (
	.clk            (clk_sys),
	.reset          (status[0] | buttons[1] | ioctl_download),
	.core_mod       (core_mod[2:0]),
	.dsw            (sw1),
	.p1_input       (p1),
	.p2_input       (p2),
	.ioctl_download (ioctl_download),
	.ioctl_index    (ioctl_index),
	.ioctl_wr       (ioctl_wr),
	.ioctl_addr     (ioctl_addr),
	.ioctl_dout     (ioctl_dout),
	.video_r        (r),
	.video_g        (g),
	.video_b        (b),
	.video_hs       (hs),
	.video_vs       (vs),
	.video_hb       (hb),
	.video_vb       (vb),
	.audio          (audio)
);

mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(10)) mist_video(
	.clk_sys             ( clk_fpga     ),
	.SPI_SCK             ( SPI_SCK      ),
	.SPI_SS3             ( SPI_SS3      ),
	.SPI_DI              ( SPI_DI       ),
	.R                   ( r            ),
	.G                   ( g            ),
	.B                   ( b            ),
	.HSync               ( hs           ),
	.VSync               ( vs           ),
	.HBlank              ( hb           ),
	.VBlank              ( vb           ),
	.VGA_R               ( VGA_R        ),
	.VGA_G               ( VGA_G        ),
	.VGA_B               ( VGA_B        ),
	.VGA_VS              ( VGA_VS       ),
	.VGA_HS              ( VGA_HS       ),
	.ce_divider          ( 1'b0         ),
	.rotate              ( { 2'b01 }    ),
	.scandoubler_disable ( scandoublerD ),
	.scanlines           ( scanlines    ),
	.blend               ( blend        ),
	.ypbpr               ( ypbpr        ),
	.no_csync            ( no_csync     )
);

dac #(.C_bits(10)) dac_l(
	.clk_i   (clk_fpga),
	.res_n_i (1'b1),
	.dac_i   (audio),
	.dac_o   (AUDIO_L)
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
	.joyswap     ( joyswap     ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

endmodule
