//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module ac1_mist (
    input  logic        CLOCK_27,
    output logic [5:0]  VGA_R,
    output logic [5:0]  VGA_G,
    output logic [5:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,     
    output logic        LED,
    output logic        AUDIO_L,
    output logic        AUDIO_R,
    input  logic        SPI_SCK,
    output logic        SPI_DO,
    input  logic        SPI_DI,
    input  logic        SPI_SS2,
    input  logic        SPI_SS3,
    input  logic        SPI_SS4,
    input  logic        CONF_DATA0,
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
    output logic        SDRAM_CKE,
    input  logic        UART_RX,
    output logic        UART_TX
);

    `include "build_id.v"
    assign LED = 1'b1;

    localparam CONF_STR = {
        "AC1;mst;",
        "O23,System_Mode,16L_64C,32L_128C,32L_256C,SCCH;",
        "O4,RAM,2KB,Full (58KB);",
        "T0,Reset;",
        "V,v1.0.", `BUILD_DATE
    };

    logic clk_sys, clk_pixel, clk_sdram;
    logic locked;

    pll pll_inst (
        .areset(),
        .inclk0(CLOCK_27),
        .c0(clk_sdram), 
        .c1(clk_sys),  
        .locked(locked)
    );

    assign SDRAM_CLK = clk_sdram;
    assign SDRAM_CKE = 1'b1;
    logic [63:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic        scandoubler_disable;
    logic        ypbpr;
    logic        ps2_kbd_data;
    logic        ps2_kbd_clk;

    user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io(
        .clk_sys        (clk_sdram       ),
        .conf_str       (CONF_STR       ),
        .SPI_CLK        (SPI_SCK        ),
        .SPI_SS_IO      (CONF_DATA0     ),
        .SPI_MISO       (SPI_DO         ),
        .SPI_MOSI       (SPI_DI         ),
        .buttons        (buttons        ),
        .switches       (switches       ),
        .scandoubler_disable (scandoubler_disable),
        .ypbpr          (ypbpr          ),
        .ps2_kbd_clk    (ps2_kbd_clk),
        .ps2_kbd_data   (ps2_kbd_data),
        .status         (status         )
    );

    logic        ioctl_download;
    logic [26:0] ioctl_addr;
    logic [7:0]  ioctl_dout;
    logic        ioctl_wr;

    data_io #(.DOUT_16(0)) data_io_inst (
        .clk_sys        (clk_sdram),
        .SPI_SCK        (SPI_SCK),
        .SPI_SS2        (SPI_SS3),
        .SPI_SS4        (SPI_SS4),
        .SPI_DI         (SPI_DI),
        .SPI_DO         (SPI_DO),
        .QCSn           (1'b1),
        .QSCK           (1'b0),
        .QDAT           (4'b0000),
        .clkref_n       (1'b1),
        .ioctl_download (ioctl_download),
        .ioctl_upload   (),
        .ioctl_index    (),
        .ioctl_wr       (ioctl_wr),
        .ioctl_addr     (ioctl_addr),
        .ioctl_dout     (ioctl_dout),
        .ioctl_din      (8'h00),
        .ioctl_fileext  (),
        .ioctl_filesize ()
    );

    logic [2:0]  dl_state;
    logic [24:0] dl_addr;
    logic        dl_req_handshake;
    logic [15:0] dl_target_addr;
    logic [7:0]  ioctl_dout_reg;

    always_ff @(posedge clk_sdram or negedge locked) begin
        if (!locked) begin
            dl_state         <= 3'd0;
            dl_target_addr   <= 16'h0000;
            dl_addr          <= 25'd0;
            dl_req_handshake <= 1'b0;
            ioctl_dout_reg   <= 8'h00;
        end else begin
            if (ioctl_download) begin
                case (dl_state)
                    3'd0: begin
                        if (ioctl_wr) begin
                            dl_target_addr[15:8] <= ioctl_dout;
                            dl_state             <= 3'd1;
                        end
                    end
                    
                    3'd1: begin
                        if (ioctl_wr) begin
                            dl_addr  <= {9'b000000000, dl_target_addr[15:8], ioctl_dout};
                            dl_state <= 3'd2;
                        end
                    end
                    
                    3'd2: begin
                        if (ioctl_wr) begin
                            ioctl_dout_reg   <= ioctl_dout;
                            dl_req_handshake <= !dl_req_handshake;
                            dl_state         <= 3'd3;
                        end
                    end
                    
                    3'd3: begin
                        if (port1_ack_out == dl_req_handshake) begin
                            dl_addr  <= dl_addr + 1'b1;
                            dl_state <= 3'd2;
                        end
                    end
                    
                    default: dl_state <= 3'd0;
                endcase
            end else begin
                dl_state         <= 3'd0;
                dl_target_addr   <= 16'h0000;
                dl_req_handshake <= port1_ack_out;
            end
        end
    end

    wire [23:0] sdram_word_addr;
    assign sdram_word_addr = ioctl_download ? {8'b00000000, dl_addr[15:0]} : {8'b00000000, wram_addr};
    
    logic sdram_req_signal;
    assign sdram_req_signal = ioctl_download ? dl_req_handshake : sdram_req_reg;

    sdram #(.MHZ(72)) sdr_ctrl_inst (
        .SDRAM_DQ   ( SDRAM_DQ ),
        .SDRAM_A    ( SDRAM_A ),
        .SDRAM_DQML ( SDRAM_DQML ),
        .SDRAM_DQMH ( SDRAM_DQMH ),
        .SDRAM_BA   ( SDRAM_BA ),
        .SDRAM_nCS  ( SDRAM_nCS ),
        .SDRAM_nWE  ( SDRAM_nWE ),
        .SDRAM_nRAS ( SDRAM_nRAS ),
        .SDRAM_nCAS ( SDRAM_nCAS ),
        .init_n     ( locked ),
        .clk        ( clk_sdram ),
        .port1_req  ( sdram_req_signal ),
        .port1_ack  ( port1_ack_out ),
        .port1_we   ( ioctl_download ? 1'b1 : wram_wren ),
        .port1_a    ( sdram_word_addr ),
        .port1_ds   ( 2'b01 ),
        .port1_d    ( ioctl_download ? {8'h00, ioctl_dout_reg} : {8'h00, wram_din} ),
        .port1_q    ( sdram_q_bus )
    );

    assign wram_dout = sdram_q_bus[7:0];

    logic [15:0] wram_addr;
    logic [7:0]  wram_din;
    logic [7:0]  wram_dout;
    logic        wram_wren;
    logic        sdram_req_reg;
    logic        sdram_ack_sync;
    logic [15:0] sdram_q_bus;
    logic        port1_ack_out;

    always_ff @(posedge clk_sdram or negedge locked) begin
        if (!locked) sdram_ack_sync <= 1'b0;
        else         sdram_ack_sync <= port1_ack_out;
    end

    logic [15:0] wram_addr_last;
    logic        wram_wren_last;

    always_ff @(posedge clk_sdram or negedge locked) begin
        if (!locked) begin
            sdram_req_reg  <= 1'b0;
            wram_addr_last <= '0;
            wram_wren_last <= 1'b0;
        end else begin
            wram_addr_last <= wram_addr;
            wram_wren_last <= wram_wren;
            if ((wram_addr != wram_addr_last) || (wram_wren && !wram_wren_last)) begin
                if (sdram_req_reg == sdram_ack_sync) begin
                    sdram_req_reg <= !sdram_req_reg;
                end
            end
        end
    end

    logic hsync, vsync, hblank, vblank, video_signal;
    logic audio_signal;
    wire rst_n = ~(buttons[1] || status[0] || !locked);

    ac1_top ac1_core (
        .clk_sys       ( clk_sys ),
        .clk_sdram     ( clk_sdram ),
        .rst_n         ( rst_n ),
        .system_mode   ( status[3:2] ),
        .ram_size_mode ( status[4] ),
        .wram_addr     ( wram_addr ),
        .wram_din      ( wram_din ),
        .wram_dout     ( wram_dout ),
        .wram_wren     ( wram_wren ),
        .ps2_kbd_clk   ( ps2_kbd_clk ),
        .ps2_kbd_data  ( ps2_kbd_data ),
        .tape_out      ( UART_TX ),      
        .tape_in       ( UART_RX ),
        .hsync         ( hsync ),
        .vsync         ( vsync ),
        .hblank        ( hblank ),
        .vblank        ( vblank ),
        .video_out     ( video_signal ),
        .audio_out( audio_signal )
    );

    mist_video #(
        .COLOR_DEPTH(1), 
        .SD_HCNT_WIDTH(10)
    ) mist_video_inst (
        .clk_sys       ( clk_sdram ),
        .SPI_SCK       ( SPI_SCK ),
        .SPI_SS3       ( SPI_SS3 ),
        .SPI_DI        ( SPI_DI ),
        .R             ( video_signal ),
        .G             ( video_signal ),
        .B             ( video_signal ),
        .ce_divider    ( 3'd5 ),
        .HSync         ( hsync ),
        .VSync         ( vsync ),
        .HBlank        ( hblank ),
        .VBlank        ( vblank ),
        .scandoubler_disable ( scandoubler_disable ),
        .ypbpr         ( ypbpr ),
        .VGA_R         ( VGA_R ),
        .VGA_G         ( VGA_G ),
        .VGA_B         ( VGA_B ),
        .VGA_VS        ( VGA_VS ),
        .VGA_HS        ( VGA_HS )
    );


    dac #(1) dac (  
        .dac_o(AUDIO_L),
        .dac_i(audio_signal),
        .clk_i(clk_sys),
        .res_n_i(1'b1)
    );

    assign AUDIO_R = AUDIO_L;

endmodule
`default_nettype wire

