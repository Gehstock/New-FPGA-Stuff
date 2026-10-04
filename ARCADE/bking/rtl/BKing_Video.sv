module BKing_Video (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  scroll_x,
    input  logic [7:0]  scroll_y,
    input  logic [1:0]  palette_bank,
    input  logic        flip_screen,
    output logic [10:0] playfield_addr,
    input  logic [7:0]  playfield_q,
    input  logic [7:0]  ball1_x,
    input  logic [7:0]  ball1_y,
    input  logic [2:0]  ball1_pic,
    input  logic [7:0]  ball2_x,
    input  logic [7:0]  ball2_y,
    input  logic [2:0]  ball2_pic,
    input  logic [7:0]  crow_x,
    input  logic [7:0]  crow_y,
    input  logic [3:0]  crow_pic,
    input  logic        crow_flip,
    input  logic [1:0]  hit_mode,
    input  logic        hit_clear,
    input  logic [2:0]  pc3259_mask,
    output logic [15:0] collision_latch,
    output logic        main_int_n,
    output logic [5:0]  Video_R,
    output logic [5:0]  Video_G,
    output logic [5:0]  Video_B,
    output logic        Video_HS,
    output logic        Video_VS,
    output logic        Video_HB,
    output logic        Video_VB
);

    logic       clk_pix;
    logic [8:0] h_cnt;
    logic [8:0] v_cnt;
    logic       sync_blank;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_pix <= 1'b0;
        else        clk_pix <= !clk_pix;
    end

    always_ff @(posedge clk) begin
        if (clk_pix) begin
            if (h_cnt == 9'd383) h_cnt <= 9'd0;
            else                h_cnt <= h_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (clk_pix && (h_cnt == 9'd383)) begin
            if (v_cnt == 9'd261) v_cnt <= 9'd0;
            else                v_cnt <= v_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (clk_pix) begin
            Video_HS    <= !(h_cnt >= 9'd272 && h_cnt < 9'd304);
            Video_VS    <= !(v_cnt >= 9'd240 && v_cnt < 9'd244);
            Video_HB    <= (h_cnt >= 9'd256);
            Video_VB    <= (v_cnt >= 9'd224);
            sync_blank  <= (h_cnt >= 9'd256) || (v_cnt >= 9'd224);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_int_n <= 1'b1;
        end else if (clk_pix) begin
            if (v_cnt == 9'd224 && h_cnt == 9'd0) main_int_n <= 1'b0;
            else if (v_cnt == 9'd226)             main_int_n <= 1'b1;
        end
    end

    logic [8:0] x_pos;
    logic [8:0] y_pos;
    assign x_pos = flip_screen ? h_cnt : (9'd255 - h_cnt);
    assign y_pos = flip_screen ? (9'd223 - (v_cnt - 9'd16)) : (v_cnt + 9'd16);

    logic [2:0] tile_color;
    logic [1:0] tile_palette;

    BKing_Tiles tiles_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .scroll_x(scroll_x),
        .scroll_y(scroll_y),
        .palette_bank(palette_bank),
        .flip_screen(flip_screen),
        .playfield_addr(playfield_addr),
        .playfield_q(playfield_q),
        .pixel_color(tile_color),
        .pixel_palette(tile_palette)
    );

    logic        ball1_active;
    logic        ball1_pixel;
    logic        ball2_active;
    logic        ball2_pixel;
    logic        crow_active;
    logic [1:0]  crow_pixel;

    BKing_Sprites sprites_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .ball1_x(ball1_x),
        .ball1_y(ball1_y),
        .ball1_pic(ball1_pic),
        .ball2_x(ball2_x),
        .ball2_y(ball2_y),
        .ball2_pic(ball2_pic),
        .crow_x(crow_x),
        .crow_y(crow_y),
        .crow_pic(crow_pic),
        .crow_flip(crow_flip),
        .ball1_active(ball1_active),
        .ball1_pixel(ball1_pixel),
        .ball2_active(ball2_active),
        .ball2_pixel(ball2_pixel),
        .crow_active(crow_active),
        .crow_pixel(crow_pixel)
    );

    logic [8:0] prom_hardware_addr;
    logic       ball1_eff_pixel;
    logic       ball2_eff_pixel;

    assign ball1_eff_pixel = ball1_active && ball1_pixel;
    assign ball2_eff_pixel = ball2_active && ball2_pixel;

    logic [7:0] palette_prom_q;

    prom_col palette_prom_inst (
        .clk(clk),
        .addr(prom_hardware_addr),
        .data(palette_prom_q)
    );

    logic sync_blank_d1, sync_blank_d2, sync_blank_d3;
    always_ff @(posedge clk) begin
        sync_blank_d1 <= sync_blank;
        sync_blank_d2 <= sync_blank_d1;
        sync_blank_d3 <= sync_blank_d2;
    end

    logic ball1_visible;
    logic ball2_visible;
    logic crow_visible;

    always_comb begin
        ball1_visible = ball1_eff_pixel;
        ball2_visible = ball2_eff_pixel;
        crow_visible  = crow_active && (crow_pixel != 2'b00);

        prom_hardware_addr[0]   = tile_color[2];
        prom_hardware_addr[1]   = tile_color[1];
        prom_hardware_addr[2]   = tile_color[0];
        prom_hardware_addr[3]   = ball1_visible;
        prom_hardware_addr[4]   = ball2_visible;
        prom_hardware_addr[5]   = crow_visible ? crow_pixel[0] : 1'b0;
        prom_hardware_addr[6]   = crow_visible ? crow_pixel[1] : 1'b0;
        prom_hardware_addr[8:7] = palette_bank;
    end



    always_comb begin
        if (sync_blank_d3) begin
            Video_R = 6'b000000;
            Video_G = 6'b000000;
            Video_B = 6'b000000;
        end else begin
            Video_R[5] = palette_prom_q[0];
            Video_R[4] = palette_prom_q[1];
            Video_R[3] = palette_prom_q[2];
            Video_R[2:0] = 3'b000;

            Video_G[5] = palette_prom_q[3];
            Video_G[4] = palette_prom_q[4];
            Video_G[3] = palette_prom_q[5];
            Video_G[2:0] = 3'b000;

            Video_B[5] = palette_prom_q[6];
            Video_B[4] = palette_prom_q[7];
            Video_B[3:0] = 4'b0000;
        end
    end



    logic [4:0] col_prom_addr;
    assign col_prom_addr = {hit_mode, tile_color};

    logic [3:0] col_prom_q;

    prom_coll_detect collision_prom_inst (
        .clk(clk),
        .addr(col_prom_addr),
        .data(col_prom_q)
    );

    logic col_bg_match, col_ball_match;
    
    assign col_bg_match   = (col_prom_q != 4'h00);
    assign col_ball_match = ball1_eff_pixel || ball2_eff_pixel;

    logic [15:0] internal_latch;
    logic        hit_occured;

    logic [8:0] x_pos_d1, x_pos_d2;
    logic [8:0] y_pos_d1, y_pos_d2;

    always_ff @(posedge clk) begin
        x_pos_d1      <= x_pos;
        x_pos_d2      <= x_pos_d1;
        y_pos_d1      <= y_pos;
        y_pos_d2      <= y_pos_d1;
    end

    logic mask_enabled;
    assign mask_enabled = (pc3259_mask == 3'd6) || (pc3259_mask == 3'd3);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_latch <= 16'h0000;
            hit_occured    <= 1'b0;
        end else if (hit_clear) begin
            internal_latch <= 16'h0000;
            hit_occured    <= 1'b0;
        end else if (!hit_occured && col_bg_match && col_ball_match && !sync_blank_d1 && mask_enabled) begin
            hit_occured    <= 1'b1;
            internal_latch[4:0]   <= flip_screen ? (5'd31 - x_pos_d2[7:3]) : x_pos_d2[7:3];
            internal_latch[9:5]   <= flip_screen ? (5'd31 - y_pos_d2[7:3]) : y_pos_d2[7:3];
            internal_latch[11:10] <= (pc3259_mask == 3'd6) ? 2'b11 : 2'b01;
            internal_latch[15:12] <= 4'h0;
        end
    end

    assign collision_latch = internal_latch;

endmodule


