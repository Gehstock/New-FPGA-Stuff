module sraider_audio (
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
    logic [7:0]  aout_sn1, aout_sn2, aout_sn3, aout_sn4, aout_sn5;
    logic [7:0]  sn1_scaled, sn2_scaled, sn3_scaled, sn4_scaled, sn5_scaled;
    logic [5:0]  latch_30_q, latch_38_q;
    logic        psg1_ce_n, psg2_ce_n, psg3_ce_n, psg4_ce_n, psg5_ce_n;
    logic        rdy1, rdy2, rdy3, rdy4, rdy5;
    logic        wr_30_en, wr_38_en;

    function automatic logic [7:0] scale_audio(input logic [7:0] sample, input logic [2:0] atten);
        logic [7:0]  weight;
        logic [15:0] mult;
        begin
            case (atten)
                3'd0: weight = 8'd255; // 100 %
                3'd1: weight = 8'd180; // ~70 %
                3'd2: weight = 8'd128; // ~50 %
                3'd3: weight = 8'd90;  // ~35 %
                3'd4: weight = 8'd64;  // ~25 %
                3'd5: weight = 8'd40;  // ~16 %
                3'd6: weight = 8'd20;  // ~8 %
                3'd7: weight = 8'd0;   // Muted (0xFF Init)
            endcase
            mult = sample * weight;
            return mult[15:8];
        end
    endfunction

    assign psg1_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00000)); // 0x00-0x07
    assign psg2_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00001)); // 0x08-0x0F
    assign psg3_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00010)); // 0x10-0x17
    assign psg4_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00011)); // 0x18-0x1F
    assign psg5_ce_n = !(cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00100)); // 0x20-0x27.
    assign wr_30_en  = cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00110);    // 0x30-0x37 (LS174 @ N7)
    assign wr_38_en  = cpu2_iorq_i && cpu2_wr_i && (cpu2_addr_i[7:3] == 5'b00111);    // 0x38-0x3F (LS174 @ N8)

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            latch_30_q <= 6'h3F;
            latch_38_q <= 6'h3F;
        end else begin
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

    assign sn1_scaled = scale_audio(aout_sn1, latch_30_q[2:0]);
    assign sn2_scaled = scale_audio(aout_sn2, latch_30_q[5:3]);
    assign sn3_scaled = scale_audio(aout_sn3, latch_38_q[2:0]);
    assign sn4_scaled = scale_audio(aout_sn4, latch_38_q[5:3]);
    assign sn5_scaled = aout_sn5;

    assign mix     = {4'b0, sn1_scaled} + {4'b0, sn2_scaled} + {4'b0, sn3_scaled} + {4'b0, sn4_scaled} + {4'b0, sn5_scaled};
    assign ready_o = rdy1 & rdy2 & rdy3 & rdy4 & rdy5;

    always_ff @(posedge clk_20mhz_i) begin
        audio_o <= {mix, 2'b00};
    end

endmodule
