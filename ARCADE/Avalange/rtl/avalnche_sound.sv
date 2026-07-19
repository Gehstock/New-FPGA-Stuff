// Atari Avalanche (1978) on MiST FPGA
// (Gehstock 2026)
module avalnche_sound (
    input  logic               clk_12m,
    input  logic               reset_n,
    input  logic               attract_en,
    input  logic               aud0_en,
    input  logic               aud1_en,
    input  logic               aud2_en,
    input  logic        [5:0]  noise_amplitude,
    output logic signed [15:0] audio
);

    localparam logic [31:0] TICKS_BEEP2 = 32'd4_800_000; 

    localparam logic [31:0] DIV_AUD1  = 32'd24381;  
    localparam logic [31:0] DIV_AUD2  = 32'd6095;   
    localparam logic [31:0] DIV_NOISE = 32'd762;    

    logic [31:0] cnt_aud1, cnt_aud2, cnt_noise;
    logic        sig_aud1, sig_aud2, clk_noise;

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            cnt_aud1  <= '0; sig_aud1  <= 1'b0;
            cnt_aud2  <= '0; sig_aud2  <= 1'b0;
            cnt_noise <= '0; clk_noise <= 1'b0;
        end else begin
            if (cnt_aud1 >= DIV_AUD1) begin cnt_aud1 <= '0; sig_aud1 <= ~sig_aud1; end
            else cnt_aud1 <= cnt_aud1 + 1'b1;

            if (cnt_aud2 >= DIV_AUD2) begin cnt_aud2 <= '0; sig_aud2 <= ~sig_aud2; end
            else cnt_aud2 <= cnt_aud2 + 1'b1;

            if (cnt_noise >= DIV_NOISE) begin cnt_noise <= '0; clk_noise <= ~clk_noise; end
            else cnt_noise <= cnt_noise + 1'b1;
        end
    end

    reg [15:0] lfsr;
    wire fb_bit = lfsr[15] ^ lfsr[14];

    always_ff @(posedge clk_noise or negedge reset_n) begin
        if (!reset_n) begin
            lfsr <= 16'hACE1;
        end else begin
            lfsr <= {lfsr[14:0], fb_bit};
        end
    end
    
    wire lfsr_out = lfsr[15];

    logic aud2_en_d;
    always_ff @(posedge clk_12m) begin
        aud2_en_d <= aud2_en;
    end
    wire aud2_trig = aud2_en && !aud2_en_d;

    logic [31:0] beep2_timer;
    logic        beep2_active;

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            beep2_timer  <= '0;
            beep2_active <= 1'b0;
        end else begin
            if (aud2_trig) begin
                beep2_timer  <= TICKS_BEEP2;
                beep2_active <= 1'b1;
            end else if (beep2_timer > 0) begin
                beep2_timer  <= beep2_timer - 1;
                beep2_active <= 1'b1;
            end else begin
                beep2_active <= 1'b0;
            end
        end
    end

    logic signed [31:0] amp_aud1;
    logic signed [31:0] amp_aud2;
    logic signed [31:0] amp_noise;
    logic signed [31:0] rc_filter;
    logic signed [31:0] noise_val;

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            audio     <= '0;
            rc_filter <= '0;
        end else begin
            amp_aud1  = (aud1_en) ? (sig_aud1 ? 32'd750 : -32'd750) : 32'd0;
            amp_aud2  = (beep2_active) ? (sig_aud2 ? 32'd750 : -32'd750) : 32'd0;
            
            noise_val = {10'd0, noise_amplitude, 16'd0} >>> 16;

            if (aud0_en) begin
                amp_noise = lfsr_out ? noise_val : -noise_val;
            end else begin
                amp_noise = 32'd0;
            end

            rc_filter <= rc_filter + ((amp_noise - rc_filter) >>> 6);

            if (attract_en) begin
                audio <= 16'sh0000;
            end else begin
                audio <= 16'((amp_aud1 + amp_aud2 + rc_filter) <<< 4);
            end
        end
    end

endmodule

