module cheekyms_audio (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        i_mute,
    input  wire        i_cheese,
    input  wire        i_music,
    input  wire        i_mouse,
    input  wire        i_hammer,
    input  wire        i_pest,
    input  wire        i_mouse_dies,
    input  wire        i_pest_dies,
    input  wire        i_coin_extra,
    input  wire        i_coin_in,
    output reg  [7:0]  audio_out
);

    wire mute_act       = ~i_mute;
    wire cheese_act     = ~i_cheese;
    wire hammer_act     = ~i_hammer;
    wire pest_act       = ~i_pest;
    wire mouse_act      = i_mouse;
    wire mouse_dies_act = i_mouse_dies;
    wire pest_dies_act  = i_pest_dies;
    wire coin_extra_act = i_coin_extra;

    reg [10:0] clk_div;
    reg        tick_48k;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 11'd0;
            tick_48k <= 1'b0;
        end else if (clk_div >= 11'd450) begin
            clk_div  <= 11'd0;
            tick_48k <= 1'b1;
        end else begin
            clk_div  <= clk_div + 11'd1;
            tick_48k <= 1'b0;
        end
    end

    reg hammer_d, pest_dies_d, mouse_dies_d, coin_extra_d, cheese_d, mouse_d, pest_d, coin_in_d;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            hammer_d     <= 1'b0;
            pest_dies_d  <= 1'b0;
            mouse_dies_d <= 1'b0;
            coin_extra_d <= 1'b0;
            cheese_d     <= 1'b0;
            mouse_d      <= 1'b0;
            pest_d       <= 1'b0;
            coin_in_d    <= 1'b0;
        end else if (tick_48k) begin
            hammer_d     <= hammer_act;
            pest_dies_d  <= pest_dies_act;
            mouse_dies_d <= mouse_dies_act;
            coin_extra_d <= coin_extra_act;
            cheese_d     <= cheese_act;
            mouse_d      <= mouse_act;
            pest_d       <= pest_act;
            coin_in_d    <= i_coin_in;
        end
    end

    wire trig_hammer     = hammer_act     && !hammer_d;
    wire trig_pest_dies  = pest_dies_act  && !pest_dies_d;
    wire trig_mouse_dies = mouse_dies_act && !mouse_dies_d;
    wire trig_coin_extra = coin_extra_act && !coin_extra_d;
    wire trig_cheese     = cheese_act     && !cheese_d;
    wire trig_mouse      = mouse_act      && !mouse_d;
    wire trig_pest       = pest_act       && !pest_d;
    wire trig_coin_in    = i_coin_in      && !coin_in_d;

    wire [6:0] sig_music = i_music ? 7'd24 : 7'd0;

    reg [12:0] mouse_timer;
    reg [9:0]  cnt_mouse;
    reg        wave_mouse;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            mouse_timer <= 13'd0;
            cnt_mouse   <= 10'd0;
            wave_mouse  <= 1'b0;
        end else if (tick_48k) begin
            if (trig_mouse) begin
                mouse_timer <= 13'd2400;
            end else if (mouse_timer != 13'd0) begin
                mouse_timer <= mouse_timer - 13'd1;
            end

            if (mouse_act || (mouse_timer != 13'd0)) begin
                if (cnt_mouse >= 10'd38) begin
                    cnt_mouse  <= 10'd0;
                    wave_mouse <= ~wave_mouse;
                end else begin
                    cnt_mouse <= cnt_mouse + 10'd1;
                end
            end else begin
                wave_mouse <= 1'b0;
                cnt_mouse  <= 10'd0;
            end
        end
    end
    wire [6:0] sig_mouse = ((mouse_act || (mouse_timer != 13'd0)) && wave_mouse) ? 7'd14 : 7'd0;

    reg [9:0]  cnt_hammer;
    reg        wave_hammer;
    reg [12:0] env_hammer;
    wire [9:0] hammer_period = 10'd60 + (10'd64 - {3'd0, env_hammer[12:6]});

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cnt_hammer  <= 10'd0;
            wave_hammer <= 1'b0;
            env_hammer  <= 13'd0;
        end else if (tick_48k) begin
            if (trig_hammer) begin
                env_hammer <= 13'd4095;
            end else if (env_hammer > 13'd32) begin
                env_hammer <= env_hammer - (env_hammer >> 7);
            end else begin
                env_hammer <= 13'd0;
            end

            if (env_hammer != 13'd0) begin
                if (cnt_hammer >= hammer_period) begin
                    cnt_hammer  <= 10'd0;
                    wave_hammer <= ~wave_hammer;
                end else begin
                    cnt_hammer <= cnt_hammer + 10'd1;
                end
            end else begin
                cnt_hammer  <= 10'd0;
                wave_hammer <= 1'b0;
            end
        end
    end
    wire [6:0] sig_hammer = wave_hammer ? {1'b0, env_hammer[12:7]} : 7'd0;

    reg [13:0] pest_timer;
    reg [11:0] cnt_pest_mod;
    reg        wave_pest_mod;
    reg [9:0]  cnt_pest_tone;
    reg        wave_pest_tone;
    wire [9:0] pest_pitch = wave_pest_mod ? 10'd42 : 10'd74;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            pest_timer     <= 14'd0;
            cnt_pest_mod   <= 12'd0;
            wave_pest_mod  <= 1'b0;
            cnt_pest_tone  <= 10'd0;
            wave_pest_tone <= 1'b0;
        end else if (tick_48k) begin
            if (trig_pest) begin
                pest_timer <= 14'd6000;
            end else if (pest_timer != 14'd0) begin
                pest_timer <= pest_timer - 14'd1;
            end

            if (pest_act || (pest_timer != 14'd0)) begin
                if (cnt_pest_mod >= 12'd2800) begin
                    cnt_pest_mod  <= 12'd0;
                    wave_pest_mod <= ~wave_pest_mod;
                end else begin
                    cnt_pest_mod <= cnt_pest_mod + 12'd1;
                end

                if (cnt_pest_tone >= pest_pitch) begin
                    cnt_pest_tone  <= 10'd0;
                    wave_pest_tone <= ~wave_pest_tone;
                end else begin
                    cnt_pest_tone <= cnt_pest_tone + 10'd1;
                end
            end else begin
                cnt_pest_mod   <= 12'd0;
                wave_pest_mod  <= 1'b0;
                cnt_pest_tone  <= 10'd0;
                wave_pest_tone <= 1'b0;
            end
        end
    end
    wire [6:0] sig_pest = ((pest_act || (pest_timer != 14'd0)) && wave_pest_tone) ? 7'd16 : 7'd0;

    reg [13:0] m_dies_timer;
    reg [9:0]  cnt_m_dies;
    reg        wave_m_dies;
    reg [9:0]  pitch_m_dies;
    reg [6:0]  pitch_step_cnt;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            m_dies_timer   <= 14'd0;
            cnt_m_dies     <= 10'd0;
            wave_m_dies    <= 1'b0;
            pitch_m_dies   <= 10'd28;
            pitch_step_cnt <= 7'd0;
        end else if (tick_48k) begin
            if (trig_mouse_dies) begin
                m_dies_timer   <= 14'd12000;
                pitch_m_dies   <= 10'd28;
                pitch_step_cnt <= 7'd0;
            end else if (m_dies_timer != 14'd0) begin
                m_dies_timer <= m_dies_timer - 14'd1;
            end

            if (mouse_dies_act || (m_dies_timer != 14'd0)) begin
                if (pitch_step_cnt >= 7'd90) begin
                    pitch_step_cnt <= 7'd0;
                    if (pitch_m_dies < 10'd160) pitch_m_dies <= pitch_m_dies + 10'd1;
                end else begin
                    pitch_step_cnt <= pitch_step_cnt + 7'd1;
                end

                if (cnt_m_dies >= pitch_m_dies) begin
                    cnt_m_dies  <= 10'd0;
                    wave_m_dies <= ~wave_m_dies;
                end else begin
                    cnt_m_dies <= cnt_m_dies + 10'd1;
                end
            end else begin
                wave_m_dies    <= 1'b0;
                pitch_m_dies   <= 10'd28;
                cnt_m_dies     <= 10'd0;
                pitch_step_cnt <= 7'd0;
            end
        end
    end
    wire [6:0] sig_mouse_dies = ((mouse_dies_act || (m_dies_timer != 14'd0)) && wave_m_dies) ? 7'd18 : 7'd0;

    reg [9:0]  cnt_p_dies;
    reg        wave_p_dies;
    reg [12:0] env_p_dies;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cnt_p_dies  <= 10'd0;
            wave_p_dies <= 1'b0;
            env_p_dies  <= 13'd0;
        end else if (tick_48k) begin
            if (trig_pest_dies) begin
                env_p_dies <= 13'd4095;
            end else if (env_p_dies > 13'd32) begin
                env_p_dies <= env_p_dies - (env_p_dies >> 7);
            end else begin
                env_p_dies <= 13'd0;
            end

            if (pest_dies_act || (env_p_dies != 13'd0)) begin
                if (cnt_p_dies >= 10'd95) begin
                    cnt_p_dies  <= 10'd0;
                    wave_p_dies <= ~wave_p_dies;
                end else begin
                    cnt_p_dies <= cnt_p_dies + 10'd1;
                end
            end else begin
                cnt_p_dies  <= 10'd0;
                wave_p_dies <= 1'b0;
            end
        end
    end
    wire [6:0] sig_pest_dies = wave_p_dies ? (pest_dies_act ? 7'd20 : {1'b0, env_p_dies[12:7]}) : 7'd0;

    reg [13:0] coin_ex_timer;
    reg [9:0]  cnt_coin;
    reg        wave_coin;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            coin_ex_timer <= 14'd0;
            cnt_coin      <= 10'd0;
            wave_coin     <= 1'b0;
        end else if (tick_48k) begin
            if (trig_coin_extra || trig_coin_in) begin
                coin_ex_timer <= 14'd11000;
            end else if (coin_ex_timer != 14'd0) begin
                coin_ex_timer <= coin_ex_timer - 14'd1;
            end

            if (coin_extra_act || (coin_ex_timer != 14'd0)) begin
                if (cnt_coin >= 10'd30) begin
                    cnt_coin  <= 10'd0;
                    wave_coin <= ~wave_coin;
                end else begin
                    cnt_coin <= cnt_coin + 10'd1;
                end
            end else begin
                wave_coin <= 1'b0;
                cnt_coin  <= 10'd0;
            end
        end
    end
    wire [6:0] sig_coin = ((coin_extra_act || (coin_ex_timer != 14'd0)) && wave_coin) ? 7'd20 : 7'd0;

    reg [12:0] cheese_timer;
    reg [14:0] lfsr;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cheese_timer <= 13'd0;
            lfsr         <= 15'h7FFF;
        end else if (tick_48k) begin
            if (trig_cheese) begin
                cheese_timer <= 13'd3200;
            end else if (cheese_timer != 13'd0) begin
                cheese_timer <= cheese_timer - 13'd1;
            end

            lfsr <= {lfsr[13:0], lfsr[14] ^ lfsr[13]};
        end
    end
    wire [6:0] sig_cheese = ((cheese_act || (cheese_timer != 13'd0)) && lfsr[0:0]) ? 7'd12 : 7'd0;

    wire [7:0] master_mix = {1'b0, sig_music} + {1'b0, sig_mouse} + {1'b0, sig_hammer} +
                            {1'b0, sig_pest}  + {1'b0, sig_mouse_dies} + {1'b0, sig_pest_dies} +
                            {1'b0, sig_coin}  + {1'b0, sig_cheese};

    wire [6:0] clamped_mix = master_mix[7] ? 7'd127 : master_mix[6:0];

    reg [11:0] lpf1;
    reg [11:0] lpf2;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            lpf1      <= 12'd0;
            lpf2      <= 12'd0;
            audio_out <= 8'd0;
        end else if (tick_48k) begin
            if (mute_act) begin
                lpf1      <= 12'd0;
                lpf2      <= 12'd0;
                audio_out <= 8'd0;
            end else begin
                lpf1      <= lpf1 - (lpf1 >> 3) + {5'd0, clamped_mix};
                lpf2      <= lpf2 - (lpf2 >> 3) + {2'b00, lpf1[11:2]};
                audio_out <= lpf2[10:3];
            end
        end
    end

endmodule
