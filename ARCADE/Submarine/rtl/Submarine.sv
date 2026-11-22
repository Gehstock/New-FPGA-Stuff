module Submarine (
    input  logic        CLOCK_27,
    output logic        LED,
    input  logic        SPI_SCK,
    output logic        SPI_DO,
    input  logic        SPI_DI,
    input  logic        SPI_SS2,
    input  logic        SPI_SS3,
    input  logic        CONF_DATA0,
    output logic [5:0]  VGA_R,
    output logic [5:0]  VGA_G,
    output logic [5:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic        AUDIO_L,
    output logic        AUDIO_R,
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

    logic clk_sys, clk_cor, locked;
    assign SDRAM_CLK = ~clk_sys;
    assign SDRAM_CKE = 1'b1;

    pll pll_inst (
        .inclk0(CLOCK_27),
        .locked(locked),
        .c0(clk_sys),
        .c1(clk_cor)
    );

`include "rtl/build_id.v"

    localparam CONF_STR = {
        "Submarine;;",
        "O12,Lives,3,4,5,6;",
        "O3,Cabinet,Upright,Cocktail;",
        "O4,Demo Sounds,On,Off;",
        "O5,Coinage,1C_1C,Free Play;",
        "O78,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };

    logic [31:0] status;
    logic [1:0]  buttons;
    logic [1:0]  switches;
    logic [7:0]  joystick_0, joystick_1;
    logic        scandoublerD, ypbpr;
    logic [9:0]  audio;
    logic        hs, vs, hb, vb;
    logic [3:0]  r, g, b;
    logic        m_one_player, m_two_players, m_three_players, m_four_players;
    logic        m_coin1, m_coin2, m_coin3, m_coin4, m_tilt;
    logic        m_right, m_left, m_down, m_up, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    logic        m_right2, m_left2, m_down2, m_up2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    logic        key_strobe;
    logic        key_pressed;
    logic [7:0]  key_code;
    logic        ioctl_downl;
    logic [7:0]  ioctl_index;
    logic        ioctl_wr;
    logic [24:0] ioctl_addr;
    logic [7:0]  ioctl_dout;
    logic [15:0] mrom_addr;
    logic [15:0] mrom_do;
    logic [12:0] srom_addr;
    logic [15:0] srom_do;
    logic [14:0] tile_rom_addr;
    logic [31:0] tile_rom_do_32;
    logic [13:0] spr_rom_addr;
    logic [31:0] spr_rom_do;
    logic [7:0]  dsw0, dsw1, in0_pins, in1_pins;
    logic        port1_req, port2_req;
    logic        reset = 1'b1;
    logic        rom_loaded = 1'b0;

    assign LED      = ~ioctl_downl;
    assign AUDIO_R  = AUDIO_L;
    assign dsw0     = {status[5] ? 4'h0 : 4'h1, 4'hF};
    assign dsw1     = {1'b1, ~status[4], ~status[3], 3'b111, status[2:1]};
    assign in0_pins = {1'b1, ~m_coin1, m_fireB, m_fireA, m_up, m_down, m_right, m_left};
    assign in1_pins = {m_one_player, m_two_players, m_fire2B, m_fire2A, m_up2, m_down2, m_right2, m_left2};

    Sub_Top sub_top_inst (
        .clk_sys      (clk_cor),
        .reset        (reset),
        .in0_pins     (in0_pins),
        .in1_pins     (in1_pins),
        .dsw0_pins    (dsw0),
        .dsw1_pins    (dsw1),
        .mrom_addr    (mrom_addr),
        .mrom_data    (mrom_addr[0] ? mrom_do[15:8] : mrom_do[7:0]),
        .srom_addr    (srom_addr),
        .srom_data    (srom_addr[0] ? srom_do[15:8] : srom_do[7:0]),
        .tile_rom_addr(tile_rom_addr),
        .tile_rom_data(tile_rom_addr[0] ? tile_rom_do_32[31:16] : tile_rom_do_32[15:0]),
        .spr_rom_addr (spr_rom_addr),
        .spr_rom_data (spr_rom_do[23:0]),
        .video_r      (r),
        .video_g      (g),
        .video_b      (b),
        .video_hsync  (hs),
        .video_vsync  (vs),
        .video_hblank (hb),
        .video_vblank (vb),
        .audio_out    (audio)
    );

    mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(11)) mist_video (
        .clk_sys            (clk_sys),
        .SPI_SCK            (SPI_SCK),
        .SPI_SS3            (SPI_SS3),
        .SPI_DI             (SPI_DI),
        .R                  (r),
        .G                  (g),
        .B                  (b),
        .HSync              (hs),
        .VSync              (vs),
        .HBlank             (hb),
        .VBlank             (vb),
        .VGA_R              (VGA_R),
        .VGA_G              (VGA_G),
        .VGA_B              (VGA_B),
        .VGA_VS             (VGA_VS),
        .VGA_HS             (VGA_HS),
        .rotate             (2'b01),
        .ce_divider         (8),
        .scandoubler_disable(scandoublerD),
        .ypbpr              (ypbpr)
    );

    user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io (
        .clk_sys            (clk_sys),
        .conf_str           (CONF_STR),
        .SPI_CLK            (SPI_SCK),
        .SPI_SS_IO          (CONF_DATA0),
        .SPI_MISO           (SPI_DO),
        .SPI_MOSI           (SPI_DI),
        .buttons            (buttons),
        .switches           (switches),
        .scandoubler_disable(scandoublerD),
        .ypbpr              (ypbpr),
        .key_strobe         (key_strobe),
        .key_pressed        (key_pressed),
        .key_code           (key_code),
        .joystick_0         (joystick_0),
        .joystick_1         (joystick_1),
        .status             (status)
    );

    sdram sdram (
        .*,
        .init_n   (locked),
        .clk      (clk_sys),
        .clkref   (clk_cor),

        .port1_req(port1_req),
        .port1_ack(),
        .port1_we (ioctl_downl && (ioctl_addr < 25'h0D000)),
        .port1_a  (ioctl_addr[23:1]),
        .port1_ds ({ioctl_addr[0], ~ioctl_addr[0]}),
        .port1_d  ({ioctl_dout, ioctl_dout}),
        .port1_q  (),

        .cpu1_addr(reset ? 17'h1ffff : {1'b0, mrom_addr[15:1]}),
        .cpu1_q   (mrom_do),
        .cpu1_qa  (),
        .cpu2_addr(reset ? 17'h1ffff : (17'h05800 + {5'd0, srom_addr[12:1]})),
        .cpu2_q   (srom_do),
        .cpu2_qa  (),

        .port2_req(port2_req),
        .port2_ack(),
        .port2_we (ioctl_downl && (ioctl_addr >= 25'h0D000)),
        .port2_a  (ioctl_addr >= 25'h0D000 ? (ioctl_addr[23:1] - 23'h06800) : 23'd0),
        .port2_ds ({ioctl_addr[0], ~ioctl_addr[0]}),
        .port2_d  ({ioctl_dout, ioctl_dout}),
        .port2_q  (),

        .chr1_addr(reset ? 18'h3ffff : {4'd0, tile_rom_addr[14:1]}),
        .chr1_q   (tile_rom_do_32),
        .chr2_addr(18'h3ffff),
        .chr2_q   (),
        .sp_addr  (reset ? 18'h3ffff : (18'h04000 + {4'd0, spr_rom_addr})),
        .sp_q     (spr_rom_do)
    );

    data_io data_io (
        .clk_sys       (clk_sys),
        .SPI_SCK       (SPI_SCK),
        .SPI_SS2       (SPI_SS2),
        .SPI_DI        (SPI_DI),
        .SPI_DO        (SPI_DO),
        .ioctl_download(ioctl_downl),
        .ioctl_index   (ioctl_index),
        .ioctl_wr      (ioctl_wr),
        .ioctl_addr    (ioctl_addr),
        .ioctl_dout    (ioctl_dout)
    );

    always_ff @(posedge clk_sys) begin
        logic ioctl_wr_last = 1'b0;
        ioctl_wr_last <= ioctl_wr;
        if (ioctl_downl) begin
            if (~ioctl_wr_last && ioctl_wr) begin
                port1_req <= ~port1_req;
                port2_req <= ~port2_req;
            end
        end
    end

    always_ff @(posedge clk_sys) begin
        logic ioctl_downlD;
        ioctl_downlD <= ioctl_downl;
        if (ioctl_downlD & ~ioctl_downl) rom_loaded <= 1'b1;
        reset <= status[0] | buttons[1] | ~rom_loaded;
    end

    arcade_inputs inputs (
        .clk         (clk_sys),
        .key_strobe  (key_strobe),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .joystick_0  (joystick_0),
        .joystick_1  (joystick_1),
        .rotate      (1'b0),
        .orientation (2'b10),
        .joyswap     (1'b0),
        .oneplayer   (1'b0),
        .controls    ({m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player}),
        .player1     ({m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right}),
        .player2     ({m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2})
    );

    dac #(.C_bits(10)) dac (
        .clk_i   (clk_sys),
        .res_n_i (1'b1),
        .dac_i   (audio),
        .dac_o   (AUDIO_L)
    );

endmodule
