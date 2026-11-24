module Wink (
    input  wire        CLOCK_27,
    output logic       LED,
    input  logic       SPI_SCK,
    output logic       SPI_DO,
    input  logic       SPI_DI,
    input  logic       SPI_SS2,
    input  logic       SPI_SS3,
    input  logic       CONF_DATA0,
    output wire [5:0]  VGA_R,
    output wire [5:0]  VGA_G,
    output wire [5:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        AUDIO_L,
    output wire        AUDIO_R,
    output [12:0]      SDRAM_A,
    inout  [15:0]      SDRAM_DQ,
    output             SDRAM_DQML,
    output             SDRAM_DQMH,
    output             SDRAM_nWE,
    output             SDRAM_nCAS,
    output             SDRAM_nRAS,
    output             SDRAM_nCS,
    output  [1:0]      SDRAM_BA,
    output             SDRAM_CLK,
    output             SDRAM_CKE
);

    wire clk_sys, clk_cor, locked;
    assign SDRAM_CLK = ~clk_sys;
    assign SDRAM_CKE = 1'b1;

    pll pll_inst (
        .inclk0(CLOCK_27),
        .locked(locked),
        .c0(clk_sys),
        .c1(clk_cor)
    );

`include "rtl/build_id.sv"

    localparam CONF_STR = {
        "Wink;;",
        "O12,Lives,3,5,7,2;",
        "O34,Timer Speed,Normal,Fast,Very Fast,Slow;",
        "O5,Ball Save Barrier,No,Yes;",
        "O6,Demo Sounds,On,Off;",
        "O78,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
        "T0,Reset;",
        "V,v1.00.", `BUILD_DATE
    };

    wire [1:0] dsw_lives = (status[2:1] == 2'd0) ? 2'b10 :
                           (status[2:1] == 2'd1) ? 2'b01 :
                           (status[2:1] == 2'd2) ? 2'b00 :
                                                   2'b11;

    wire [1:0] dsw_timer = (status[4:3] == 2'd0) ? 2'b10 :
                           (status[4:3] == 2'd1) ? 2'b11 :
                           (status[4:3] == 2'd2) ? 2'b01 :
                                                   2'b00;

    wire [7:0] dsw1 = {dsw_lives[1:1], dsw_timer, ~status[5], dsw_lives[0], 2'b11, ~status[5]};
    wire [7:0] dsw2 = 8'hFE;
    wire [7:0] dsw3 = {4'hF, status[6], 3'b111};

    wire [31:0] status;
    wire  [1:0] buttons;
    wire  [1:0] switches;
    wire  [7:0] joystick_0, joystick_1;
    wire        scandoublerD, ypbpr;
    wire  [9:0] audio_l, audio_r;
    wire        hs, vs, hb, vb;
    wire  [3:0] r, g, b;
    wire        m_one_player, m_two_players, m_three_players, m_four_players;
    wire        m_coin1, m_coin2, m_coin3, m_coin4, m_tilt;
    wire        m_right, m_left, m_down, m_up, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
    wire        m_right2, m_left2, m_down2, m_up2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
    wire        key_strobe;
    wire        key_pressed;
    wire  [7:0] key_code;

    assign LED     = ~ioctl_downl;
    assign AUDIO_R = AUDIO_L;
    wire [7:0] dial_pos;
    Dial #(
        .DIV_BITS (17)
    ) dial_inst (
        .clk12      (clk_cor),
        .rst_n      (~reset),
        .m_left     (m_left | m_left2),
        .m_right    (m_right | m_right2),
        .joystick_0 (joystick_0 | joystick_1),
        .paddle_reg (dial_pos)
    );



    wire [7:0] inputs1 = ~{m_tilt, m_coin1, m_coin2, m_coin3, m_one_player, m_two_players, m_fireA, m_fireB};

    wire        ioctl_downl;
    wire  [7:0] ioctl_index;
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire  [7:0] ioctl_dout;
    wire [16:1] cpu1_addr, cpu2_addr, cpu3_addr;
    wire [15:0] cpu1_q, cpu2_q, cpu3_q;

    Top Wink_Top (
        .clk_sys   (clk_cor),
        .reset     (reset),
        .cpu1_addr (cpu1_addr),
        .cpu1_q    (cpu1_q),
        .cpu2_addr (cpu2_addr),
        .cpu2_q    (cpu2_q),
        .cpu3_addr (cpu3_addr),
        .cpu3_q    (cpu3_q),
        .dial1     (dial_pos),
        .inputs1   (inputs1),
        .dsw1      (dsw1),
        .dsw2      (dsw2),
        .dsw3      (dsw3),
        .red       (r),
        .green     (g),
        .blue      (b),
        .hsync     (hs),
        .vsync     (vs),
        .hblank    (hb),
        .vblank    (vb),
        .audio_l   (audio_l),
        .audio_r   (audio_r)
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
        .ce_divider         (6),
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

    sdram #(48) sdram (
        .*,
        .init_n    (locked),
        .clk       (clk_sys),
        .port1_req (port1_req),
        .port1_ack (),
        .port1_a   (ioctl_addr[23:1]),
        .port1_ds  ({ioctl_addr[0], ~ioctl_addr[0]}),
        .port1_we  (ioctl_downl),
        .port1_d   ({ioctl_dout, ioctl_dout}),
        .port1_q   (),
        .cpu1_addr (ioctl_downl ? 16'hffff : cpu1_addr),
        .cpu1_q    (cpu1_q),
        .cpu2_addr (ioctl_downl ? 16'hffff : cpu2_addr),
        .cpu2_q    (cpu2_q),
        .cpu3_addr (ioctl_downl ? 16'hffff : cpu3_addr),
        .cpu3_q    (cpu3_q),
        .port2_req (port2_req),
        .port2_ack (),
        .port2_a   (23'h7fffff),
        .port2_ds  (2'b00),
        .port2_we  (1'b0),
        .port2_d   (16'h0000),
        .port2_q   (),
        .sp_addr   (15'h7fff),
        .sp_q      ()
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

    reg port1_req, port2_req;
    always @(posedge clk_sys) begin
        reg ioctl_wr_last = 0;
        ioctl_wr_last <= ioctl_wr;
        if (ioctl_downl) begin
            if (~ioctl_wr_last && ioctl_wr) begin
                port1_req <= ~port1_req;
                port2_req <= ~port2_req;
            end
        end
    end

    reg reset = 1;
    reg rom_loaded = 0;
    always @(posedge clk_sys) begin
        reg ioctl_downlD;
        ioctl_downlD <= ioctl_downl;
        if (ioctl_downlD & ~ioctl_downl) rom_loaded <= 1;
        reset <= status[0] | buttons[1] | ~rom_loaded;
    end

    arcade_inputs inputs (
        .clk         (clk_sys),
        .key_strobe  (key_strobe),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .joystick_0  (joystick_0),
        .joystick_1  (joystick_1),
        .joyswap     (1'b1),
        .oneplayer   (1'b1),
        .controls    ({m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player}),
        .player1     ({m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right}),
        .player2     ({m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2})
    );

    dac #(.C_bits(10)) dac (
        .clk_i   (clk_sys),
        .res_n_i (1'b1),
        .dac_i   (audio_l),
        .dac_o   (AUDIO_L)
    );

endmodule
