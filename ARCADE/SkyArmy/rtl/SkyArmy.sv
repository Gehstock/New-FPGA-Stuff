module SkyArmy(
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
    "SkyArmy;;",
    "O2,Rotate Controls,Off,On;",
    "O34,Scanlines,Off,25%,50%,75%;",
    "O5,Blend,Off,On;",
    "O6,Joystick Swap,Off,On;",
    "O89,Lives,3,2,4,Infinite;",
    "OAB,Bonus Life,10000,20000,30000,40000;",
    "OCD,Coinage,1C_1C,3C_1C,2C_1C,1C_2C;",
    "OE,Flip Screen,Off,On;",
    "OF,Cabinet,Upright,Cocktail;",
    "T0,Reset;",
    "V,v1.00."
};


    wire          rotate = status[2];
    wire [1:0]    scanlines = status[4:3];
    wire          blend = status[5];
    wire          joyswap = status[6];
    wire [1:0]    orientation = 2'b11;
	 wire [1:0] dsw_lives      = status[9:8];
    wire [1:0] dsw_bonus_life = status[11:10];
    wire [1:0] dsw_coinage    = status[13:12];
    wire       dsw_flip       = status[14];
    wire       dsw_cabinet    = status[15];
    assign        LED = 1'b1;
    assign        AUDIO_R = AUDIO_L;

    wire clk_36, clk_18, pll_locked;
    pll pll(
        .inclk0(CLOCK_27),
        .c0(clk_36),
        .c1(clk_18),
        .locked(pll_locked)
    );

    wire [31:0] status;
    wire  [1:0] buttons;
    wire  [1:0] switches;
    wire [11:0] kbjoy;
    wire  [31:0] joystick_0;
    wire  [31:0] joystick_1;
    wire        scandoublerD;
    wire        ypbpr;
    wire        no_csync;
    wire [8:0] audio;
    wire        hs, vs, cs, blank;
    wire [3:0]  r, g, b;
    wire        key_strobe;
    wire        key_pressed;
    wire  [7:0] key_code;
	 
    wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
    wire [7:0] dsw_mapped = { dsw_cabinet, dsw_flip, dsw_coinage, dsw_bonus_life, dsw_lives };
    wire [7:0] p1_mapped     = {2'b00, m_fireB, m_fireA, m_right, m_left, m_down, m_up};
    wire [7:0] p2_mapped     = {2'b00, m_fire2B, m_fire2A, m_right2, m_left2, m_down2, m_up2};
    wire [7:0] system_mapped = {5'b00000, m_two_players, m_one_player, m_coin1};
skyarmy_main skyarmy_main (
    .clk_sys(clk_18),
    .rst_n(~(status[0] || buttons[1])),
    .dsw_input(dsw_mapped),
    .p1_input(p1_mapped),
    .p2_input(p2_mapped),
    .system_input(system_mapped),
    .blank(blank),
    .hsync(hs),
    .vsync(vs),
    .video_r(r),
    .video_g(g),
    .video_b(b),
    .audio_out(audio)
);

    mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(10)) mist_video(
        .clk_sys        (clk_36),
        .SPI_SCK        (SPI_SCK),
        .SPI_SS3        (SPI_SS3),
        .SPI_DI         (SPI_DI),
        .R              (~blank ? r : 4'b0000),
        .G              (~blank ? g : 4'b0000),
        .B              (~blank ? b : 4'b0000),
        .HSync          (hs),
        .VSync          (vs),
        .VGA_R          (VGA_R),
        .VGA_G          (VGA_G),
        .VGA_B          (VGA_B),
        .VGA_VS         (VGA_VS),
        .VGA_HS         (VGA_HS),
        .ce_divider     (3'd5),  // 36MHz / 6 = 6MHz actual pixel clock
        .blend          (blend),
        .scandoubler_disable(scandoublerD),
        .rotate         ({orientation[1], rotate}),
        .scanlines      (scanlines),
        .ypbpr          (ypbpr),
        .no_csync       (no_csync)
    );
    
    user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io(
        .clk_sys        (clk_36),
        .conf_str       (CONF_STR),
        .SPI_CLK        (SPI_SCK),
        .SPI_SS_IO      (CONF_DATA0),
        .SPI_MISO       (SPI_DO),
        .SPI_MOSI       (SPI_DI),
        .buttons        (buttons),
        .switches       (switches),
        .scandoubler_disable (scandoublerD),
        .ypbpr          (ypbpr),
        .no_csync       (no_csync),
        .key_strobe     (key_strobe),
        .key_pressed    (key_pressed),
        .key_code       (key_code),
        .joystick_0     (joystick_0),
        .joystick_1     (joystick_1),
        .status         (status)
    );

    dac #(.C_bits(9)) dac_l(
        .clk_i          (clk_18),
        .res_n_i        (1'b1),
        .dac_i          (audio),
        .dac_o          (AUDIO_L)
    );

    arcade_inputs #(.START1(10), .START2(12), .COIN1(11))
inputs (
        .clk         (clk_36),
        .key_strobe  (key_strobe),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .joystick_0  (joystick_0),
        .joystick_1  (joystick_1),
        .rotate      (rotate),
        .orientation (orientation),
        .joyswap     (joyswap),
        .oneplayer   (1'b0),
        .controls    ({m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player}),
        .player1     ({m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right}),
        .player2     ({m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2})
    );    

endmodule
