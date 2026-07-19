module nitedrvr_sound (
    input  wire        clk_sys,       
    input  wire        rst_n,
    input  wire        out0_we,       
    input  wire        out1_we,       
    input  wire  [7:0] cpu_data_in,
    input  wire  [8:0] h_cnt,   
    input  wire  [7:0] v_cnt,	 
    output wire [7:0]  audio_out,      
    output wire        video_crash      
);

    reg [5:0] out0_latch;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)          out0_latch <= 6'd0;
        else if (out0_we)    out0_latch <= cpu_data_in[5:0]; 
    end

    wire [3:0] motor_data = out0_latch[3:0];
    wire       skid1_en   = out0_latch[4];
    wire       skid2_en   = out0_latch[5];

    reg       attract_reg;
    reg [3:0] crash_data;
    reg       crash_data_en;
    reg       out1_we_prev;
    reg [7:0] crash_speed_divider;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            attract_reg         <= 1'b1;
            crash_data          <= 4'd0;
            crash_data_en       <= 1'b0;
            out1_we_prev        <= 1'b0;
            crash_speed_divider <= 8'd0;
        end else begin
            out1_we_prev <= out1_we;

            if (out1_we && !out1_we_prev) begin
                attract_reg <= cpu_data_in[1]; 
                
                if (cpu_data_in[0] == 1'b0) begin
                    crash_data_en       <= 1'b1;
                    crash_data          <= 4'd15; 
                    crash_speed_divider <= 8'd0;
                end
            end else if (ena_3k && crash_data_en) begin
                crash_speed_divider <= crash_speed_divider + 8'd1;
                
                if (crash_speed_divider == 8'd128) begin
                    crash_speed_divider <= 8'd0;
                    if (crash_data > 4'd0) begin
                        crash_data <= crash_data - 4'd1;
                    end else begin
                        crash_data_en <= 1'b0;
                    end
                end
            end
        end
    end

    assign video_crash = crash_data_en;

    reg [11:0] ena_3k_counter;
    wire       ena_3k = (ena_3k_counter == 12'd0);
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) ena_3k_counter <= 12'd0;
        else        ena_3k_counter <= ena_3k_counter + 12'd1;
    end

    localparam FREQ_TUNE = 50;

    reg [8:0]  rpm_val;
    reg [16:0] ramp_term;
    reg [16:0] ramp_count;
    reg        motor_clk;
    reg [2:0]  counter_b;
    reg        counter_a;
    reg        motor_clk_prev;
    reg        counter_a_clk_prev;
    reg [3:0]  motor_prefilter;
    reg [3:0]  motor_filter_t1;
    reg [3:0]  motor_filter_t2;
    reg [3:0]  motor_filter_t3;
    reg [5:0]  motor_filtered;
    wire [31:0] full_mult_result = (17'd200 - FREQ_TUNE) * rpm_val;
    wire [16:0] ramp_term_unfilt = full_mult_result[16:0];

    always @(posedge clk_sys) begin
        case (motor_data) 
            4'b0000: rpm_val <= 25;
            4'b0001: rpm_val <= 40;
            4'b0010: rpm_val <= 55;
            4'b0011: rpm_val <= 70;
            4'b0100: rpm_val <= 85;
            4'b0101: rpm_val <= 100;
            4'b0110: rpm_val <= 115;
            4'b0111: rpm_val <= 130;
            4'b1000: rpm_val <= 145;
            4'b1001: rpm_val <= 160;
            4'b1010: rpm_val <= 175;
            4'b1011: rpm_val <= 190;
            4'b1100: rpm_val <= 205;
            4'b1101: rpm_val <= 230;
            4'b1110: rpm_val <= 245;
            4'b1111: rpm_val <= 280;
        endcase
    end
	 
     always @(posedge clk_sys) begin
        if (ena_3k) begin
            if (ramp_term_unfilt > ramp_term) begin
                ramp_term <= ramp_term + 17'd5;
            end else if (ramp_term_unfilt < ramp_term) begin
                ramp_term <= ramp_term - 17'd3;
            end
        end
    end

        always @(posedge clk_sys) begin
        if (ramp_count > ramp_term) begin
            ramp_count <= 17'd0;
            motor_clk  <= 1'b0;
        end else begin
            ramp_count <= ramp_count + 17'd1;
            motor_clk  <= 1'b1;
        end
    end

    wire counter_a_clk = counter_b[0] ^ counter_b[2];

    always @(posedge clk_sys) begin
        motor_clk_prev     <= motor_clk;
        counter_a_clk_prev <= counter_a_clk;

        if (!attract_reg) begin
            if (motor_clk && !motor_clk_prev) begin
                counter_b <= counter_b + 3'd1;
            end
            if (counter_a_clk && !counter_a_clk_prev) begin
                counter_a <= ~counter_a;
            end
        end else begin
            counter_b <= 3'd0;
            counter_a <= 1'b0;
        end
    end

    reg [2:0] motor_prefilter_reg;
    always @(posedge clk_sys) begin
        motor_prefilter_reg <= {2'b00, counter_b[1]} + {2'b00, counter_b[2]} + {2'b00, counter_a};
    end

    always @(posedge clk_sys) begin
        if (ena_3k) begin
            motor_filter_t1 <= {1'b0, motor_prefilter_reg} + {1'b0, motor_prefilter_reg};
            motor_filter_t2 <= motor_filter_t1;
            motor_filter_t3 <= motor_filter_t2;
        end
        motor_filtered <= {2'b00, motor_filter_t1} + 
                          {1'b0, motor_filter_t2, 1'b0} + 
                          {2'b00, motor_filter_t3};
    end

    reg        h_cnt_prev;
    reg        noise_clk_en;
    always @(posedge clk_sys) begin
        h_cnt_prev   <= h_cnt[3];
        noise_clk_en <= (h_cnt[3] && !h_cnt_prev);
    end

    reg [15:0] lfsr_reg;
    wire       lfsr_feedback = ~(lfsr_reg[14] ^ lfsr_reg[0]); 

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hFFFF;
        end else if (noise_clk_en) begin 
            lfsr_reg <= {lfsr_feedback, lfsr_reg[15:1]};
        end
    end

    reg [11:0] skid_cnt1;
    reg [11:0] skid_cnt2;
    wire        skid_wave1;
    wire        skid_wave2;

reg  [15:0] noise_shift;
reg noise;
reg         shift_in;
    always @(posedge v_cnt[1] or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            noise_shift <= 16'd0;
            noise       <= 1'b0;
            shift_in    <= 1'b1;
        end else begin
            noise_shift <= {shift_in, noise_shift[15:1]};
            noise       <= noise_shift[0];
            shift_in    <= !(noise_shift[6] ^ noise_shift[8]);
        end
    end


    tire_screech #(
        .Inc1(24),
        .Inc2(33),
        .Dec1(29),
        .Dec2(16)
    ) Screech_gen1 (
        .Clk(h_cnt[2]),
		  .ena(skid1_en),
        .Noise(noise),
        .Screech_out(skid_wave1)
    );

    tire_screech #(
        .Inc1(24),
        .Inc2(33),
        .Dec1(23),
        .Dec2(12)
    ) Screech_gen2 (
        .Clk(h_cnt[2]),
		  .ena(skid2_en),
        .Noise(noise),
        .Screech_out(skid_wave2)
    );

    wire [7:0] skid_output  = (skid_wave1 || skid_wave2) ? 8'd45 : 8'd0;
    wire [7:0] crash_noise  = lfsr_reg[15] ? {4'd0, crash_data} : 8'd0;
    wire [7:0] crash_volume = (crash_data_en && !attract_reg) ? {crash_noise[3:0], 4'h0} : 8'd0;
    wire [7:0] motor_volume = (!attract_reg) ? {motor_filtered, 2'b00} : 8'd0;
    wire [9:0] mixed_audio  = {2'b00, motor_volume} + {2'b00, crash_volume} + {2'b00, skid_output};
    assign audio_out = (attract_reg) ? 8'd0 : (mixed_audio > 10'd255) ? 8'd255 : mixed_audio[7:0];

endmodule

module tire_screech #(
    parameter [13:0] Inc1 = 14'd24,
    parameter [13:0] Inc2 = 14'd34,
    parameter [13:0] Dec1 = 14'd23,
    parameter [13:0] Dec2 = 14'd12
)(
    input  wire Clk,             // 750kHz
    input  wire ena,
    input  wire Noise,
    output reg  Screech_out
);

    reg [13:0] screech_count;
    reg        screech_state;

    always @(posedge Clk) begin
        if (!ena) begin
            screech_count <= 14'd1000;
            screech_state <= 1'b1;
            Screech_out   <= 1'b0;
        end else begin
            if (screech_state == 1'b1) begin
                if (Noise == 1'b1) begin
                    screech_count <= screech_count + Inc2;
                end else begin
                    screech_count <= screech_count + Inc1;
                end
                if (screech_count >= 14'd10000) begin
                    screech_state <= 1'b0;
                end
            end else begin
                if (Noise == 1'b1) begin
                    screech_count <= screech_count - Dec2;
                end else begin
                    screech_count <= screech_count - Dec1;
                end
                if (screech_count <= 14'd1000) begin
                    screech_state <= 1'b1;
                end
            end
            Screech_out <= screech_state;
        end
    end

endmodule

