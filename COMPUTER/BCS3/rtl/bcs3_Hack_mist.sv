//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module bcs3_Hack_mist (
    input  logic        CLOCK_27,
    output logic [5:0]  VGA_R,
    output logic [5:0]  VGA_G,
    output logic [5:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,     
    output logic        LED,
    input  logic        SPI_SCK,
    output logic        SPI_DO,
    input  logic        SPI_DI,
    input  logic        CONF_DATA0,
    input  logic        SPI_SS2,
    input  logic        SPI_SS3,
    input  logic        SPI_SS4,
    input  logic        UART_RX,
    output logic        UART_TX
);

    `include "build_id.v"
    assign LED = 1'b1;

    localparam CONF_STR = {
        "BCS3;;",
        "T0,Reset;",
        "V,v1.0.", `BUILD_DATE
    };

    logic clk_sys, clk_5mhz;
    logic locked;

    pll pll_inst (
        .areset(),
        .inclk0(CLOCK_27),
        .c0(clk_sys), //28mhz
        .c1(clk_5mhz), //5mhz 
        .locked(locked)
    );

    logic [63:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic        scandoubler_disable;
    logic        ypbpr;
    logic        ps2_kbd_data;
    logic        ps2_kbd_clk;

    user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io(
        .clk_sys        (clk_sys),
        .conf_str       (CONF_STR),
        .SPI_CLK        (SPI_SCK),
        .SPI_SS_IO      (CONF_DATA0),
        .SPI_MISO       (SPI_DO),
        .SPI_MOSI       (SPI_DI),
        .buttons        (buttons),
        .switches       (switches),
        .scandoubler_disable (scandoubler_disable),
        .ypbpr          (ypbpr),
        .ps2_kbd_clk    (ps2_kbd_clk),
        .ps2_kbd_data   (ps2_kbd_data),
        .status         (status)
    );

    logic hsync, vsync, hblank, vblank, video_signal;
    wire  rst_n = ~(buttons[1] || status[0] || !locked);

    bcs3_Hack_top bcs3_core (
        .clk_in_5mhz        (clk_5mhz),
        .reset_n            (rst_n),
        .ps2_kbd_clk    	 (ps2_kbd_clk),
        .ps2_kbd_data   	 (ps2_kbd_data),
        .cassette_in        (UART_RX),
        .cassette_out       (UART_TX),
        .pio_port_a_in      (8'hFF),
        .pio_port_a_out     (),
        .pio_port_b_in      (8'hFF),
        .pio_port_b_out     (),
        .ctc_clk_trg        (4'h0),
        .hsync              (hsync),
        .vsync              (vsync),
        .hblank             (hblank),
        .vblank             (vblank),
        .video_out          (video_signal)
    );

    mist_video #(
        .COLOR_DEPTH(1), 
        .SD_HCNT_WIDTH(10)
    ) mist_video_inst (
        .clk_sys             (clk_sys),
        .SPI_SCK             (SPI_SCK),
        .SPI_SS3             (SPI_SS3),
        .SPI_DI              (SPI_DI),
        .R                   (video_signal),
        .G                   (video_signal),
        .B                   (video_signal),
        .HSync               (hsync),
        .VSync               (vsync),
        .HBlank              (hblank), 
        .VBlank              (vblank),
        .scandoubler_disable (scandoubler_disable),
        .ypbpr               (ypbpr),
        .VGA_R               (VGA_R),
        .VGA_G               (VGA_G),
        .VGA_B               (VGA_B),
        .VGA_VS              (VGA_VS),
        .VGA_HS              (VGA_HS)
    );


endmodule

`default_nettype wire
