module sraider_bg (
    input  logic       clk_sys,
    input  logic       clk_vid_en,
    input  logic       rst_n,
    input  logic [3:0] h_i,
    input  logic [3:0] h_t_i,
    input  logic       hx_i,
    input  logic [3:0] v_i,
    input  logic [3:0] v_t_i,
    input  logic       hblank_i,
    input  logic       vblank_i,
    input  logic       flip_screen_i,
    input  logic       stars_enable_i,
    input  logic [2:0] stars_speed_i,
    input  logic [7:0] grid_color_reg_i,
    input  logic       grid_ram_we_i,
    input  logic [7:0] grid_ram_addr_i,
    input  logic [7:0] cpu_grid_data_i,
    output logic       star_pixel_en_o,
    output logic [1:0] star_rgb_r_o,
    output logic [1:0] star_rgb_g_o,
    output logic [1:0] star_rgb_b_o,
    output logic       grid_tile_pixel_o,
    output logic       grid_line_en_o,
    output logic [1:0] tile_grid_rgb_r_o,
    output logic [1:0] tile_grid_rgb_g_o,
    output logic [1:0] tile_grid_rgb_b_o
);

    localparam logic [15:0] POS_START = 16'h2000 - 16'd9;

    logic [16:0] m_state, n_state, work, cur;
    logic [15:0] pos, m_offset, n_offset, steps, i_work, cur_i;
    logic [11:0] rom_grid_a_o;
    logic [9:0]  mame_tile_index;
    logic [8:0]  x_plus_8, grid_tile_code;
    logic [7:0]  x_beam, y_beam, xloc, lookahead_h_tile, lookahead_v_tile, rom_grid_d_i, next_x, grid_rdx;
    logic [4:0]  star_color, sraider_col, sraider_row, sub_row;
    logic [2:0]  grid_pixel_y;
    logic        stars_en_d, m_count, n_count, prep_done, running, y_vis, trig, start;
    logic        fb_cur, hcond, vcond, in_win, grid_line_read_reg;

    (* ramstyle = "no_rw_check" *) logic grid_data_ram [0:255];

    function automatic logic [16:0] lfsr_step(input logic [16:0] s);
        logic tempbit, fb;
        tempbit = ~s[16];
        fb      = s[5] ? ~tempbit : tempbit;
        return {s[15:0], fb};
    endfunction

    assign x_beam = {h_t_i, h_i};
    assign y_beam = {v_t_i, v_i};
    assign pos    = {y_beam, x_beam} - 16'd9;
    assign xloc   = pos[7:0];
    assign y_vis  = (y_beam >= 8'h20) && (y_beam <= 8'he0);
    assign trig   = vblank_i && (y_beam == 8'he8);
    assign start  = (y_beam == 8'h20) && (x_beam == 8'h00) && !hx_i;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            stars_en_d <= 1'b0;
            m_count    <= 1'b0;
            m_offset   <= 16'h0000;
            m_state    <= 17'h00000;
            n_count    <= 1'b0;
            n_offset   <= 16'h0000;
            n_state    <= 17'h00000;
            work       <= 17'h00000;
            steps      <= 16'h0000;
            i_work     <= 16'h0000;
            prep_done  <= 1'b0;
            cur        <= 17'h00000;
            cur_i      <= 16'h0000;
            running    <= 1'b0;
        end else begin
            stars_en_d <= stars_enable_i;

            if (trig && !prep_done) begin
                prep_done <= 1'b1;
                if (stars_enable_i) begin
                    n_count <= ~m_count;
                    if (m_count) begin
                        n_offset <= m_offset + {12'd0, stars_speed_i, 1'b0} - 16'd9;
                        n_state  <= 17'h00000;
                        work     <= 17'h00000;
                        steps    <= POS_START - (m_offset + {12'd0, stars_speed_i, 1'b0} - 16'd9);
                        i_work   <= 16'h0000;
                    end else begin
                        n_offset <= m_offset;
                        n_state  <= 17'h1fc71;
                        work     <= 17'h1fc71;
                        steps    <= POS_START - m_offset;
                        i_work   <= 16'h0000;
                    end
                end else begin
                    n_count  <= m_count;
                    n_offset <= m_offset;
                    n_state  <= m_state;
                    work     <= m_state;
                    steps    <= POS_START - m_offset;
                    i_work   <= 16'h0000;
                end
            end else if (steps >= 16'd2) begin
                work   <= lfsr_step(lfsr_step(work));
                steps  <= steps - 16'd2;
                i_work <= i_work + 16'd2;
            end else if (steps == 16'd1) begin
                work   <= lfsr_step(work);
                steps  <= 16'd0;
                i_work <= i_work + 16'd1;
            end

            if (clk_vid_en && start) begin
                prep_done <= 1'b0;
                m_count   <= n_count;
                m_offset  <= n_offset;
                m_state   <= n_state;
                cur       <= (i_work == 16'hffff) ? n_state : lfsr_step(work);
                cur_i     <= i_work + 16'd1;
                running   <= 1'b1;
            end else if (clk_vid_en && running && !hx_i) begin
                cur_i <= cur_i + 16'd1;
                if (cur_i == 16'hffff) cur <= m_state;
                else                   cur <= lfsr_step(cur);
                if (y_beam == 8'he1) running <= 1'b0;
            end

            if (stars_enable_i && !stars_en_d) begin
                m_offset <= 16'h0000;
                n_offset <= 16'h0000;
            end
        end
    end

    assign fb_cur     = cur[5] ? cur[16] : ~cur[16];
    assign x_plus_8   = {1'b0, xloc} + 9'd8;
    assign hcond      = x_plus_8[4];
    assign vcond      = 1'b1;
    assign in_win     = flip_screen_i ? (xloc >= 8'h27) : (xloc <= 8'hd8);
    assign star_color = cur[13:9];

    always_comb begin
        star_pixel_en_o = 1'b0;
        star_rgb_r_o    = 2'b00;
        star_rgb_g_o    = 2'b00;
        star_rgb_b_o    = 2'b00;
        if (stars_enable_i && running && !hx_i && !hblank_i && !vblank_i && y_vis && in_win && (hcond == vcond) &&
            (cur[7:0] == 8'hff) && !fb_cur) begin
            star_pixel_en_o = 1'b1;
            star_rgb_r_o    = {1'b0, star_color[0]};
            star_rgb_g_o    = {star_color[2], star_color[1]};
            star_rgb_b_o    = {star_color[4], star_color[3]};
        end
    end

    assign lookahead_h_tile  = {h_t_i, h_i};
    assign lookahead_v_tile  = {v_t_i, v_i};
    assign sraider_col       = lookahead_h_tile[7:3];
    assign sraider_row       = lookahead_v_tile[7:3];
    assign mame_tile_index   = {sraider_row, sraider_col};
    assign sub_row           = 5'd31 - sraider_row;
    assign rom_grid_a_o      = {grid_tile_code[8:0], grid_pixel_y[2:0]};
    assign grid_tile_pixel_o = rom_grid_d_i[h_i[2:0]];

    always_comb begin
        if (mame_tile_index < 11'd512) begin
            grid_tile_code = mame_tile_index[8:0];
            grid_pixel_y   = lookahead_v_tile[2:0];
        end else begin
            grid_tile_code = {sub_row[3:0], sraider_col};
            grid_pixel_y   = 3'd7 - lookahead_v_tile[2:0];
        end
    end

    sraider_grid_rom grid_rom (
        .addr(rom_grid_a_o),
        .clk(clk_sys),
        .data(rom_grid_d_i)
    );

    always_ff @(posedge clk_sys) begin
        if (grid_ram_we_i)
            grid_data_ram[grid_ram_addr_i] <= |cpu_grid_data_i;
    end

    assign next_x   = x_beam - 8'd8;
    assign grid_rdx = flip_screen_i ? ~next_x : next_x;

    always_ff @(posedge clk_sys) begin
        if (clk_vid_en)
            grid_line_read_reg <= grid_data_ram[grid_rdx];
    end

    always_comb begin
        grid_line_en_o = 1'b0;
        if (!hblank_i && !vblank_i)
            grid_line_en_o = grid_line_read_reg;
    end

    assign tile_grid_rgb_r_o = grid_color_reg_i[6] ? 2'b11 : 2'b00;
    assign tile_grid_rgb_g_o = grid_color_reg_i[5] ? 2'b11 : 2'b00;
    assign tile_grid_rgb_b_o = grid_color_reg_i[4] ? 2'b11 : 2'b00;

endmodule
