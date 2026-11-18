module sn76477 #(
    parameter int unsigned CLK_HZ          = 10000000,
    parameter real         NOISE_CLOCK_RES = 47000.0,
    parameter real         NOISE_FILTER_RES= 150000.0,
    parameter real         NOISE_FILTER_CAP= 4700.0e-12,
    parameter real         DECAY_RES       = 47000.0,
    parameter real         ATTACK_DECAY_CAP= 10.0e-6,
    parameter real         ATTACK_RES      = 4700.0,
    parameter real         AMPLITUDE_RES   = 47000.0,
    parameter real         FEEDBACK_RES    = 100000.0,
    parameter real         VCO_VOLTAGE     = 0.0,
    parameter real         VCO_CAP         = 0.01e-6,
    parameter real         VCO_RES         = 100000.0,
    parameter real         PITCH_VOLTAGE   = 2.5,
    parameter real         SLF_CAP         = 1.0e-6,
    parameter real         SLF_RES         = 220000.0,
    parameter real         ONE_SHOT_CAP    = 1.0e-6,
    parameter real         ONE_SHOT_RES    = 100000.0
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        mixer_a,
    input  logic        mixer_b,
    input  logic        mixer_c,
    input  logic        envelope_1,
    input  logic        envelope_2,
    input  logic        vco_mode,
    input  logic        noise_clock_ext,
    input  logic [15:0] vco_ext_voltage_mv,
    output logic [7:0]  audio_out
);

    localparam int unsigned SAMPLE_RATE = 48000;
    localparam int unsigned SAMPLE_DIV  = CLK_HZ / SAMPLE_RATE;

    localparam int unsigned V_MAX       = 32'h10000000;
    localparam int unsigned V_5V        = V_MAX;
    localparam int unsigned V_SLF_HI    = int'((2.46 / 5.0) * V_MAX);
    localparam int unsigned V_SLF_LO    = int'((0.36 / 5.0) * V_MAX);
    localparam int unsigned V_OS_HI     = int'((2.60 / 5.0) * V_MAX);
    localparam int unsigned V_VCO_LO    = int'((0.36 / 5.0) * V_MAX);
    localparam int unsigned V_ENV_HI    = int'((3.60 / 5.0) * V_MAX);
    localparam int unsigned V_FLT_THRESH= int'((2.50 / 5.0) * V_MAX);

    localparam real R_OS  = (ONE_SHOT_RES > 0.0)     ? ONE_SHOT_RES     : 100000.0;
    localparam real C_OS  = (ONE_SHOT_CAP > 0.0)     ? ONE_SHOT_CAP     : 1.0e-6;
    localparam real R_SLF = (SLF_RES > 0.0)          ? SLF_RES          : 100000.0;
    localparam real C_SLF = (SLF_CAP > 0.0)          ? SLF_CAP          : 1.0e-6;
    localparam real R_VCO = (VCO_RES > 0.0)          ? VCO_RES          : 100000.0;
    localparam real C_VCO = (VCO_CAP > 0.0)          ? VCO_CAP          : 0.01e-6;
    localparam real R_ATK = (ATTACK_RES > 0.0)       ? ATTACK_RES       : 4700.0;
    localparam real R_DEC = (DECAY_RES > 0.0)        ? DECAY_RES        : 47000.0;
    localparam real C_ENV = (ATTACK_DECAY_CAP > 0.0) ? ATTACK_DECAY_CAP : 1.0e-6;
    localparam real R_NFLT= (NOISE_FILTER_RES > 0.0) ? NOISE_FILTER_RES : 10000.0;
    localparam real C_NFLT= (NOISE_FILTER_CAP > 0.0) ? NOISE_FILTER_CAP : 1000.0e-12;
    localparam real R_NCLK= (NOISE_CLOCK_RES > 0.0)  ? NOISE_CLOCK_RES  : 47000.0;

    localparam int unsigned STEP_OS_CHG  = int'(((0.8 * 5.0 / (R_OS * C_OS)) / SAMPLE_RATE) * (V_MAX / 5.0));
    localparam int unsigned STEP_SLF_CHG = int'(((2.1 * 2.0 / (R_SLF * C_SLF)) / SAMPLE_RATE) * (V_MAX / 5.0));
    localparam int unsigned STEP_VCO_CHG = int'(((2.1 * 2.0 / (R_VCO * C_VCO)) / SAMPLE_RATE) * (V_MAX / 5.0));
    localparam int unsigned STEP_ENV_ATK = int'(((3.6 / (R_ATK * C_ENV)) / SAMPLE_RATE) * (V_MAX / 5.0));
    localparam int unsigned STEP_ENV_DEC = int'(((3.6 / (R_DEC * C_ENV)) / SAMPLE_RATE) * (V_MAX / 5.0));
    localparam int unsigned STEP_NFLT    = int'(((5.0 / (R_NFLT * C_NFLT)) / SAMPLE_RATE) * (V_MAX / 5.0));

    localparam real NOISE_FREQ_HZ = 339100000.0 / R_NCLK;
    localparam int unsigned NOISE_PHASE_INC = int'((NOISE_FREQ_HZ / SAMPLE_RATE) * 4294967296.0);
    localparam int unsigned VCO_DUTY_THRESH = int'(((PITCH_VOLTAGE < 0.36 ? 0.36 : (PITCH_VOLTAGE > 2.5 ? 2.5 : PITCH_VOLTAGE)) / 5.0) * V_MAX);

    logic [15:0] sample_cnt;
    logic        sample_tick;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sample_cnt  <= 16'd0;
            sample_tick <= 1'b0;
        end else if (sample_cnt >= 16'(SAMPLE_DIV - 1)) begin
            sample_cnt  <= 16'd0;
            sample_tick <= 1'b1;
        end else begin
            sample_cnt  <= sample_cnt + 16'd1;
            sample_tick <= 1'b0;
        end
    end

    logic        enable_d1;
    logic [31:0] os_cap_v;
    logic        os_running;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            enable_d1  <= 1'b1;
            os_cap_v   <= 32'd0;
            os_running <= 1'b0;
        end else begin
            enable_d1 <= enable;
            if (enable) begin
                os_cap_v   <= 32'd0;
                os_running <= 1'b0;
            end else if (enable_d1 && !enable) begin
                os_cap_v   <= 32'd0;
                os_running <= 1'b1;
            end else if (sample_tick && os_running) begin
                if (os_cap_v + STEP_OS_CHG >= V_OS_HI) begin
                    os_cap_v   <= V_OS_HI;
                    os_running <= 1'b0;
                end else begin
                    os_cap_v <= os_cap_v + STEP_OS_CHG;
                end
            end
        end
    end

    logic [31:0] slf_cap_v;
    logic        slf_out;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            slf_cap_v <= V_SLF_LO;
            slf_out   <= 1'b1;
        end else if (sample_tick) begin
            if (slf_out) begin
                if (slf_cap_v + STEP_SLF_CHG >= V_SLF_HI) begin
                    slf_cap_v <= V_SLF_HI;
                    slf_out   <= 1'b0;
                end else begin
                    slf_cap_v <= slf_cap_v + STEP_SLF_CHG;
                end
            end else begin
                if (slf_cap_v <= V_SLF_LO + STEP_SLF_CHG) begin
                    slf_cap_v <= V_SLF_LO;
                    slf_out   <= 1'b1;
                end else begin
                    slf_cap_v <= slf_cap_v - STEP_SLF_CHG;
                end
            end
        end
    end

    logic [31:0] vco_ctrl_v;
    logic [31:0] vco_ext_scaled;
    assign vco_ext_scaled = (vco_ext_voltage_mv == 16'd0) ? int'((VCO_VOLTAGE / 5.0) * V_MAX) : (int'(vco_ext_voltage_mv) * (V_MAX / 5000));
    assign vco_ctrl_v     = vco_mode ? slf_cap_v : vco_ext_scaled;

    logic [31:0] vco_hi_limit;
    assign vco_hi_limit = (vco_ctrl_v < V_VCO_LO + 32'h00200000) ? (V_VCO_LO + 32'h00200000) : vco_ctrl_v;

    logic [31:0] vco_cap_v;
    logic        vco_charge_dir;
    logic        vco_out;
    logic        vco_alt_ff;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            vco_cap_v      <= V_VCO_LO;
            vco_charge_dir <= 1'b1;
            vco_out        <= 1'b0;
            vco_alt_ff     <= 1'b0;
        end else if (sample_tick) begin
            if (vco_charge_dir) begin
                if (vco_cap_v + STEP_VCO_CHG >= vco_hi_limit) begin
                    vco_cap_v      <= vco_hi_limit;
                    vco_charge_dir <= 1'b0;
                end else begin
                    vco_cap_v <= vco_cap_v + STEP_VCO_CHG;
                end
            end else begin
                if (vco_cap_v <= V_VCO_LO + STEP_VCO_CHG) begin
                    vco_cap_v      <= V_VCO_LO;
                    vco_charge_dir <= 1'b1;
                    vco_alt_ff     <= ~vco_alt_ff;
                end else begin
                    vco_cap_v <= vco_cap_v - STEP_VCO_CHG;
                end
            end
            vco_out <= (vco_cap_v < VCO_DUTY_THRESH) ? 1'b1 : 1'b0;
        end
    end

    logic [31:0] noise_phase;
    logic [31:0] rng;
    logic        real_noise_bit;
    logic        noise_clk_d1;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            noise_phase    <= 32'd0;
            rng            <= 32'h1FFFF;
            real_noise_bit <= 1'b0;
            noise_clk_d1   <= 1'b0;
        end else begin
            noise_clk_d1 <= noise_clock_ext;
            if (NOISE_CLOCK_RES == 0.0) begin
                if (!noise_clk_d1 && noise_clock_ext) begin
                    real_noise_bit <= 1'((rng >> 28) ^ (rng >> 30));
                    rng <= {rng[30:0], 1'((rng >> 28) ^ (rng >> 30))};
                end
            end else if (sample_tick) begin
                if (noise_phase + NOISE_PHASE_INC < noise_phase) begin
                    real_noise_bit <= 1'((rng >> 28) ^ (rng >> 30));
                    rng <= {rng[30:0], 1'((rng >> 28) ^ (rng >> 30))};
                end
                noise_phase <= noise_phase + NOISE_PHASE_INC;
            end
        end
    end

    logic [31:0] nflt_cap_v;
    logic        filtered_noise_bit;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            nflt_cap_v         <= 32'd0;
            filtered_noise_bit <= 1'b0;
        end else if (sample_tick) begin
            if (real_noise_bit) begin
                if (nflt_cap_v + STEP_NFLT >= V_5V)
                    nflt_cap_v <= V_5V;
                else
                    nflt_cap_v <= nflt_cap_v + STEP_NFLT;
            end else begin
                if (nflt_cap_v <= STEP_NFLT)
                    nflt_cap_v <= 32'd0;
                else
                    nflt_cap_v <= nflt_cap_v - STEP_NFLT;
            end
            filtered_noise_bit <= (nflt_cap_v >= V_FLT_THRESH) ? 1'b1 : 1'b0;
        end
    end

    logic [2:0] mixer_mode;
    logic       mixer_out;
    assign mixer_mode = {mixer_c, mixer_b, mixer_a};

    always_comb begin
        case (mixer_mode)
            3'b000: mixer_out = vco_out;
            3'b001: mixer_out = slf_out;
            3'b010: mixer_out = filtered_noise_bit;
            3'b011: mixer_out = vco_out & filtered_noise_bit;
            3'b100: mixer_out = slf_out & filtered_noise_bit;
            3'b101: mixer_out = vco_out & slf_out;
            3'b110: mixer_out = vco_out & slf_out & filtered_noise_bit;
            3'b111: mixer_out = 1'b0;
        endcase
    end

    logic [1:0]  env_mode;
    logic        env_attack;
    logic [31:0] env_cap_v;
    assign env_mode = {envelope_2, envelope_1};

    always_comb begin
        case (env_mode)
            2'b00: env_attack = 1'b1;
            2'b01: env_attack = os_running;
            2'b10: env_attack = os_running;
            2'b11: env_attack = vco_alt_ff;
        endcase
    end

    wire [31:0] dec_step = (env_cap_v < (V_ENV_HI >> 2)) ? (STEP_ENV_DEC >> 2) : STEP_ENV_DEC;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            env_cap_v <= 32'd0;
        end else if (enable) begin
            env_cap_v <= 32'd0;
        end else if (sample_tick) begin
            if (env_mode == 2'b00) begin
                env_cap_v <= V_ENV_HI;
            end else if (env_attack) begin
                if (env_cap_v + STEP_ENV_ATK >= V_ENV_HI)
                    env_cap_v <= V_ENV_HI;
                else
                    env_cap_v <= env_cap_v + STEP_ENV_ATK;
            end else begin
                if (env_cap_v <= dec_step)
                    env_cap_v <= 32'd0;
                else
                    env_cap_v <= env_cap_v - dec_step;
            end
        end
    end



    logic [7:0] env_amp;
    assign env_amp = 8'(env_cap_v >> 20);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            audio_out <= 8'd0;
        end else if (enable || !mixer_out) begin
            audio_out <= 8'd0;
        end else begin
            audio_out <= env_amp;
        end
    end

endmodule
