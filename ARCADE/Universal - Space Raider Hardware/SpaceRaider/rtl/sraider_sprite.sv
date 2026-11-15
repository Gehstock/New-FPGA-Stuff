module sraider_sprite (
    input  logic       clk_20mhz_i,
    input  logic       por_n_i,
    input  logic       res_n_i,
    input  logic       clk_en_10mhz_i,
    input  logic       clk_en_10mhz_n_i,
    input  logic       clk_en_5mhz_i,
    input  logic       clk_en_5mhz_n_i,
    input  logic       cs7_n_i,
    input  logic [9:0] a_i,
    input  logic [7:0] d_from_cpu_i,
    input  logic [3:0] h_i,
    input  logic [3:0] h_t_i,
    input  logic       hx_i,
    input  logic       ha_d_i,
    input  logic [3:0] v_i,
    input  logic [3:0] v_t_i,
    input  logic       vbl_n_i,
    input  logic       vbl_d_n_i,
    input  logic       vc_d_i,
    input  logic       blank_flont_i,
    input  logic       blank_i,
    output logic [4:1] sig_o
);

    logic [15:0] rd_shift_int, rd_shift_s, rd_vram_s, vram_q, rom_sprite_d_i;
    logic [11:6] ma_q;
    logic [11:0] ma_s;
    logic [10:0] c_s;
    logic [9:0]  ra_s, cr_s;
    logic [7:0]  rb_s, rc_s, df_muxed_s, lu_d_s, ctrl_lu_d_s, v_cnt_a5_a6_s, a_v, b_v, df_v, h5_n_s, h5_d_s;
    logic [6:1]  ctrl_lu_q_d_s, ctrl_lu_q;
    logic [6:0]  mc_q;
    logic [5:0]  x_s;
    logic [4:1]  e7_q, e7_s, e7_d, e7_q_n, e7_s_n;
    logic [4:0]  v_cnt_s, cl_q, lu_a_s, ctrl_lu_a_s;
    logic [3:1]  ca_q;
    logic [3:0]  lu_d_mux_s, rs_int, rs_s, rs_n_s, j6_shifter, h6_shifter;
    logic [3:0]  vram_a6_out_s, vram_b6_out_s, vram_c6_out_s, vram_d6_out_s;
    logic [3:0]  f7_q1, f7_q2, j5_q1, j5_q2, f7_s1, f7_s2, j5_s1, j5_s2;
    logic [2:1]  f7_ck_en_s, f7_cl_s, j5_ck_en_s, j5_cl_s;
    logic [2:0]  j7_s;
    logic [1:0]  mb_q;
    logic        sprite_ram_cs_n_s, sprite_ram_we_n_s, clk_5mhz_n_q, clk_en_eck_s, clk_en_rd_s;
    logic        clk_en_5ck_n_s, clk_en_6ck_n_s, clk_en_7ck_n_s, clk_en_b7_p3_s, clk_en_e7_3_s;
    logic        s6ck_n_s, s7ck_n_s, e5_p8_s, a8_p5_n_s, ct0_s, ct1_s, cr_mux_sel_s;
    logic        ck_inh_s, ck_inh_n_q, qh1_s, qh2_s, rs_enable_s, shift_oc_n_s, vram_we_n_s, cpu_access_v;
    logic        clk_5mhz_q, a7_p5_q, a7_p9_q, a8_p5_q, n4_p5_q, a7_p5_s, n4_p5_s;
    logic        e7_ck_en_s, e7_cl_n_s, f5_p3_q_v, f5_p3_d_v, b76_q, b76_d, ff_q_v, ff_d_v;

    function automatic logic [7:0] ttl_45_f(input logic a, input logic b, input logic c, input logic d);
        logic [3:0] idx;
        idx      = {d, c, b, a};
        ttl_45_f = 8'hFF;
        if (idx < 4'd8) ttl_45_f[idx[2:0] +: 1] = 1'b0;
        return ttl_45_f;
    endfunction

    always_comb begin
        f7_s1 = f7_cl_s[1:1] ? 4'd0 : (f7_ck_en_s[1:1] ? f7_q1 + 1'b1 : f7_q1);
        f7_s2 = f7_cl_s[2:2] ? 4'd0 : (f7_ck_en_s[2:2] ? f7_q2 + 1'b1 : f7_q2);
        j5_s1 = j5_cl_s[1:1] ? 4'd0 : (j5_ck_en_s[1:1] ? j5_q1 + 1'b1 : j5_q1);
        j5_s2 = j5_cl_s[2:2] ? 4'd0 : (j5_ck_en_s[2:2] ? j5_q2 + 1'b1 : j5_q2);
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            f7_q1 <= 4'd0;
            f7_q2 <= 4'd0;
            j5_q1 <= 4'd0;
            j5_q2 <= 4'd0;
        end else begin
            f7_q1 <= f7_s1;
            f7_q2 <= f7_s2;
            j5_q1 <= j5_s1;
            j5_q2 <= j5_s2;
        end
    end

    assign e7_q_n = ~e7_q;
    assign e7_s_n = ~e7_s;

    always_comb begin
        if (!e7_cl_n_s)      e7_s = 4'd0;
        else if (e7_ck_en_s) e7_s = e7_d;
        else                 e7_s = e7_q;
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) e7_q <= 4'd0;
        else          e7_q <= e7_s;
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            clk_5mhz_q <= 1'b0;
            a7_p5_q    <= 1'b0;
            a7_p9_q    <= 1'b0;
            a8_p5_q    <= 1'b0;
            n4_p5_q    <= 1'b0;
        end else begin
            if (clk_en_5mhz_i)        clk_5mhz_q <= 1'b1;
            else if (clk_en_5mhz_n_i) clk_5mhz_q <= 1'b0;
            a7_p5_q <= a7_p5_s;
            if (clk_en_5mhz_n_i) a7_p9_q <= j5_q2[3:3];
            if (clk_en_eck_s)    a8_p5_q <= ~(j7_s[1:1] & j7_s[2:2]);
            n4_p5_q <= n4_p5_s;
        end
    end

    always_comb begin
        if (!a7_p5_q)                n4_p5_s = 1'b0;
        else if (v_i[2:2] & ~vc_d_i) n4_p5_s = 1'b1;
        else                         n4_p5_s = n4_p5_q;

        if (h_i[0:0] & ~ha_d_i)      a7_p5_s = f7_q2[3:3];
        else                         a7_p5_s = a7_p5_q;
    end

    assign f5_p3_q_v = ~(~a7_p5_q & vbl_n_i);
    assign f5_p3_d_v = ~(~a7_p5_s & vbl_d_n_i);
    assign h5_n_s    = ttl_45_f(j5_q1[0:0], j5_q1[1:1], h_i[0:0], f5_p3_q_v);
    assign h5_d_s    = ttl_45_f(j5_s1[0:0], j5_s1[1:1], ha_d_i,   f5_p3_d_v);

    assign clk_en_5ck_n_s = ~h5_n_s[5:5] & h5_d_s[5:5];
    assign clk_en_6ck_n_s = ~h5_n_s[6:6] & h5_d_s[6:6];
    assign clk_en_7ck_n_s = ~h5_n_s[7:7] & h5_d_s[7:7];
    assign s6ck_n_s       = h5_n_s[6:6];
    assign s7ck_n_s       = h5_n_s[7:7];

    assign b76_q  = ~f7_q2[3:3] & ~e7_q_n[1:1];
    assign b76_d  = ~f7_q2[3:3] & ~e7_s_n[1:1];
    assign ff_q_v = j5_q2[3:3] | (vbl_n_i   & h_i[0:0] & n4_p5_q) | b76_q;
    assign ff_d_v = j5_s2[3:3] | (vbl_d_n_i & ha_d_i   & n4_p5_s) | b76_d;

    assign f7_ck_en_s[1:1] = ~ff_q_v & ff_d_v;
    assign f7_ck_en_s[2:2] = f7_q1[1:1] & ~f7_s1[1:1];
    assign f7_cl_s[1:1]    = n4_p5_q & h_i[0:0] & vbl_n_i;
    assign f7_cl_s[2:2]    = f7_cl_s[1:1];

    assign j5_cl_s[1:1]    = ~vbl_n_i | (~clk_5mhz_q & ~h5_n_s[0:0]) | n4_p5_q;
    assign j5_cl_s[2:2]    = a7_p9_q | (n4_p5_q & h_i[0:0] & vbl_n_i) | b76_q;
    assign j5_ck_en_s[1:1] = ~(~h_i[0:0] & e7_q[3:3]) & (~ha_d_i & e7_s[3:3]);
    assign j5_ck_en_s[2:2] = ~(j5_q1[2:2] | e7_q[2:2]) & (j5_s1[2:2] | e7_s[2:2]);

    assign e7_d[1:1]      = ~rb_s[7:7];
    assign e7_d[2:2]      = ~(rb_s[7:7] & rc_s[5:5] & ~rc_s[4:4] & (~rc_s[3:3] | rb_s[6:6]));
    assign e7_d[3:3]      = ~e7_d[2:2] & ~a8_p5_q;
    assign e7_d[4:4]      = 1'b0;
    assign e7_ck_en_s     = clk_en_5mhz_i & ~h5_n_s[4:4];
    assign e7_cl_n_s      = f7_q2[3:3] | ~(~clk_5mhz_q & ~h5_n_s[0:0]);
    assign clk_en_e7_3_s  = ~e7_q[3:3] & e7_s[3:3];
    assign clk_en_b7_p3_s = f7_ck_en_s[1:1];
    assign e5_p8_s        = ~(n4_p5_q | (f7_q1[0:0] & f7_q1[1:1]));
    assign a8_p5_n_s      = ~a8_p5_q;
    assign c_s            = {f7_q1[1:0], f7_q2[2:0], j5_q2[3:0], j5_q1[1:0]};

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i)
            v_cnt_s <= 5'd0;
        else if (clk_en_b7_p3_s) begin
            if (!e5_p8_s) v_cnt_s <= {v_t_i, 1'b0};
            else          v_cnt_s <= v_cnt_s + 1'b1;
        end
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i)
            j7_s <= 3'd0;
        else if (clk_en_10mhz_i) begin
            if (!s6ck_n_s)
                j7_s <= {~mc_q[6:6], mc_q[6:6], 1'b0};
            else if (!(ct0_s | ct1_s | a8_p5_n_s | ck_inh_s))
                j7_s <= j7_s + 1'b1;
        end
    end

    assign ct0_s = v_cnt_a5_a6_s[0:0];
    assign ct1_s = v_cnt_a5_a6_s[1:1];
    assign x_s   = v_cnt_a5_a6_s[7:2];

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i)
            v_cnt_a5_a6_s <= 8'h00;
        else if (clk_en_10mhz_i) begin
            if (!s7ck_n_s) begin
                v_cnt_a5_a6_s[7:4] <= rb_s[7:4];
                v_cnt_a5_a6_s[3:0] <= {rb_s[3:2], ~rc_s[7:7], ~rc_s[6:6]};
            end else if (ck_inh_n_q)
                v_cnt_a5_a6_s <= v_cnt_a5_a6_s + 1'b1;
        end
    end

    assign cpu_access_v      = ~cs7_n_i & ~vbl_n_i;
    assign sprite_ram_we_n_s = ~cpu_access_v;
    assign sprite_ram_cs_n_s = ~(cpu_access_v | vbl_n_i);
    assign ra_s              = (!vbl_n_i) ? a_i : {v_cnt_s[4:0], c_s[4:0]};

    spram #(10,8) sprite_ram_b (
        .clock  (clk_20mhz_i),
        .enable (1'b1),
        .address(ra_s),
        .data   (d_from_cpu_i),
        .wren   (~sprite_ram_cs_n_s & ~sprite_ram_we_n_s & clk_en_5mhz_i),
        .q      (rb_s)
    );


    always_comb begin
        a_v  = {rb_s[1:0], 2'b01, rb_s[3:0]};
        b_v  = {2'b11, 1'b0, c_s[10:10], ~v_i[3:3], ~c_s[8:6]};
        rc_s = a_v + b_v;
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            clk_5mhz_n_q <= 1'b0;
            ma_q         <= 6'd0;
            mb_q         <= 2'd0;
            mc_q         <= 7'd0;
            cl_q         <= 5'd0;
            ck_inh_n_q   <= 1'b1;
        end else begin
            if (clk_en_5mhz_n_i)    clk_5mhz_n_q <= 1'b1;
            else if (clk_en_5mhz_i) clk_5mhz_n_q <= 1'b0;
            if (clk_en_5ck_n_s) begin
                mb_q <= rb_s[1:0];
                ma_q <= rb_s[7:2];
            end
            if (clk_en_e7_3_s) begin
                mc_q[3:0] <= rc_s[3:0];
                mc_q[6:4] <= rb_s[6:4];
            end
            if (clk_en_6ck_n_s)   cl_q       <= rb_s[4:0];
            if (clk_en_10mhz_n_i) ck_inh_n_q <= ~ck_inh_s;
        end
    end

    always_comb begin
        ma_s[11:6] = ma_q;
        if (!mc_q[6:6]) ma_s[5:4] = mb_q[1:0];
        else            ma_s[5:4] = {mc_q[3:3] ^ mc_q[4:4], mc_q[5:5] ^ j7_s[2:2]};
        ma_s[3:0] = {mc_q[2:2] ^ mc_q[4:4], mc_q[1:1] ^ mc_q[4:4], mc_q[0:0] ^ mc_q[4:4], mc_q[5:5] ^ j7_s[0:0]};
    end

    gfx2_rom_16bit sprite_rom_inst (
        .clk   (clk_20mhz_i),
        .clk_en(1'b1),
        .addr  (ma_s),
        .data  (rom_sprite_d_i)
    );

    always_comb begin
        df_v = (!cl_q[4:4]) ? rom_sprite_d_i[7:0] : rom_sprite_d_i[15:8];
        if (!mc_q[5:5]) begin
            df_muxed_s = {df_v[6:6], df_v[4:4], df_v[2:2], df_v[0:0], df_v[7:7], df_v[5:5], df_v[3:3], df_v[1:1]};
        end else begin
            df_muxed_s = {df_v[0:0], df_v[2:2], df_v[4:4], df_v[6:6], df_v[1:1], df_v[3:3], df_v[5:5], df_v[7:7]};
        end
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            h6_shifter <= 4'd0;
            j6_shifter <= 4'd0;
        end else if (clk_en_10mhz_i & ~ck_inh_s) begin
            if (!(ct0_s | ct1_s | a8_p5_n_s)) begin
                h6_shifter <= df_muxed_s[3:0];
                j6_shifter <= df_muxed_s[7:4];
            end else begin
                h6_shifter <= {h6_shifter[2:0], 1'b0};
                j6_shifter <= {j6_shifter[2:0], 1'b0};
            end
        end
    end

    assign qh1_s      = h6_shifter[3:3];
    assign qh2_s      = j6_shifter[3:3];
    assign lu_a_s     = {cl_q[2:0], qh2_s, qh1_s};
    assign lu_d_mux_s = (!cl_q[3:3]) ? lu_d_s[3:0] : lu_d_s[7:4];

    prom_10_1 prom_L3 (
        .CLK (clk_20mhz_i),
        .ADDR(lu_a_s),
        .DATA(lu_d_s)
    );

    assign ctrl_lu_a_s = {h_i[1:0], clk_5mhz_n_q, hx_i, 1'b1};

    prom_10_3 prom_C1 (
        .CLK (clk_20mhz_i),
        .ADDR(ctrl_lu_a_s),
        .DATA(ctrl_lu_d_s)
    );

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) ctrl_lu_q <= 6'd0;
        else          ctrl_lu_q <= ctrl_lu_q_d_s;
    end

    always_comb begin
        ctrl_lu_q_d_s = ctrl_lu_q;
        clk_en_eck_s  = 1'b0;
        clk_en_rd_s   = 1'b0;
        if (clk_en_10mhz_i) begin
            ctrl_lu_q_d_s = ctrl_lu_d_s[5:0];
            if (!ctrl_lu_q[1:1] && ctrl_lu_q_d_s[1:1]) clk_en_eck_s = 1'b1;
            if (!ctrl_lu_q[6:6] && ctrl_lu_q_d_s[6:6]) clk_en_rd_s  = 1'b1;
        end
    end

    assign shift_oc_n_s = ~(ctrl_lu_q[1:1] & res_n_i);
    assign ck_inh_s     = ctrl_lu_q[2:2];
    assign cr_mux_sel_s = ctrl_lu_q[3:3];
    assign vram_we_n_s  = ctrl_lu_q[4:4];
    assign rs_enable_s  = ctrl_lu_q[5:5];

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i)            ca_q <= 3'd0;
        else if (clk_en_7ck_n_s) ca_q <= c_s[8:6];
    end

    always_comb begin
        if (!cr_mux_sel_s)
            cr_s = {v_i[3:0], h_t_i[3:0], h_i[3:2]};
        else
            cr_s = {~v_i[3:3], ca_q[3:1], x_s[5:0]};
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            rd_shift_int <= 16'hFFFF;
            rs_int       <= 4'hF;
        end else if (clk_en_10mhz_i & ~ck_inh_s) begin
            rs_int       <= {~(qh1_s | qh2_s), rs_int[3:1]};
            rd_shift_int <= {lu_d_mux_s[0:0], rd_shift_int[15:13],
                             lu_d_mux_s[1:1], rd_shift_int[11:9],
                             lu_d_mux_s[2:2], rd_shift_int[7:5],
                             lu_d_mux_s[3:3], rd_shift_int[3:1]};
        end
    end

    assign rd_shift_s = (!shift_oc_n_s) ? rd_shift_int : 16'hFFFF;
    assign rs_s       = (!shift_oc_n_s) ? rs_int       : 4'hF;
    assign rs_n_s     = rs_s & {4{rs_enable_s}};

    spram #(10,4) vram_a6_b (
        .clock  (clk_20mhz_i),
        .enable (1'b1),
        .address(cr_s),
        .data   ({rd_shift_s[12:12], rd_shift_s[8:8], rd_shift_s[4:4], rd_shift_s[0:0]}),
        .wren   (~rs_n_s[0:0] & ~vram_we_n_s),
        .q      (vram_a6_out_s)
    );

    spram #(10,4)  vram_b6_b (
        .clock  (clk_20mhz_i),
        .enable (1'b1),
        .address(cr_s),
        .data   ({rd_shift_s[13:13], rd_shift_s[9:9], rd_shift_s[5:5], rd_shift_s[1:1]}),
        .wren   (~rs_n_s[1:1] & ~vram_we_n_s),
        .q      (vram_b6_out_s)
    );

    spram #(10,4)  vram_c6_b (
        .clock  (clk_20mhz_i),
        .enable (1'b1),
        .address(cr_s),
        .data   ({rd_shift_s[14:14], rd_shift_s[10:10], rd_shift_s[6:6], rd_shift_s[2:2]}),
        .wren   (~rs_n_s[2:2] & ~vram_we_n_s),
        .q      (vram_c6_out_s)
    );

    spram #(10,4)  vram_d6_b (
        .clock  (clk_20mhz_i),
        .enable (1'b1),
        .address(cr_s),
        .data   ({rd_shift_s[15:15], rd_shift_s[11:11], rd_shift_s[7:7], rd_shift_s[3:3]}),
        .wren   (~rs_n_s[3:3] & ~vram_we_n_s),
        .q      (vram_d6_out_s)
    );

    assign rd_vram_s = {
        vram_d6_out_s[3:3] | rs_n_s[3:3], vram_c6_out_s[3:3] | rs_n_s[2:2], vram_b6_out_s[3:3] | rs_n_s[1:1], vram_a6_out_s[3:3] | rs_n_s[0:0],
        vram_d6_out_s[2:2] | rs_n_s[3:3], vram_c6_out_s[2:2] | rs_n_s[2:2], vram_b6_out_s[2:2] | rs_n_s[1:1], vram_a6_out_s[2:2] | rs_n_s[0:0],
        vram_d6_out_s[1:1] | rs_n_s[3:3], vram_c6_out_s[1:1] | rs_n_s[2:2], vram_b6_out_s[1:1] | rs_n_s[1:1], vram_a6_out_s[1:1] | rs_n_s[0:0],
        vram_d6_out_s[0:0] | rs_n_s[3:3], vram_c6_out_s[0:0] | rs_n_s[2:2], vram_b6_out_s[0:0] | rs_n_s[1:1], vram_a6_out_s[0:0] | rs_n_s[0:0]};

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i)
            vram_q <= 16'h0000;
        else if (!blank_flont_i)
            vram_q <= 16'h0000;
        else if (clk_en_rd_s) begin
            if (!shift_oc_n_s) vram_q <= rd_shift_s;
            else               vram_q <= rd_vram_s;
        end
    end

    always_comb begin
        sig_o = 4'b0000;
        if (!blank_i) begin
            case (h_i[1:0])
                2'b00: sig_o = {vram_q[13:13], vram_q[9:9],  vram_q[5:5], vram_q[1:1]};
                2'b01: sig_o = {vram_q[14:14], vram_q[10:10], vram_q[6:6], vram_q[2:2]};
                2'b10: sig_o = {vram_q[15:15], vram_q[11:11], vram_q[7:7], vram_q[3:3]};
                2'b11: sig_o = {vram_q[12:12], vram_q[8:8],  vram_q[4:4], vram_q[0:0]};
            endcase
        end
    end

endmodule
