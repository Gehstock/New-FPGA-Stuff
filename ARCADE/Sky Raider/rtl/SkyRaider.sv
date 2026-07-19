module SkyRaider (
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
	 output logic        UART_TX,
    input  logic        CLOCK_27
);

`include "rtl/build_id.v" 

    localparam CONF_STR = {
        "SkyRaider;;",
        "O1,Service Mode,Off,On;", 
        "O2,Ext. Play,Off,On;",	
		  "O3,Ext. Play Score,Low,High;",
		  "OCD,Play Time,60s,80s,100s,120s;", 
		  "O47,Coin Mode ,0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F;",
		  "O89,Language,Eng,Fr,Ger,Esp;",       
        "OAB,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",	
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };

    logic [31:0] status;
    logic  [1:0] buttons;
    logic  [1:0] switches;
    logic  [7:0] joystick_0;
    logic  [7:0] joystick_1;
    logic        scandoublerD;
    logic        ypbpr;
    logic signed [15:0] audio;
    logic        hs, vs;
    logic        blank;
    logic  [2:0] r, g, b;
    logic        key_strobe;
    logic        key_pressed;
    logic  [7:0] key_code;
    logic        clk24, clk12, pll_locked;
    logic        rst_n;
    logic        m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    logic        m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    logic        m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
    logic [1:0] scanlines;

    assign scanlines = status[11:10];
    assign AUDIO_R   = AUDIO_L;
    assign rst_n     = ~(buttons[1] | status[0]);
    assign LED       = 1'b1;

    pll pll (
        .inclk0 (CLOCK_27),
        .c0     (clk24),
        .c1     (clk12),
        .locked (pll_locked)
    );

    skyraid_top skyraid_top (
        .clk_12M        (clk12),
        .rst_n          (rst_n),
        .language_input ({2'b11, status[9:8], 4'b1111}),	  
        .dsw_input      ({status[2], 1'b1, status[13:12], 4'b1111}),
        .coin_input     ({m_coin2, m_coin1, ~m_fireA, status[3], status[7:4]}),
        .system_input   ({~status[1], ~m_one_player, 1'b1, ~m_tilt, 4'b1111}),		  
        .btn_left       (m_left),
        .btn_right      (m_right),
        .btn_up         (m_up),
        .btn_down       (m_down),
        .video_hsync    (hs),
        .video_vsync    (vs),
        .video_r        (r), 
        .video_g        (g), 
        .video_b        (b),
		  .video_blank		(blank),
        .audio_mixer    (audio),
		  .DBG				(UART_TX)
    );

    mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(9)) mist_video (
        .clk_sys             (clk24),
        .SPI_SCK             (SPI_SCK),
        .SPI_SS3             (SPI_SS3),
        .SPI_DI              (SPI_DI),
        .R                   (blank ? 3'b0 : r),
        .G                   (blank ? 3'b0 : g),
        .B                   (blank ? 3'b0 : b),
        .HSync               (hs),
        .VSync               (vs),
        .VGA_R               (VGA_R),
        .VGA_G               (VGA_G),
        .VGA_B               (VGA_B),
        .VGA_VS              (VGA_VS),
        .VGA_HS              (VGA_HS),
        .ce_divider          (1'b0),
        .scandoubler_disable (scandoublerD),
        .scanlines           (scanlines),
        .ypbpr               (ypbpr)
    );

    user_io #(.STRLEN(($size(CONF_STR) >> 3))) user_io (
        .clk_sys             (clk24),
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

    dac #(.C_bits(16)) dac (
        .clk_i   (clk24),
        .res_n_i (1'b1),
        .dac_i   ({audio[15],audio[14:0]}),
        .dac_o   (AUDIO_L)
    );
	
    arcade_inputs inputs (
        .clk         (clk24),
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

