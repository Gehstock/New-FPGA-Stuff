module Audio (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic        ce_audio,
    input  logic [7:0]  sound_latch,
    input  logic        sound_irq,
    input  logic        line_irq,
    output logic [16:1] cpu2_addr,
    input  logic [15:0] cpu2_q,
    output logic [9:0]  audio_l,
    output logic [9:0]  audio_r
);

    logic [15:0] snd_addr;
    logic [7:0]  snd_din;
    logic [7:0]  snd_dout;
    logic        m1_n, mreq_n, iorq_n, rd_n, wr_n;
    logic        int_n;

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            int_n <= 1'b1;
        end else begin
            if (sound_irq)
                int_n <= 1'b0;
            else if (!iorq_n && !m1_n)
                int_n <= 1'b1;
        end
    end

    T80s #(
        .Mode(0),
        .T2Write(1),
        .IOWait(1)
    ) audiocpu (
        .RESET_n (~reset),
        .CLK     (clk_sys),
        .CEN     (ce_audio),
        .WAIT_n  (1'b1),
        .INT_n   (int_n),
        .NMI_n   (1'b1),
        .BUSRQ_n (1'b1),
        .M1_n    (m1_n),
        .MREQ_n  (mreq_n),
        .IORQ_n  (iorq_n),
        .RD_n    (rd_n),
        .WR_n    (wr_n),
        .RFSH_n  (),
        .HALT_n  (),
        .BUSAK_n (),
        .A       (snd_addr),
        .DI      (snd_din),
        .DO      (snd_dout)
    );

    assign cpu2_addr = 16'h4000 + {4'd0, snd_addr[12:1]};
    logic [7:0] aud_rom_dout;
    assign aud_rom_dout = snd_addr[0:0] ? cpu2_q[15:8] : cpu2_q[7:0];

    logic cs_aud_ram;
    logic [7:0] aud_ram_dout;
    assign cs_aud_ram = !mreq_n && (snd_addr[15:10] == 6'b010000);

    spram #(10,8) audio_ram (
        .clk    (clk_sys),
        .enable (cs_aud_ram),
        .addr   (snd_addr[9:0]),
        .din    (snd_dout),
        .dout   (aud_ram_dout),
        .we     (cs_aud_ram && !wr_n)
    );

    logic cs_latch;
    assign cs_latch = !mreq_n && (snd_addr[15] == 1'b1);

    logic sound_flag;
    logic line_irq_d;
    always_ff @(posedge clk_sys) begin
        line_irq_d <= line_irq;
        if (reset)
            sound_flag <= 1'b0;
        else if (line_irq && !line_irq_d)
            sound_flag <= ~sound_flag;
    end

    logic [7:0] ym_dout;
    logic       ym_bdir, ym_bc1;
    logic [7:0] ym_audio_8;
    logic [9:0] ym_audio_l, ym_audio_r;

    assign ym_bdir = !iorq_n && !wr_n && (snd_addr[7:0] == 8'h00 || snd_addr[7:0] == 8'h80);
    assign ym_bc1  = !iorq_n && ((!rd_n && snd_addr[7:0] == 8'h00) || (!wr_n && snd_addr[7:0] == 8'h80));

    YM2149 #(
        .MIXER_VOLTABLE (1'b0),
        .IO_OUT_READ_IN (1'b1)
    ) ay_inst (
        .I_DA       (snd_dout),
        .O_DA       (ym_dout),
        .O_DA_OE_L  (),
        .I_A9_L     (1'b0),
        .I_A8       (1'b1),
        .I_BDIR     (ym_bdir),
        .I_BC2      (1'b1),
        .I_BC1      (ym_bc1),
        .I_SEL_L    (1'b1),
        .I_STEREO   (1'b0),
        .O_AUDIO    (ym_audio_8),
        .O_CHAN     (),
        .O_AUDIO_L  (ym_audio_l),
        .O_AUDIO_R  (ym_audio_r),
        .I_IOA      ({sound_flag, 7'h7F}),
        .O_IOA      (),
        .O_IOA_OE_L (),
        .I_IOB      (8'hFF),
        .O_IOB      (),
        .O_IOB_OE_L (),
        .ENA        (ce_audio),
        .RESET_L    (~reset),
        .CLK        (clk_sys)
    );

    assign audio_l = (ym_audio_l != 10'd0) ? ym_audio_l : {ym_audio_8, 2'b00};
    assign audio_r = (ym_audio_r != 10'd0) ? ym_audio_r : {ym_audio_8, 2'b00};

    always_comb begin
        snd_din = 8'hFF;
        if (!mreq_n && (snd_addr[15:13] == 3'b000)) begin
            snd_din = aud_rom_dout;
        end else if (cs_aud_ram) begin
            snd_din = aud_ram_dout;
        end else if (cs_latch) begin
            snd_din = sound_latch;
        end else if (!iorq_n && !rd_n && (snd_addr[7:0] == 8'h00)) begin
            snd_din = ym_dout;
        end
    end

endmodule
