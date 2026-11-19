module huebler_grafik_mist (
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
    output logic        UART_TX,
    output logic [12:0] SDRAM_A,
    inout  wire  [15:0] SDRAM_DQ,
    output logic        SDRAM_DQML,
    output logic        SDRAM_DQMH,
    output logic        SDRAM_nWE,
    output logic        SDRAM_nCAS,
    output logic        SDRAM_nRAS,
    output logic        SDRAM_nCS,
    output logic [1:0]  SDRAM_BA,
    output logic        SDRAM_CLK,
    output logic        SDRAM_CKE
);

    `include "build_id.v"
    assign LED = 1'b1;
    assign SDRAM_CLK = ~clk_sys;
    localparam CONF_STR = {
        "HuGFX_MC;;",
        "T0,Reset;",
        "V,v1.0.", `BUILD_DATE
    };

    logic clk_sys, clk_10mhz, clk_9mhz;
    logic locked;

    pll pll_inst (
        .areset(),
        .inclk0(CLOCK_27),
        .c0(clk_sys), //60mhz
        .c1(clk_10mhz), //10mhz 
		  .c2(clk_9mhz), //9mhz 
        .locked(locked)
    );


    logic [63:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic        scandoubler_disable;
    logic        ypbpr;
    logic        ps2_kbd_data;
    logic        ps2_kbd_clk;
	 logic		  audio;

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
	 
	 logic [15:0] ram_addr;
    logic [7:0]  ram_din;
    logic [15:0] sdram_dout;
    logic        ram_we;
    logic        ram_rd;
    logic        sdram_ready;
    logic        sdram_init_done;

    always_ff @(posedge clk_sys or negedge locked) begin
        if (!locked) begin
            sdram_init_done <= 1'b0;
        end else if (sdram_ready) begin
            sdram_init_done <= 1'b1;
        end
    end

    sdram sdram_inst (
        .init       (!locked),
        .clk        (clk_sys),
        .SDRAM_DQ   (SDRAM_DQ),
        .SDRAM_A    (SDRAM_A),
        .SDRAM_DQML (SDRAM_DQML),
        .SDRAM_DQMH (SDRAM_DQMH),
        .SDRAM_BA   (SDRAM_BA),
        .SDRAM_nCS  (SDRAM_nCS),
        .SDRAM_nWE  (SDRAM_nWE),
        .SDRAM_nRAS (SDRAM_nRAS),
        .SDRAM_nCAS (SDRAM_nCAS),
        .SDRAM_CKE  (SDRAM_CKE),
        .wtbt       (2'b00),
        .addr       ({9'd0, ram_addr}),
        .dout       (sdram_dout),
        .din        ({8'h00, ram_din}),
        .we         (ram_we),
        .rd         (ram_rd),
        .ready      (sdram_ready)
    );

    logic hsync, vsync, hblank, vblank, video_signal;
    wire  rst_n = ~(buttons[1] || status[0] || !locked || !sdram_init_done);

    huebler_grafik_top huebler_grafik_top_inst (
        .clk_10mhz    (clk_10mhz),
        .clk_9mhz     (clk_9mhz),
        .rst_n        (rst_n),
        .ps2_kbd_clk  (ps2_kbd_clk),
        .ps2_kbd_data (ps2_kbd_data),
        .video_hsync  (hsync),   
        .video_vsync  (vsync),   
        .video_hblank (hblank),  
        .video_vblank (vblank), 
        .video_out    (video_signal),     
        .cassette_in  (UART_RX),   
        .cassette_out (UART_TX),  
        .audio_out    (audio),
        .ram_addr     (ram_addr),
        .ram_din      (ram_din),
        .ram_dout     (sdram_dout[7:0]),
        .ram_we       (ram_we),
        .ram_rd       (ram_rd)
    );

    mist_video #(
        .COLOR_DEPTH(1), 
        .SD_HCNT_WIDTH(11)
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
