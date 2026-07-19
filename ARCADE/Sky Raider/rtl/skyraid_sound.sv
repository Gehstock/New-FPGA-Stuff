`timescale 1ns / 1ps

module skyraid_sound (
    input  logic        clk_12M,
    input  logic        rst_n,
    input  logic [7:0]  sound_data,
    input  logic        sound_we,
    output logic [15:0] audio_mixer,
    output logic        dbg
);

logic reg_plane_sweep_en;
logic reg_missile_en;
logic reg_explosion_en;
logic reg_plane_on;
logic reg_attract_en;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        reg_plane_sweep_en <= 1'b0;
        reg_missile_en     <= 1'b0;
        reg_explosion_en   <= 1'b0;
        reg_plane_on       <= 1'b0;
        reg_attract_en     <= 1'b0;
    end else if (sound_we) begin
        reg_plane_sweep_en <= sound_data[0];
        reg_missile_en     <= sound_data[1];
        reg_explosion_en   <= sound_data[2];
        reg_plane_on       <= sound_data[4];
        reg_attract_en     <= sound_data[5];
    end
end

assign dbg = reg_attract_en;

localparam integer CLK_555_DIV = 5396;

logic [12:0] clk_555_cnt;
logic        clk_555_strobe;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        clk_555_cnt    <= 13'd0;
        clk_555_strobe <= 1'b0;
    end else begin
        clk_555_strobe <= 1'b0;
        if (clk_555_cnt == CLK_555_DIV - 1) begin
            clk_555_cnt    <= 13'd0;
            clk_555_strobe <= 1'b1;
        end else begin
            clk_555_cnt <= clk_555_cnt + 1'b1;
        end
    end
end

logic [15:0] lfsr_reg;
logic        noise_out;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        lfsr_reg <= 16'hACE1;
    end else if (reg_attract_en) begin
        lfsr_reg <= 16'h0000;
    end else if (clk_555_strobe) begin
        lfsr_reg <= {lfsr_reg[14:0], ~(lfsr_reg[0] ^ lfsr_reg[14])};
    end
end

assign noise_out = lfsr_reg[15];

wire node_20 = ~(reg_explosion_en | noise_out);

logic [23:0] rc_cap;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        rc_cap <= 24'd0;
    end else begin
        if (reg_explosion_en) begin
            rc_cap <= rc_cap + ((24'hFFFFFF - rc_cap) >> 15);
        end else begin
            if (node_20) begin
                if (rc_cap < 24'h200001)
                    rc_cap <= 24'd0;
                else
                    rc_cap <= rc_cap - (rc_cap >> 21);
            end
        end
    end
end

wire        node21_active = node_20;
wire signed [24:0] node21_v = node21_active ? {1'b0, rc_cap} : 25'sd0;

logic [7:0] audio_tick_cnt;
wire        audio_tick = (audio_tick_cnt == 8'd255);

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) audio_tick_cnt <= 8'd0;
    else        audio_tick_cnt <= audio_tick_cnt + 1'b1;
end

localparam signed [17:0] BQ_A1 = -18'sd130952;
localparam signed [17:0] BQ_A2 =  18'sd65432;
localparam signed [17:0] BQ_B0 = -18'sd12529;
localparam signed [17:0] BQ_B2 =  18'sd12529;

logic signed [24:0] bq_x1, bq_x2;
logic signed [39:0] bq_y1, bq_y2;

wire signed [63:0] bq_acc = (-BQ_A1 * bq_y1) - (BQ_A2 * bq_y2)
                           + (BQ_B0 * node21_v) + (BQ_B2 * bq_x2);
wire signed [39:0] bq_y_next = bq_acc >>> 16;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        bq_x1 <= 25'sd0; bq_x2 <= 25'sd0;
        bq_y1 <= 40'sd0; bq_y2 <= 40'sd0;
    end else if (audio_tick) begin
        if (!reg_explosion_en && rc_cap == 24'd0) begin
            bq_x1 <= 25'sd0; bq_x2 <= 25'sd0;
            bq_y1 <= 40'sd0; bq_y2 <= 40'sd0;
        end else begin
            bq_x2 <= bq_x1;
            bq_x1 <= node21_v;
            bq_y2 <= bq_y1;
            bq_y1 <= bq_y_next;
        end
    end
end

localparam int EXPL_SHIFT = 8;
wire signed [31:0] expl_scaled = bq_y1 >>> EXPL_SHIFT;
wire signed [15:0] expl_snd    = (expl_scaled >  32'sd32767) ?  16'sh7FFF :
                                  (expl_scaled < -32'sd32768) ? -16'sh8000 :
                                   expl_scaled[15:0];

wire expl_active = reg_explosion_en | (rc_cap != 24'd0) |
                   (bq_y1 != 40'sd0) | (bq_y2 != 40'sd0);

localparam logic [31:0] JET_INC_OFF = 32'h00E865AC;
localparam logic [31:0] JET_INC_ON  = 32'h00BD5CA5;

logic [31:0] jet_accum;
logic        jet_msb_prev;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        jet_accum    <= 32'd0;
        jet_msb_prev <= 1'b0;
    end else begin
        jet_msb_prev <= jet_accum[31];
        jet_accum    <= jet_accum + (reg_plane_sweep_en ? JET_INC_ON : JET_INC_OFF);
    end
end

wire jet_vco_tick = jet_accum[31] & ~jet_msb_prev;

logic [15:0] jet_shift;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        jet_shift <= 16'd0;
    end else if (jet_vco_tick) begin
        jet_shift <= {jet_shift[14:0], noise_out};
    end
end

wire jet_a = jet_shift[0];
wire jet_b = jet_shift[15];

wire [15:0] plane_snd = (!reg_plane_on)                                  ? 16'h0000 :
                         (jet_shift[0] & jet_shift[14])                   ? 16'hAAAA :
                         (jet_shift[0] | jet_shift[14])                   ? 16'h5555 :
                                                                            16'h0000;

localparam logic [31:0] MSL_INC_MAX = 32'h00D08783;

logic [31:0] msl_cap;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        msl_cap <= 32'd0;
    end else begin
        if (reg_missile_en)
            msl_cap <= msl_cap + ((32'hFFFFFFFF - msl_cap) >> 19);
        else
            msl_cap <= msl_cap - ((msl_cap >> 23) + (msl_cap >> 24));
    end
end

wire [15:0] msl_cap_frac = msl_cap[31:16];
wire [47:0] msl_inc_wide = {32'd0, msl_cap_frac} * {16'd0, MSL_INC_MAX};
wire [31:0] msl_inc      = msl_inc_wide[47:16];

logic [31:0] msl_accum;
logic        msl_msb_prev;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        msl_accum    <= 32'd0;
        msl_msb_prev <= 1'b0;
    end else begin
        msl_msb_prev <= msl_accum[31];
        msl_accum    <= msl_accum + msl_inc;
    end
end

wire msl_vco_tick = msl_accum[31] & ~msl_msb_prev;

logic [15:0] msl_shift;

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        msl_shift <= 16'd0;
    end else if (msl_vco_tick) begin
        msl_shift <= {msl_shift[14:0], noise_out};
    end
end

wire msl_a = msl_shift[0];
wire msl_b = msl_shift[15];

localparam integer W_EXPL  = 17936;
localparam integer W_JET_A =   840;
localparam integer W_JET_B =   840;
localparam integer W_MSL_A =  3946;
localparam integer W_MSL_B =  3946;
localparam integer W_PLANE =  5261;

wire [15:0] expl_u  = expl_active ? {~expl_snd[15], expl_snd[14:0]} : 16'h8000;
wire [15:0] jet_a_u = jet_a ? 16'hFFFF : 16'h0000;
wire [15:0] jet_b_u = jet_b ? 16'hFFFF : 16'h0000;
wire [15:0] msl_a_u = msl_a ? 16'hFFFF : 16'h0000;
wire [15:0] msl_b_u = msl_b ? 16'hFFFF : 16'h0000;

wire [47:0] mix_expl  = W_EXPL  * {32'd0, expl_u};
wire [47:0] mix_jet_a = W_JET_A * {32'd0, jet_a_u};
wire [47:0] mix_jet_b = W_JET_B * {32'd0, jet_b_u};
wire [47:0] mix_msl_a = W_MSL_A * {32'd0, msl_a_u};
wire [47:0] mix_msl_b = W_MSL_B * {32'd0, msl_b_u};
wire [47:0] mix_plane = W_PLANE * {32'd0, plane_snd};

wire [47:0] mix_sum = mix_expl + mix_jet_a + mix_jet_b
                    + mix_msl_a + mix_msl_b + mix_plane;

wire [31:0] mix_out = mix_sum[47:16];

always_ff @(posedge clk_12M or negedge rst_n) begin
    if (!rst_n) begin
        audio_mixer <= 16'h0000;
    end else begin
        if (reg_attract_en)
            audio_mixer <= 16'h0000;
        else if (mix_out[31:16] != 16'd0)
            audio_mixer <= 16'hFFFF;
        else
            audio_mixer <= mix_out[15:0];
    end
end

endmodule
