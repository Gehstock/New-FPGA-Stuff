module mrsdyna_audio (
    input  logic        clk_20mhz_i,
    input  logic        clk_en_4mhz_i,
    input  logic        por_n_i,
    input  logic        cpu2_iorq_i,
    input  logic        cpu2_wr_i,
    input  logic [7:0]  cpu2_addr_i,
    input  logic [7:0]  d_from_cpu_i,
    output logic [13:0] audio_o,
    output logic        ready_o
);

    logic [11:0] mix;
    logic [7:0]  aout_sn1, aout_sn2, aout_sn3, aout_sn4, aout_sn5, latch_28_q;
    logic [7:0]  sn1_scaled, sn2_scaled, sn3_scaled, sn4_scaled, sn5_scaled;
    logic [5:0]  latch_30_q, latch_38_q;
    logic        psg1_ce_n, psg2_ce_n, psg3_ce_n, psg4_ce_n, psg5_ce_n, rdy1, rdy2, rdy3, rdy4, rdy5;
    logic        wr_28_en, wr_30_en, wr_38_en;

    function automatic logic [7:0] scale_audio(input logic [7:0] sample, input logic [2:0] atten, input logic gate_en);
        logic [10:0] mult;
        if (!gate_en) begin
            return 8'd0;
        end else begin
            mult = sample * (4'd8 - {1'b0, atten});
            return mult[10:3];
        end
    endfunction

    assign psg1_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00000));
    assign psg2_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00001));
    assign psg3_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00010));
    assign psg4_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00011));
    assign psg5_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00100));
    assign wr_28_en  = cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00101);
    assign wr_30_en  = cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00110);
    assign wr_38_en  = cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00111);

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            latch_28_q <= 8'hFF;
            latch_30_q <= 6'd0;
            latch_38_q <= 6'd0;
        end else begin
            if (wr_28_en) begin
                latch_28_q[cpu2_addr_i[2:0] +: 1] <= d_from_cpu_i[0:0];
            end
            if (wr_30_en) begin
                latch_30_q <= d_from_cpu_i[5:0];
            end
            if (wr_38_en) begin
                latch_38_q <= d_from_cpu_i[5:0];
            end
        end
    end

    sn76489_top snd_sn1 (
        .clock_i(clk_20mhz_i),
        .clock_en_i(clk_en_4mhz_i),
        .res_n_i(por_n_i),
        .ce_n_i(psg1_ce_n),
        .we_n_i(~cpu2_wr_i),
        .ready_o(rdy1),
        .d_i(d_from_cpu_i),
        .aout_o(aout_sn1)
    );

    sn76489_top snd_sn2 (
        .clock_i(clk_20mhz_i),
        .clock_en_i(clk_en_4mhz_i),
        .res_n_i(por_n_i),
        .ce_n_i(psg2_ce_n),
        .we_n_i(~cpu2_wr_i),
        .ready_o(rdy2),
        .d_i(d_from_cpu_i),
        .aout_o(aout_sn2)
    );

    sn76489_top snd_sn3 (
        .clock_i(clk_20mhz_i),
        .clock_en_i(clk_en_4mhz_i),
        .res_n_i(por_n_i),
        .ce_n_i(psg3_ce_n),
        .we_n_i(~cpu2_wr_i),
        .ready_o(rdy3),
        .d_i(d_from_cpu_i),
        .aout_o(aout_sn3)
    );

    sn76489_top snd_sn4 (
        .clock_i(clk_20mhz_i),
        .clock_en_i(clk_en_4mhz_i),
        .res_n_i(por_n_i),
        .ce_n_i(psg4_ce_n),
        .we_n_i(~cpu2_wr_i),
        .ready_o(rdy4),
        .d_i(d_from_cpu_i),
        .aout_o(aout_sn4)
    );

    sn76489_top snd_sn5 (
        .clock_i(clk_20mhz_i),
        .clock_en_i(clk_en_4mhz_i),
        .res_n_i(por_n_i),
        .ce_n_i(psg5_ce_n),
        .we_n_i(~cpu2_wr_i),
        .ready_o(rdy5),
        .d_i(d_from_cpu_i),
        .aout_o(aout_sn5)
    );

//    assign sn1_scaled = scale_audio(aout_sn1, latch_30_q[2:0], latch_28_q[0]);
//    assign sn2_scaled = scale_audio(aout_sn2, latch_30_q[5:3], latch_28_q[1]);
//    assign sn3_scaled = scale_audio(aout_sn3, latch_38_q[2:0], latch_28_q[2]);
//    assign sn4_scaled = scale_audio(aout_sn4, latch_38_q[5:3], latch_28_q[3]);
//    assign sn5_scaled = scale_audio(aout_sn5, latch_38_q[5:3], latch_28_q[4]);

    assign sn1_scaled = scale_audio(aout_sn1, latch_30_q[2:0], 1'b1);
    assign sn2_scaled = scale_audio(aout_sn2, latch_30_q[5:3], 1'b1);
    assign sn3_scaled = scale_audio(aout_sn3, latch_38_q[2:0], 1'b1);
    assign sn4_scaled = scale_audio(aout_sn4, latch_38_q[5:3], 1'b1);
    assign sn5_scaled = scale_audio(aout_sn5, 3'd0,            1'b1);
    assign mix     = {4'b0, sn1_scaled} + {4'b0, sn2_scaled} + {4'b0, sn3_scaled} + {4'b0, sn4_scaled} + {4'b0, sn5_scaled};
    assign ready_o = rdy1 & rdy2 & rdy3 & rdy4 & rdy5;

    always_ff @(posedge clk_20mhz_i) begin
        audio_o <= {mix, 2'b00};
    end

endmodule
