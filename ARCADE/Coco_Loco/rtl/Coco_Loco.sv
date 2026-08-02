`default_nettype none

module Coco_Loco(
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
    "CocoLoco;;",
    "O1,Char Speed,Fast,Slow;",
    "O2,Monsters Speed,Fast,Slow;",
    "O34,Monsters Out Time,Long,Medium-Long,Medium-Short,Short;",
    "O78,Coinage,1C 2C,1C 4C,1C 3C,1C 5C;",
    "O9A,Bonus Life,10000 Pts,15000 Pts,20000 Pts,30000 Pts;",
    "OB,Lives,2,3;",
    "OC,Monsters Count,4,5;",
    "ODE,Vitamin Time,Long,Medium-Long,Medium-Short,Short;",
    "T0,Reset;",
    "V,v1.00."
};

    assign        LED = 1'b1;
    assign        AUDIO_R = AUDIO_L;

    wire clk20, clk40, pll_locked;
    pll pll(
        .inclk0(CLOCK_27),
        .c0(clk40),
        .c1(clk20),
        .locked(pll_locked)
    );

    wire sys_reset = status[0] || buttons[1] || ~pll_locked;

    wire [63:0] status;
    wire  [1:0] buttons;
    wire  [1:0] switches;
    wire [11:0] kbjoy;
    wire [31:0] joystick_0;
    wire [31:0] joystick_1;
    wire        scandoublerD;
    wire        ypbpr;
    wire        no_csync;
    wire        key_strobe;
    wire        key_pressed;
    wire  [7:0] key_code;
	 
    wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

    wire        hs, vs, hb, vb;
    wire [3:0]  r, g, b;
    wire [9:0]  audio_top;

    wire [7:0] dsw1_mapped = {4'b1111,status[4:3],status[2],status[1]};
    wire [7:0] dsw2_mapped = {status[14:13],status[12],status[11],status[10:9],status[8:7]};

    wire [7:0] input_port_in0 = {~vb,m_up,m_down,m_right,m_left,m_fireA,m_one_player,m_coin1};

    cocoloco_top cocoloco_core (
        .clk            (clk20),          
        .reset          (sys_reset),
        .input_port_in0 (input_port_in0),   
        .dsw1           (dsw1_mapped),
        .dsw2           (dsw2_mapped),
        .video_hsync    (hs),
        .video_vsync    (vs),
        .video_r        (r),
        .video_g        (g),
        .video_b        (b),
        .video_hblank   (hb),
        .video_vblank   (vb),
        .audio_out      (audio_top)
    );

    mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(10)) mist_video(
        .clk_sys        (clk40),
        .SPI_SCK        (SPI_SCK),
        .SPI_SS3        (SPI_SS3),
        .SPI_DI         (SPI_DI),
        .R              (r),
        .G              (g),
        .B              (b),
        .HSync          (hs),
        .VSync          (vs),
        .HBlank         (hb),
        .VBlank         (vb),
        .VGA_R          (VGA_R),
        .VGA_G          (VGA_G),
        .VGA_B          (VGA_B),
        .VGA_VS         (VGA_VS),
        .VGA_HS         (VGA_HS),
        .scandoubler_disable(scandoublerD),
        .rotate         (2'b11),
        .ypbpr          (ypbpr),
        .no_csync       (no_csync)
    );
    
    user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io(
        .clk_sys        (clk40),
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

    dac #(10) dac_l(
        .clk_i          (clk20),
        .res_n_i        (1'b1),
        .dac_i          (audio_top), 
        .dac_o          (AUDIO_L)
    );

    arcade_inputs inputs (
        .clk         (clk40),
        .key_strobe  (key_strobe),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .joystick_0  (joystick_0),
        .joystick_1  (joystick_1),
        .orientation (2'b10),
        .oneplayer   (1'b1),
        .controls    ({m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player}),
        .player1     ({m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right})
    );    

endmodule
