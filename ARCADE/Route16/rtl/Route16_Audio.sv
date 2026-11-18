module Route16_Audio (
    input  logic       clk,
    input  logic       ay_en,
    input  logic       reset,
    input  logic [2:0] core_mod,
    input  logic       bdir,
    input  logic       bc1,
    input  logic [7:0] data_in,
    input  logic [7:0] dac_data,
    input  logic       dac_we,
    output logic [9:0] audio
);

    logic [7:0] ay_data_out;
    logic [7:0] ay_ioa_out;
    logic [9:0] ay_audio;
    logic       ay_reset_l;
    assign ay_reset_l = ~reset;

    YM2149 u_ay8910 (
        .I_DA(data_in),
        .O_DA(ay_data_out),
        .O_DA_OE_L(),
        .I_A9_L(1'b0),
        .I_A8(1'b1),
        .I_BDIR(bdir),
        .I_BC2(1'b1),
        .I_BC1(bc1),
        .I_SEL_L(1'b1),
        .I_STEREO(1'b0),
        .O_AUDIO(),
        .O_CHAN(),
        .O_AUDIO_L(ay_audio),
        .O_AUDIO_R(),
        .I_IOA(8'h00),
        .O_IOA(ay_ioa_out),
        .O_IOA_OE_L(),
        .I_IOB(8'h00),
        .O_IOB(),
        .O_IOB_OE_L(),
        .ENA(ay_en),
        .RESET_L(ay_reset_l),
        .CLK(clk)
    );

    logic [7:0] dac_reg;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            dac_reg <= 8'h80;
        else if (dac_we)
            dac_reg <= dac_data ^ 8'h80;
    end

    logic [7:0] sn_audio;
    sn76477 #(
        .CLK_HZ           (10000000),
        .NOISE_CLOCK_RES  (47000.0),
        .NOISE_FILTER_RES (47000.0),
        .NOISE_FILTER_CAP (1000.0e-12),
        .DECAY_RES        (100000.0),
        .ATTACK_DECAY_CAP (10.0e-6),
        .ATTACK_RES       (4700.0),
        .AMPLITUDE_RES    (47000.0),
        .FEEDBACK_RES     (100000.0),
        .VCO_VOLTAGE      (0.0),
        .VCO_CAP          (0.01e-6),
        .VCO_RES          (100000.0),
        .PITCH_VOLTAGE    (2.5),
        .SLF_CAP          (1.0e-6),
        .SLF_RES          (220000.0),
        .ONE_SHOT_CAP     (1.0e-6),
        .ONE_SHOT_RES     (330000.0)
    ) u_sn76477 (

        .clk                (clk),
        .reset              (reset),
        .enable             (1'(ay_ioa_out >> 0)),
        .vco_mode           (1'(ay_ioa_out >> 1)),
        .envelope_1         (1'(ay_ioa_out >> 2)),
        .envelope_2         (1'(ay_ioa_out >> 3)),
        .mixer_a            (1'(ay_ioa_out >> 4)),
        .mixer_b            (1'(ay_ioa_out >> 5)),
        .mixer_c            (1'(ay_ioa_out >> 6)),
        .noise_clock_ext    (1'b0),
        .vco_ext_voltage_mv (16'd0),
        .audio_out          (sn_audio)
    );

    logic [10:0] mixed_stratvox;
    assign mixed_stratvox = {1'b0, ay_audio} + {2'b00, sn_audio, 1'b0} + {2'b00, dac_reg, 1'b0};
    assign audio = (core_mod[2:0] >= 3'd2) ? (1'(mixed_stratvox >> 10) ? 10'h3FF : mixed_stratvox[9:0]) : ay_audio;

endmodule
