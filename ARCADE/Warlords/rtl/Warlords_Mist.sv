module Warlords_Mist (
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
    input  logic        CLOCK_27
);

    `include "rtl\build_id.v" 
        localparam CONF_STR = {
        "Warlords;;",
        "O34,Scanlines,Off,25%,50%,75%;",
        "O5,Blend,Off,On;",
        "O6,Joystick Swap,Off,On;",
        "O7,Test,Off,On;",
        "O9,Cabinet Type,Cocktail,Upright;",
        "OAD,Credits,1p/2p=1cr,1p=1 2p=2,1p/2p=2cr,2p=2cr;",
        "OE,Music,Endgame,Highscore;",
        "OFI,Language,EN,FR,ES,DE;", 
        "O12,Coinage,Free Play,1C_2C,1C_1C,2C_1C;",
        "OJK,Right Coin,*1,*4,*5,*6;",
        "OL,Left Coin,*1,*2;",
        "OMN,Bonus Coins,None,3cr/2c,5cr/4c,6cr/4c,6cr/5c;",
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };


    logic [63:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic [1:0]  scanlines;
    logic        blend;
    logic        joyswap;
    logic        service;
    logic        cocktail;

    assign scanlines = status[4:3];
    assign blend     = status[5];
    assign joyswap   = status[6];
    assign service   = status[7];
    assign cocktail  = status[9];
    
    assign LED       = 1'b1;
    assign AUDIO_R   = AUDIO_L;
    
    logic clk_24, clk_12;

    pll pll (
        .inclk0         ( CLOCK_27 ),
        .areset         ( 1'b0 ),
        .c0             ( clk_24 ),
        .c2             ( clk_12 )
    );

    logic        key_pressed;
    logic [7:0]  key_code;
    logic        key_strobe;
    logic [8:0]  RGB;
    logic [2:0]  r, g, b;
    logic        hs, vs, vb, hb;
    logic [5:0]  audio;
    logic        scandoublerD;
    logic        ypbpr;
    logic        no_csync;

    logic m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    logic m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    logic m_up3, m_down3, m_left3, m_right3, m_fire3A, m_fire3B, m_fire3C, m_fire3D, m_fire3E, m_fire3F;
    logic m_up4, m_down4, m_left4, m_right4, m_fire4A, m_fire4B, m_fire4C, m_fire4D, m_fire4E, m_fire4F;
    logic m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
    logic [31:0] joystick_0, joystick_1, joystick_2, joystick_3;

    warlords_top u_warlords_core (
        .Clk12        ( clk_12 ),
        .Reset        ( status[0] | buttons[1] ),
        .JoyRight     ( {m_right4, m_right3, m_right2, m_right4} ),
        .JoyLeft      ( {m_left4, m_left3, m_left2, m_left} ),  
        .In0          ( ~{ ~cocktail, 1'b0, service, 1'b1, 4'b1111 } ),
        .In1          ( ~( {service, m_coin2, m_coin1, m_tilt, m_fire4A, m_fire3A, m_fire2A, m_fireA} ) ),
        .Sw1          ( { 2'b11, status[11:10], 1'b1, status[14], status[16:15] } ),
        .Sw2          ( { status[24:22], status[21], status[20:19], status[2:1] } ),
        .R            ( r ), 
        .G            ( g ), 
        .B            ( b ),
        .Hsync        ( hs ), 
        .Vsync        ( vs ), 
        .Hblank       ( hb ), 
        .Vblank       ( vb ),
        .Audio        ( audio )
    );

    mist_video #(
        .COLOR_DEPTH(3), 
        .SD_HCNT_WIDTH(12)
    ) mist_video (
        .clk_sys             ( clk_24 ),
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
        .rotate              ( 2'b00 ),
        .ce_divider          ( 1'b1 ),
        .blend               ( blend ),
        .scandoubler_disable ( scandoublerD ),
        .no_csync            ( 1'b1 ),
        .ypbpr               ( ypbpr )
    );  

    user_io #(
        .STRLEN(($size(CONF_STR)>>3))
    ) user_io (
        .clk_sys             ( clk_24 ),
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
        .C_bits(6)
    ) dac (
        .clk_i               ( clk_24 ),
        .res_n_i             ( 1'b1 ),
        .dac_i               ( audio ),
        .dac_o               ( AUDIO_L )
    );

    arcade_inputs inputs (
        .clk                ( clk_24 ),
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
	
endmodule
