module BKing_Mist (
    output logic        LED,
    output logic [5:0]  VGA_R,
    output logic [5:0]  VGA_G,
    output logic [5:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic        AUDIO_L,
    output logic        AUDIO_R,
    input  logic        SPI_SCK,
    output logic        SPI_DO,
    input  logic        SPI_DI,
    input  logic        SPI_SS2,
    input  logic        SPI_SS3,
    input  logic        CONF_DATA0,
//    output logic        UART_TX,
//    input  logic        UART_RX,
    input  logic        CLOCK_27,
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

    `include "rtl\build_id.sv" 
        localparam CONF_STR = {
        "BKing;rom;",
		  "O2,Blend,Off,On;",
        "O34,Scanlines,Off,25%,50%,75%;",
        "O5,Joystick Swap,Off,On;",
		  
		  "O6,Flip Screen,Off,On;",
		  "O7,Self Test,Off,On;",
		  "O8,Cabinet,Upright,Cocktail;",		  
		  "O9,Holes Awarded,0 Holes/Birdie,1 Holes/Birdie;",
		  "OA,Holes Awarded HIO,3 Holes,9 Holes;",
		  "OB,Free_Play,Off,On;",
		  "OCD,Holes Per Play,3,5,4,9;",
		  
		  
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };


    logic [63:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic [1:0]  scanlines;
    logic        blend;
    logic        joyswap;
    logic        flip, test, cabinet;
	 logic [1:0]  holesPP;
	 logic		  holes, holes_hio, free;

    assign scanlines = status[4:3];
    assign blend     = status[2];
    assign joyswap   = status[5];
	 
	 assign flip   	= status[6];
	 assign test   	= status[7];
	 assign cabinet   = status[8];
	 assign holes   	= status[9];
	 assign holes_hio = status[10];
	 assign holesPP 	= status[13:12];
	 assign free 		= status[11];
	 
    
    assign LED       = ~ioctl_downl;
    assign AUDIO_R   = AUDIO_L;
	 assign SDRAM_CLK = ~clk_72;
	 assign SDRAM_CKE = 1;
    
    logic clk_72, clk_12, pll_locked;

    pll pll (
        .inclk0         ( CLOCK_27 ),
		  .locked(pll_locked),
        .areset         ( 1'b0 ),
        .c0             ( clk_72 ),
        .c1             ( clk_12 )
    );

    logic        key_pressed;
    logic [7:0]  key_code;
    logic        key_strobe;
    logic [8:0]  RGB;
    logic [5:0]  r, g, b;
    logic        hs, vs, vb, hb;
    logic [15:0] audio;
    logic        scandoublerD;
    logic        ypbpr;
    logic        no_csync;

    logic m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    logic m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    logic m_up3, m_down3, m_left3, m_right3, m_fire3A, m_fire3B, m_fire3C, m_fire3D, m_fire3E, m_fire3F;
    logic m_up4, m_down4, m_left4, m_right4, m_fire4A, m_fire4B, m_fire4C, m_fire4D, m_fire4E, m_fire4F;
    logic m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
    logic [31:0] joystick_0, joystick_1, joystick_2, joystick_3;

wire [14:0] rom_addr;
wire [15:0] rom_do;
wire [12:0] snd_addr;
wire [15:0] snd_do;
wire        ioctl_downl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

data_io data_io (
	.clk_sys       ( clk_72      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
);

reg         port1_req, port2_req;
sdram #(.MHZ(72)) sdram(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_72      ),
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( ioctl_addr[23:1] ),
	.port1_ds      ( {ioctl_addr[0], ~ioctl_addr[0]} ),
	.port1_we      ( ioctl_downl ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       ( ),
	.cpu1_addr     ( ioctl_downl ? 15'h7fff : {1'b0, rom_addr[14:1]} ),
	.cpu1_q        ( rom_do ),
	.port2_req     ( port2_req ),
	.port2_ack     ( ),
	.port2_a       ( ioctl_addr[23:1] - 16'h4000 ),
	.port2_ds      ( {ioctl_addr[0], ~ioctl_addr[0]} ),
	.port2_we      ( ioctl_downl ),
	.port2_d       ( {ioctl_dout, ioctl_dout} ),
	.port2_q       ( ),
	.snd_addr      ( ioctl_downl ? 15'h7fff : {5'h0, snd_addr[12:1]} ),
	.snd_q         ( snd_do )
);

always @(posedge clk_72) begin
	reg        ioctl_wr_last = 0;

	ioctl_wr_last <= ioctl_wr;
	if (ioctl_downl && ioctl_index == 0) begin
		if (~ioctl_wr_last && ioctl_wr) begin
			port1_req <= ~port1_req;
			port2_req <= ~port2_req;
		end
	end
end

reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk_72) begin
	reg ioctl_downlD;
	ioctl_downlD <= ioctl_downl;
	if (ioctl_downlD & ~ioctl_downl) rom_loaded <= 1;
	reset <= status[0] | buttons[1] | ~rom_loaded;
end

BKing_Top BKing_Top(
    .clk        			( clk_12 ),
    .rst_n        		( ~reset ),
    .in0_din          	( {6'b111111, m_coin2, m_coin1} ),
    .in1_din          	( {6'b111111, ~m_two_players, ~m_one_player} ),
	 .dswa_din         	( {~cabinet, ~flip, ~test, ~holesPP, ~free, ~holes_hio, ~holes} ),//dswa
    .dswb_din         	( 8'h00 ),//dswb ),
    .dswc_din         	( 8'h7B ),//dswc ),
    .track0_x_din     	( joy_track0_x ),
    .track0_y_din     	( joy_track0_y ),
    .track1_x_din     	( joy_track1_x ),
    .track1_y_din     	( joy_track1_y ),
    .rom_addr				( rom_addr ),
    .rom_do					( rom_addr[0] ? rom_do[15:8] : rom_do[7:0] ),
	 .snd_addr				( snd_addr ),
    .snd_do					( snd_addr[0] ? snd_do[15:8] : snd_do[7:0] ),
    .Video_R            ( r ),
    .Video_G            ( g ),
    .Video_B            ( b ),
    .Video_HS        	( hs ),
    .Video_VS        	( vs ),
    .Video_HB       		( hb ),
    .Video_VB       		( vb ),
    .audio_out        	( audio )
);

    mist_video #(
        .COLOR_DEPTH(6), 
        .SD_HCNT_WIDTH(11)
    ) mist_video (
        .clk_sys             ( clk_72 ),
        .SPI_SCK             ( SPI_SCK ),
        .SPI_SS3             ( SPI_SS3 ),
        .SPI_DI              ( SPI_DI ),
        .R                   ( r ),
        .G                   ( g ),
        .B                   ( b ),
        .HSync               ( hs ),
        .VSync               ( vs ),
        .HBlank              ( hb ),
        .VBlank              ( vb ),
        .VGA_R               ( VGA_R ),
        .VGA_G               ( VGA_G ),
        .VGA_B               ( VGA_B ),
        .VGA_VS              ( VGA_VS ),
        .VGA_HS              ( VGA_HS ),
        .rotate              ( 2'b11 ),
        .ce_divider          ( 1'b1 ),
        .blend               ( blend ),
        .scandoubler_disable ( scandoublerD ),
        .no_csync            ( 1'b1 ),
        .ypbpr               ( ypbpr )
    );  

    user_io #(
        .STRLEN(($size(CONF_STR)>>3))
    ) user_io (
        .clk_sys             ( clk_72 ),
        .conf_str            ( CONF_STR ),
        .SPI_CLK             ( SPI_SCK ),
        .SPI_SS_IO           ( CONF_DATA0 ),
        .SPI_MISO            ( SPI_DO ),
        .SPI_MOSI            ( SPI_DI ),
        .buttons             ( buttons ),
        .switches            ( switches ),
        .scandoubler_disable ( scandoublerD ),
        .ypbpr               ( ypbpr ),
        .no_csync            ( no_csync ),
        .key_strobe          ( key_strobe ),
        .key_pressed         ( key_pressed ),
        .key_code            ( key_code ),
        .joystick_0          ( joystick_0 ),
        .joystick_1          ( joystick_1 ),
        .joystick_2          ( joystick_2 ), 
        .joystick_3          ( joystick_3 ),
        .status              ( status )
    );  

    dac #(
        .C_bits(16)
    ) dac (
        .clk_i               ( clk_72 ),
        .res_n_i             ( 1'b1 ),
        .dac_i               ( audio ),
        .dac_o               ( AUDIO_L )
    );

    arcade_inputs inputs (
        .clk                ( clk_72 ),
        .key_strobe         ( key_strobe ),
        .key_pressed        ( key_pressed ),
        .key_code           ( key_code ),
        .joystick_0         ( joystick_0 ),
        .joystick_1         ( joystick_1 ),
        .joystick_2         ( joystick_2 ),
        .joystick_3         ( joystick_3 ),
        .orientation        ( 2'b01 ),
        .joyswap            ( joyswap ),
        .oneplayer          ( 1'b0 ),
        .controls           ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
        .player1            ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
        .player2            ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} ),
        .player3            ( {m_fire3F, m_fire3E, m_fire3D, m_fire3C, m_fire3B, m_fire3A, m_up3, m_down3, m_left3, m_right3} ),
        .player4            ( {m_fire4F, m_fire4E, m_fire4D, m_fire4C, m_fire4B, m_fire4A, m_up4, m_down4, m_left4, m_right4} )
    );  
	 
	 
// Trackball EMU
    logic [7:0] joy_track0_x;
    logic [7:0] joy_track0_y;
    logic [7:0] joy_track1_x;
    logic [7:0] joy_track1_y;
    logic [15:0] track_tick_cnt;
    logic        track_pulse;	 
	 
	     always_ff @(posedge clk_72 or posedge reset) begin
        if (reset) begin
            track_tick_cnt <= 16'd0;
            track_pulse    <= 1'b0;
            joy_track0_x   <= 8'h00;
            joy_track0_y   <= 8'h00;
            joy_track1_x   <= 8'h00;
            joy_track1_y   <= 8'h00;
        end else begin
            if (track_tick_cnt >= 16'd45000) begin
                track_tick_cnt <= 16'd0;
                track_pulse    <= 1'b1;
            end else begin
                track_tick_cnt <= track_tick_cnt + 16'd1;
                track_pulse    <= 1'b0;
            end

            if (track_pulse) begin
                if (m_left)       joy_track0_y <= joy_track0_y - 8'd1;
                else if (m_right) joy_track0_y <= joy_track0_y + 8'd1;

                if (m_up)         joy_track0_x <= joy_track0_x + 8'd1;
                else if (m_down)  joy_track0_x <= joy_track0_x - 8'd1;

                if (m_left2)       joy_track1_y <= joy_track1_y - 8'd1;
                else if (m_right2) joy_track1_y <= joy_track1_y + 8'd1;

                if (m_up2)         joy_track1_x <= joy_track1_x + 8'd1;
                else if (m_down2)  joy_track1_x <= joy_track1_x - 8'd1;
            end
        end
    end

	
endmodule
