module sraider_video (
    input  logic        clk_20mhz_i,
    input  logic        por_n_i,
    input  logic        res_n_i,
    input  logic        clk_en_10mhz_i,
    input  logic        clk_en_10mhz_n_i,
    input  logic        clk_en_5mhz_i,
    input  logic        clk_en_5mhz_n_i,
    input  logic        clk_en_4mhz_i,
    input  logic        cs7_n_i,
    input  logic        cs10_n_i,
    input  logic        cs13_n_i,
    input  logic [10:0] a_i,
    input  logic        rd_n_i,
    input  logic        wr_n_i,
    output logic        wait_n_o,
    input  logic [7:0]  d_from_cpu_i,
    output logic [7:0]  d_from_video_o,
    output logic        vc_o,
    output logic        vbl_tick_n_o,
    output logic        vbl_buf_o,
    input  logic        stars_enable_i,
    input  logic [2:0]  stars_speed_i,
    input  logic [7:0]  grid_color_reg_i,
    input  logic        grid_ram_we_i,
    input  logic [7:0]  grid_ram_addr_i,
    input  logic [7:0]  cpu2_data_i,
    input  logic        flip_screen_signal,
    output logic [1:0]  rgb_r_o,
    output logic [1:0]  rgb_g_o,
    output logic [1:0]  rgb_b_o,
    output logic        hsync_n_o,
    output logic        vsync_n_o,
    output logic        comp_sync_n_o,
    output logic        vblank_o,
    output logic        hblank_o
);

    logic [7:0] h_cnt_q, h_cnt_s, h_preset, h_rise, h_do, v_cnt_q, v_cnt_s, v_preset, v_rise, v_do;
    logic [7:0] d_from_char_s, rgb_s, rgb_n_q;
    logic [5:1] crg_s;
    logic [4:1] sig_s;
    logic [4:0] a_s;
    logic [3:0] h_s, h_t_s, v_s, v_t_s;
    logic [1:0] orig_rgb_r, orig_rgb_g, orig_rgb_b, star_rgb_r, star_rgb_g, star_rgb_b;
    logic [1:0] tile_grid_rgb_r, tile_grid_rgb_g, tile_grid_rgb_b;
    logic       h_carry_s, v_carry_s, hx_n_s, hd_rise_s, vx_n_s, vbl_n_s, vbl_t_n_s, vc_rise_s, vd_rise_s, vb_t_rise_s;
    logic       hx_q, hx_s, vx_q, hx_rise_s, hbl_q, hsync_n_q, vbl_q, vbl_s, vbl_t_q, vbl_t_s, vsync_n_q, preset_v;
    logic       ha_d_s, ha_t_rise_s, hbl_s, hx_s_out, vc_d_s, vbl_d_n_s, sig_and_v;
    logic       blank_flont_s, blank_s, comp_sync_n, star_pixel_en, grid_tile_pixel, grid_line_en, background_is_black;

    assign h_carry_s = (h_cnt_q == 8'hFF);
    assign h_cnt_s   = (clk_en_5mhz_i) ? (h_carry_s ? h_preset : h_cnt_q + 1'b1) : h_cnt_q;
    assign h_rise    = h_cnt_s & ~h_cnt_q;
    assign h_do      = h_cnt_s;

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            h_cnt_q <= 8'h00;
        end else begin
            h_cnt_q <= h_cnt_s;
        end
    end

    assign hd_rise_s   = h_rise[3:3];
    assign ha_t_rise_s = h_rise[4:4];
    assign ha_d_s      = h_do[0:0];
    assign hx_n_s      = ~hx_q;
    assign h_preset    = {hx_n_s, hx_n_s, 2'b00, hx_n_s, 3'b000};

    always_comb begin
        hx_s      = hx_q;
        hx_rise_s = 1'b0;
        if (clk_en_5mhz_i == 1'b1) begin
            if (h_carry_s == 1'b1) begin
                hx_s = ~hx_q;
                if (hx_q == 1'b0) begin
                    hx_rise_s = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            hx_q      <= 1'b0;
            hbl_q     <= 1'b0;
            hsync_n_q <= 1'b1;
        end else begin
            hx_q <= hx_s;
            if ((hx_q && !h_cnt_q[3:3]) == 1'b1) begin
                hbl_q <= 1'b1;
            end else if (hd_rise_s == 1'b1) begin
                hbl_q <= hx_q;
            end
            if (hx_q == 1'b0) begin
                hsync_n_q <= 1'b1;
            end else if (hd_rise_s == 1'b1) begin
                hsync_n_q <= h_cnt_q[5:5];
            end
        end
    end

    assign v_carry_s = (v_cnt_q == 8'hFF);
    assign v_cnt_s   = (hx_rise_s) ? (v_carry_s ? v_preset : v_cnt_q + 1'b1) : v_cnt_q;
    assign v_rise    = v_cnt_s & ~v_cnt_q;
    assign v_do      = v_cnt_s;

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (!por_n_i) begin
            v_cnt_q <= 8'h00;
        end else begin
            v_cnt_q <= v_cnt_s;
        end
    end

    assign vb_t_rise_s = v_rise[5:5];
    assign vd_rise_s   = v_rise[3:3];
    assign vc_rise_s   = v_rise[2:2];
    assign vc_d_s      = v_do[2:2];
    assign vx_n_s      = ~vx_q;
    assign v_preset    = {vx_n_s, vx_n_s, vx_n_s, vx_q, vx_n_s, 1'b0, vx_n_s, 1'b0};

    always_comb begin
        preset_v = (v_cnt_q[5:5] && v_cnt_q[6:6] && v_cnt_q[7:7]) == 1'b1;
        vbl_s = vbl_q;
        if (preset_v) begin
            vbl_s = 1'b1;
        end else if (vb_t_rise_s == 1'b1) begin
            vbl_s = vx_q;
        end
        vbl_t_s = vbl_t_q;
        if (preset_v) begin
            vbl_t_s = 1'b1;
        end else if (vd_rise_s == 1'b1) begin
            vbl_t_s = vx_q;
        end
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            vx_q      <= 1'b0;
            vbl_q     <= 1'b0;
            vsync_n_q <= 1'b1;
            vbl_t_q   <= 1'b0;
        end else begin
            if (hx_rise_s == 1'b1) begin
                if (v_carry_s == 1'b1) begin
                    vx_q <= vx_n_s;
                end
            end
            if (vc_rise_s == 1'b1) begin
                vsync_n_q <= !(v_cnt_q[7:7] && v_cnt_q[6:6] && v_cnt_q[5:5] && v_cnt_q[4:4] && v_cnt_q[3:3] && vx_n_s);
            end
            vbl_q   <= vbl_s;
            vbl_t_q <= vbl_t_s;
        end
    end

    assign vbl_n_s             = ~vbl_q;
    assign vbl_t_n_s           = ~vbl_t_q;
    assign h_s                 = h_cnt_q[3:0];
    assign h_t_s               = h_cnt_q[7:4];
    assign hbl_s               = hbl_q;
    assign hx_s_out            = hx_q;
    assign v_s                 = v_cnt_q[3:0];
    assign v_t_s               = v_cnt_q[7:4];
    assign vbl_tick_n_o        = vbl_t_n_s;
    assign vbl_d_n_s           = ~vbl_s;
    assign hsync_n_o           = hsync_n_q;
    assign vsync_n_o           = vsync_n_q;
    assign comp_sync_n         = ~(hsync_n_q ^ vsync_n_q);
    assign blank_flont_s       = vbl_n_s;
    assign comp_sync_n_o       = comp_sync_n & vbl_n_s;
    assign vbl_buf_o           = ~vbl_n_s;
    assign vc_o                = v_s[2:2];
    assign d_from_video_o      = (cs13_n_i == 1'b0) ? d_from_char_s : 8'hFF;
    assign background_is_black = (orig_rgb_r == 2'b00 && orig_rgb_g == 2'b00 && orig_rgb_b == 2'b00);

    sraider_char char (
        .clk_20mhz_i(clk_20mhz_i),
        .por_n_i(por_n_i),
        .res_n_i(res_n_i),
        .clk_en_5mhz_i(clk_en_5mhz_i),
        .clk_en_4mhz_i(clk_en_4mhz_i),
        .cs10_n_i(cs10_n_i),
        .cs13_n_i(cs13_n_i),
        .a_i(a_i),
        .rd_n_i(rd_n_i),
        .wr_n_i(wr_n_i),
        .wait_n_o(wait_n_o),
        .d_from_cpu_i(d_from_cpu_i),
        .d_from_char_o(d_from_char_s),
        .h_i(h_s),
        .h_t_i(h_t_s),
        .ha_t_rise_i(ha_t_rise_s),
        .hx_i(hx_s_out),
        .v_i(v_s),
        .v_t_i(v_t_s),
        .hbl_i(hbl_s),
        .blank_flont_i(blank_flont_s),
        .blank_o(blank_s),
        .vblank_o(vblank_o),
        .hblank_o(hblank_o),
        .crg_o(crg_s)
    );

    sraider_sprite sprite (
        .clk_20mhz_i(clk_20mhz_i),
        .por_n_i(por_n_i),
        .res_n_i(res_n_i),
        .clk_en_10mhz_i(clk_en_10mhz_i),
        .clk_en_10mhz_n_i(clk_en_10mhz_n_i),
        .clk_en_5mhz_i(clk_en_5mhz_i),
        .clk_en_5mhz_n_i(clk_en_5mhz_n_i),
        .cs7_n_i(cs7_n_i),
        .a_i(a_i[9:0]),
        .d_from_cpu_i(d_from_cpu_i),
        .h_i(h_s),
        .h_t_i(h_t_s),
        .hx_i(hx_s_out),
        .ha_d_i(ha_d_s),
        .v_i(v_s),
        .v_t_i(v_t_s),
        .vbl_n_i(vbl_n_s),
        .vbl_d_n_i(vbl_d_n_s),
        .vc_d_i(vc_d_s),
        .blank_flont_i(blank_flont_s),
        .blank_i(blank_s),
        .sig_o(sig_s)
    );

    always_comb begin
        sig_and_v = sig_s[1:1] & sig_s[2:2] & sig_s[3:3] & sig_s[4:4];
        a_s[4:4]  = crg_s[1:1] & sig_and_v;
        if (sig_and_v && (crg_s[1:1] || crg_s[2:2])) begin
            a_s[3:0] = {crg_s[2:2], crg_s[5:5], crg_s[4:4], crg_s[3:3]};
        end else begin
            a_s[3:0] = sig_s;
        end
    end

    prom_10_2 rgb_prom (
        .CLK(clk_20mhz_i),
        .ADDR({5'b00000, a_s}),
        .DATA(rgb_s)
    );

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            rgb_n_q <= 8'hFF;
        end else begin
            if (clk_en_5mhz_i == 1'b1) begin
                rgb_n_q <= ~rgb_s;
            end
        end
    end

    assign orig_rgb_r = {rgb_n_q[0:0], rgb_n_q[3:3]};
    assign orig_rgb_g = {rgb_n_q[4:4], rgb_n_q[5:5]};
    assign orig_rgb_b = {rgb_n_q[6:6], rgb_n_q[7:7]};

    sraider_bg background (
        .clk_sys(clk_20mhz_i),
        .clk_vid_en(clk_en_5mhz_i),
        .rst_n(por_n_i),
        .h_i(h_s),
        .h_t_i(h_t_s),
        .hx_i(hx_s_out),
        .v_i(v_s),
        .v_t_i(v_t_s),
        .hblank_i(hblank_o),
        .vblank_i(vblank_o),
        .flip_screen_i(flip_screen_signal),
        .stars_enable_i(stars_enable_i),
        .stars_speed_i(stars_speed_i),
        .grid_color_reg_i(grid_color_reg_i),
        .grid_ram_we_i(grid_ram_we_i),
        .grid_ram_addr_i(grid_ram_addr_i),
        .cpu_grid_data_i(cpu2_data_i),
        .star_pixel_en_o(star_pixel_en),
        .star_rgb_r_o(star_rgb_r),
        .star_rgb_g_o(star_rgb_g),
        .star_rgb_b_o(star_rgb_b),
        .grid_tile_pixel_o(grid_tile_pixel),
        .grid_line_en_o(grid_line_en),
        .tile_grid_rgb_r_o(tile_grid_rgb_r),
        .tile_grid_rgb_g_o(tile_grid_rgb_g),
        .tile_grid_rgb_b_o(tile_grid_rgb_b)
    );

    always_ff @(posedge clk_20mhz_i) begin
        rgb_r_o <= orig_rgb_r;
        rgb_g_o <= orig_rgb_g;
        rgb_b_o <= orig_rgb_b;
        if (background_is_black && !hblank_o && !vblank_o) begin
            if (grid_tile_pixel == 1'b1) begin
                rgb_r_o <= tile_grid_rgb_r;
                rgb_g_o <= tile_grid_rgb_g;
                rgb_b_o <= tile_grid_rgb_b;
            end else if (grid_line_en == 1'b1) begin
                rgb_r_o <= tile_grid_rgb_r;
                rgb_g_o <= tile_grid_rgb_g;
                rgb_b_o <= tile_grid_rgb_b;
            end else if (star_pixel_en == 1'b1) begin
                rgb_r_o <= star_rgb_r;
                rgb_g_o <= star_rgb_g;
                rgb_b_o <= star_rgb_b;
            end else begin
                rgb_r_o <= 2'b00;
                rgb_g_o <= 2'b00;
                rgb_b_o <= 2'b00;
            end
        end
    end

endmodule
