module MrsDyna(
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
	input         SPI_SS4,
	input         CONF_DATA0,
	input         CLOCK_27,
	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE
);

`include "rtl\build_id.v" 

localparam CONF_STR = {
	"MrsDyna;rom;",
	"O2,Allow Continue,No,Yes;",
	"O34,Scanlines,Off,25%,50%,75%;",
	"O5,Service Mode,Off,On;",
	"O6,Blending,Off,On;",
	"O7,High Score Letters,12,3;",
	"O89,Lives,3,4,5,2;",
	"OA,Cabinet,Upright,Cocktail;",
	"OBC,Difficulty,Easy,Medium,Hard,Hardest;",
	"OGJ,Coin A,1C/1C,2C/1C,3C/1C,4C/1C,5C/1C,1C/2C,2C/2C,1C/3C,2C/3C,1C/4C,1C/1C(A),1C/1C(B),1C/1C(C),1C/1C(D),1C/1C(E),Free Play;",
	"OKN,Coin B,1C/1C,2C/1C,3C/1C,4C/1C,5C/1C,1C/2C,2C/2C,1C/3C,2C/3C,1C/4C,1C/1C(A),1C/1C(B),1C/1C(C),1C/1C(D),1C/1C(E),Free Play;",
	"T0,Reset;",
	"V,v1.00.",`BUILD_DATE
};

wire       Continue   = status[2];
wire       Names      = status[7];
wire [1:0] Lives      = status[9:8];
wire       Cabinet    = status[10];
wire [1:0] Difficulty = status[12:11];
wire [3:0] Coin1      = status[19:16];
wire [3:0] Coin2      = status[23:20];

wire clk40, clk20, clk_sd, pll_locked;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk40),
	.c1(clk20),
	.c2(clk_sd),
	.locked(pll_locked)
	);	
	
assign LED = ~ioctl_downl;
assign SDRAM_CLK = clk_sd;
assign SDRAM_CKE = 1;
assign AUDIO_R = AUDIO_L;
		
wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [11:0] kbjoy;
wire [31:0] joystick_0, joystick_1;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire        key_pressed;
wire  [7:0] key_code;
wire        key_strobe;
wire  [13:0]	audio;
wire	[1:0]	r, g, b;
wire hs, vs, cs, hb, vb;
wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
wire        ioctl_downl, ioctl_upl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout, ioctl_din;
wire [14:0] main_rom_addr;
wire [15:0] main_rom_do;
wire [14:0] sub_rom_addr;
wire [15:0] sub_rom_do;
//wire [11:0] grid_rom_addr;
//reg  [7:0]  grid_rom_do;
//wire [11:0] tile_rom_addr;
//wire [15:0] tile_rom_do;
//wire [11:0] sprite_rom_addr;
//wire [15:0] sprite_rom_do;
//wire [15:0] tile_rom_do   = tile_rom_addr ? chr1_do_32[31:16] : chr1_do_32[15:0];
//wire [15:0] sprite_rom_do = sprite_rom_addr ? sp_do_32[31:16] : sp_do_32[15:0];
wire clkref;

