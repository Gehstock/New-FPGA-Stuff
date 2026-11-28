module Cheekyms (
    output logic        LED,
    output logic  [5:0] VGA_R,
    output logic  [5:0] VGA_G,
    output logic  [5:0] VGA_B,
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
    input  logic        CLOCK_27
);

`include "rtl/build_id.v" 

    localparam CONF_STR = {
        "Cheekyms;;",
        "O12,Lives,3,2,4,5;", 
        "O34,Coinage,1C 1C,2C 1C,1C 2C,Free Play;",	
        "O5,Cabinet,Upright,Cocktail;",
        "O6,Demo Sounds,On,Off;",
        "O78,Bonus Life,3000,4500,6000,None;",
        "O9A,Scanlines,None,CRT 25%,CRT 50%,CRT 75%;",	
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };
	 
	 wire [1:0] lives = status[2:1];
	 wire [1:0] coinage = status[4:3];
	 wire			cabinet = status[5];
	 wire			demo = status[6];
	 wire [1:0] bonus = status[8:7];
	 wire [1:0] scanlines = status[10:9];

    logic [63:0] status;
    logic  [1:0] buttons;
    logic  [1:0] switches;
    logic  [7:0] joystick_0, joystick_1;
    logic        scandoublerD;
    logic        ypbpr;
    logic  [7:0] audio;
    logic        hs, vs, hb, vb;
    logic        r, g, b;
    logic        key_strobe;
    logic        key_pressed;
    logic  [7:0] key_code;
    logic        clk36, clk12, pll_locked;
    logic        rst_n;
    logic        m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    logic        m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    logic        m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player;



    assign AUDIO_R   = AUDIO_L;
	 assign LED = 1'b1;

    pll pll (
        .inclk0 (CLOCK_27),
        .c0     (clk36), // 43.26400000 MHz
        .c1     (clk12), // 21.632
        .locked (pll_locked)
    );

    cheekyms_top cheekyms_top (
        .clk_sys(clk12),              
        .rst_n(~(buttons[1] | status[0])),                
        .p1_inputs({~m_fireA, ~m_left, ~m_right, ~m_fire2A, ~m_left2, ~m_right2, ~m_two_players, ~m_one_player}),          
        .dip_switches({bonus, demo, cabinet, coinage, lives}),      
        .coin_pulse(m_coin1), 
        .audio(audio),
		  .video_r(r),
		  .video_g(g),
		  .video_b(b),
        .video_hs(hs),
        .video_vs(vs),
        .video_hb(hb),
        .video_vb(vb)
    );

    mist_video #(.COLOR_DEPTH(1), .SD_HCNT_WIDTH(11)) mist_video (
        .clk_sys             (clk36),
        .SPI_SCK             (SPI_SCK),
        .SPI_SS3             (SPI_SS3),
        .SPI_DI              (SPI_DI),
        .R                   (r),
        .G                   (g),
        .B                   (b),
        .HSync               (hs),
        .VSync               (vs),
		  .HBlank              (hb),
		  .VBlank              (vb),
        .VGA_R               (VGA_R),
        .VGA_G               (VGA_G),
        .VGA_B               (VGA_B),
        .VGA_VS              (VGA_VS),
        .VGA_HS              (VGA_HS),
        .ce_divider          (1'b1),
		  .rotate				  (2'b01),
        .scandoubler_disable (scandoublerD),
        .scanlines           (scanlines),
        .ypbpr               (ypbpr)
    );

    user_io #(.STRLEN(($size(CONF_STR) >> 3))) user_io (
        .clk_sys             (clk36),
        .conf_str            (CONF_STR),
        .SPI_CLK             (SPI_SCK),
        .SPI_SS_IO           (CONF_DATA0),
        .SPI_MISO            (SPI_DO),
        .SPI_MOSI            (SPI_DI),
        .buttons             (buttons),
        .switches            (switches),
        .scandoubler_disable (scandoublerD),
        .ypbpr               (ypbpr),
        .key_strobe          (key_strobe),
        .key_pressed         (key_pressed),
        .key_code            (key_code),
        .joystick_0          (joystick_0),
        .joystick_1          (joystick_1),
        .status              (status)
    );

    dac #(.C_bits(8)) dac (
        .clk_i   (clk36),
        .res_n_i (1'b1),
        .dac_i   (audio),
        .dac_o   (AUDIO_L)
    );
	
    arcade_inputs inputs (
        .clk         (clk36),
        .key_strobe  (key_strobe),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .joystick_0  (joystick_0),
        .joystick_1  (joystick_1),
        .oneplayer   (1'b1),
        .controls    ({m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player}),
        .player1     ({m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right}),
        .player2     ({m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2})
    );

endmodule