data_io #(.ROM_DIRECT_UPLOAD(1'b1)) data_io(
	.clk_sys       ( clk40      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.clkref_n      ( 1'b0         ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
);

reg port1_req = 1'b0, port2_req = 1'b0;
wire [15:0] port1_q_dummy;
wire [15:0] port2_q_dummy;

reg  [7:0] dl_lo;
reg [15:0] dl_d;
reg [23:1] dl_a, dl_sp_a;
wire [24:0] sp_ioctl_addr = ioctl_addr - 20'h8000;

always @(posedge clk40) begin
	reg        ioctl_wr_last = 0;

	ioctl_wr_last <= ioctl_wr;
	if (ioctl_downl & ~ioctl_wr_last & ioctl_wr) begin
		if (~ioctl_addr[0])
			dl_lo <= ioctl_dout;
		else begin
			dl_d <= {ioctl_dout, dl_lo};
			dl_a <= ioctl_addr[23:1];
			port1_req <= ~port1_req;
			if (ioctl_addr >= 20'h10000) begin
				dl_sp_a <= sp_ioctl_addr[23:1];
				port2_req <= ~port2_req;
			end
		end
	end
end

reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk40) begin
	reg ioctl_downlD;
	ioctl_downlD <= ioctl_downl;

	if (ioctl_downlD & ~ioctl_downl) rom_loaded <= 1;
	reset <= status[0] | buttons[1] | ~rom_loaded;
end

wire [31:0] chr1_do_32;	// CHAR
wire [31:0] chr2_do_32; // GRID
wire [31:0] sp_do_32;	// SPRITE
wire [16:0] cpu1_sd_addr = ioctl_downl ? 17'h1ffff : {3'b000, main_rom_addr[14:1]};
wire [16:0] cpu2_sd_addr = ioctl_downl ? 17'h1ffff : ({3'b000, sub_rom_addr[14:1]} + 17'h04000); // sub ROM at byte 0x8000
wire [16:0] cpu1_sd_qa, cpu2_sd_qa;
sdram #(
    .MHZ(16'd80)
) u_sdram (
    .*,
    .init_n        ( pll_locked   ),
    .clk           ( clk40        ),
    .clkref        ( clkref         ),

    .port1_req     ( port1_req    ),
    .port1_ack     ( ),
    .port1_a       ( dl_a         ),
    .port1_ds      ( 2'b11        ), 
    .port1_we      ( ioctl_downl  ),
    .port1_d       ( dl_d         ),
    .port1_q       ( ),
    .cpu1_addr     ( cpu1_sd_addr ),
    .cpu1_q        ( main_rom_do  ), 
    .cpu1_qa       ( cpu1_sd_qa   ),
    .cpu2_addr     ( cpu2_sd_addr ),
    .cpu2_q        ( sub_rom_do   ), 
    .cpu2_qa       ( cpu2_sd_qa   ),
	 
    .port2_req     ( port2_req    ),
    .port2_ack     ( ),
    .port2_a       ( dl_sp_a      ),
    .port2_ds      ( 2'b11        ),
    .port2_we      ( ioctl_downl  ),
    .port2_d       ( dl_d         ),
    .port2_q       ( ),
    .chr1_addr     ( 17'h1ffff),//{6'd0, tile_rom_addr[11:2]}   ), 
    .chr1_q        ( chr1_do_32                    ), 
    .chr2_addr     ( 17'h1ffff),//{6'd0, grid_rom_addr[11:2]} + 17'h08000 ), 
    .chr2_q        ( chr2_do_32                    ),
    .sp_addr       ( 17'h1ffff),//{5'd0, sprite_rom_addr[11:2]} + 17'h04000 ), 
    .sp_q          ( sp_do_32                      )  
);

//always @(*) begin
//    case (grid_rom_addr[1:0])
//        2'b00: grid_rom_do = chr2_do_32[7:0];
//        2'b01: grid_rom_do = chr2_do_32[15:8];
//        2'b10: grid_rom_do = chr2_do_32[23:16];
//        2'b11: grid_rom_do = chr2_do_32[31:24];
//    endcase
//end


mrsdyna_top mrsdyna_top (
    .clk_sys(clk20),
    .rst_n(~reset),
	 .clkref(clkref),
    .in0_i(~{m_tilt, m_two_players, m_one_player, m_fireA | status[5], m_up, m_right, m_down, m_left}),
    .in1_i(~{m_coin2, m_coin1, vb, m_fire2A, m_up2, m_right2, m_down2, m_left2}),
    .dsw0_i({~Lives, Cabinet, 1'b1, ~Continue, ~Names, ~Difficulty}),
    .dsw1_i(~{Coin2,Coin1}),
    .video_r(r),
    .video_g(g),
    .video_b(b),
    .video_hsync(hs),
    .video_vsync(vs),
    .video_vblank(vb),
	 .video_hblank(hb),
    .audio_o(audio),
	 .cpu1_rom_addr(main_rom_addr),//15bit
	 .cpu1_rom_q(main_rom_addr[0] ? main_rom_do[15:8] : main_rom_do[7:0] ),//8bit
	 .cpu1_rom_valid(cpu1_sd_qa == cpu1_sd_addr),
	 .cpu2_rom_addr(sub_rom_addr),//15bit
	 .cpu2_rom_q(sub_rom_addr[0] ? sub_rom_do[15:8] : sub_rom_do[7:0]),//8bit
	 .cpu2_rom_valid(cpu2_sd_qa == cpu2_sd_addr)
);

user_io #(
	.STRLEN(($size(CONF_STR)>>3)))
user_io(
	.clk_sys        (clk40        ),
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
	.COLOR_DEPTH(2), 
	.SD_HCNT_WIDTH(10),
	.BIG_OSD(1'b0))
mist_video(
	.clk_sys        ( clk40           	),
	.SPI_SCK        ( SPI_SCK          	),
	.SPI_SS3        ( SPI_SS3          	),
	.SPI_DI         ( SPI_DI           	),
	.R					 ( r               	),
	.G					 ( g               	),
	.B					 ( b               	),
	.HSync          ( hs               	),
	.VSync          ( vs               	),
	.HBlank         ( hb               	),
	.VBlank         ( vb               	),
	.VGA_R          ( VGA_R           	),
	.VGA_G          ( VGA_G            	),
	.VGA_B          ( VGA_B            	),
	.VGA_VS         ( VGA_VS           	),
	.VGA_HS         ( VGA_HS           	),
	.scanlines      ( status[4:3]      	),
	.rotate         ( 2'b01 	),
//	.ce_divider     ( 1'b1             	),
	.blend          ( status[6]        	),
	.scandoubler_disable(scandoublerD  	),
	.no_csync       ( no_csync         	),
	.ypbpr          ( ypbpr            	)
	);

dac #(
	.C_bits(14))
dac_l(
	.clk_i(clk40),
	.res_n_i(1),
	.dac_i(audio),
	.dac_o(AUDIO_L)
	);

arcade_inputs inputs (
	.clk         ( clk40      ),
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
