module skyarmy_video (
    input  wire        clk_sys,
    input  wire        clk_pixel,
    input  wire        rst_n,
    input  wire        flip_x,
    input  wire        flip_y,
    input  wire [8:0]  h_cnt_in,
    input  wire [8:0]  v_cnt_in,
    input  wire [15:0] cpu_addr,
    input  wire [7:0]  cpu_data_in,
    input  wire        cpu_we,
    output wire [7:0]  vram_data_out,
    output wire [7:0]  cram_data_out,
    output wire [7:0]  sram_data_out,
    output wire [7:0]  scram_data_out,
    output reg  [3:0]  video_r,
    output reg  [3:0]  video_g,
    output reg  [3:0]  video_b
);

    wire video_on = (h_cnt_in >= 9'd2 && h_cnt_in < 9'd258 && v_cnt_in >= 9'd8 && v_cnt_in < 9'd248);
    wire [8:0] game_x = flip_x ? (9'd255 - h_cnt_in) : h_cnt_in;
    wire [7:0] game_y = flip_y ? (8'd255 - v_cnt_in[7:0]) : v_cnt_in[7:0];

    wire [4:0] current_col = game_x[7:3];
    wire [7:0] col_scroll_val;
    wire scram_cpu_sel = (cpu_addr >= 16'h9840 && cpu_addr <= 16'h985F);
    wire [8:0] next_h_cnt     = h_cnt_in + 9'd1;
    wire [8:0] next_game_x    = flip_x ? (9'd255 - next_h_cnt) : next_h_cnt;
    wire [4:0] scroll_rd_addr = next_game_x[7:3];
    
    dpram #(.address_width(5), .data_width(8)) u_scroll_ram (
        .clock_a   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (cpu_we && scram_cpu_sel),
        .address_a (cpu_addr[4:0]),
        .data_a    (cpu_data_in),
        .q_a       (scram_data_out),
        .clock_b   (clk_pixel),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (scroll_rd_addr),
        .data_b    (8'h00),
        .q_b       (col_scroll_val)
    );

    wire [7:0] scrolled_game_y = flip_y ? (game_y - col_scroll_val) : (game_y + col_scroll_val);
    wire [4:0] tile_row = scrolled_game_y[7:3];
    wire [9:0] vram_render_addr = {tile_row, current_col};

    wire [7:0] tile_code;
    wire vram_cpu_sel = (cpu_addr >= 16'h8800 && cpu_addr <= 16'h8FFF);
    
    dpram #(.address_width(10), .data_width(8)) u_video_ram (
        .clock_a   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (cpu_we && vram_cpu_sel),
        .address_a (cpu_addr[9:0]),
        .data_a    (cpu_data_in),
        .q_a       (vram_data_out),
        .clock_b   (clk_pixel),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vram_render_addr),
        .data_b    (8'h00),
        .q_b       (tile_code)
    );

    wire [7:0] tile_attr;
    wire cram_cpu_sel = (cpu_addr >= 16'h9000 && cpu_addr <= 16'h93FF);
    
    dpram #(.address_width(10), .data_width(8)) u_color_ram (
        .clock_a   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (cpu_we && cram_cpu_sel),
        .address_a (cpu_addr[9:0]),
        .data_a    (cpu_data_in),
        .q_a       (cram_data_out),
        .clock_b   (clk_pixel),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vram_render_addr),
        .data_b    (8'h00),
        .q_b       (tile_attr)
    );

    wire [2:0] bg_pal_code = {tile_attr[0], tile_attr[1], tile_attr[2]};
    wire [2:0] tile_pixel_x = game_x[2:0];
    wire [2:0] tile_pixel_y = scrolled_game_y[2:0];
    reg [2:0] tile_pixel_y_d1;
    always @(posedge clk_pixel) tile_pixel_y_d1 <= tile_pixel_y;
    wire [10:0] trom_base_addr = {tile_code[7:0], tile_pixel_y_d1[2:0]};
    wire [7:0] trom_data_p0;
    wire [7:0] trom_data_p1;
    gfx1_1 u_tile_rom_p0 (.clk(clk_pixel), .addr(trom_base_addr), .data(trom_data_p0));
    gfx1_2 u_tile_rom_p1 (.clk(clk_pixel), .addr(trom_base_addr), .data(trom_data_p1));
    
    reg [2:0] tile_pixel_x_d1, tile_pixel_x_d2;
    always @(posedge clk_pixel) begin
        tile_pixel_x_d1 <= tile_pixel_x;
        tile_pixel_x_d2 <= tile_pixel_x_d1;
    end

    wire [1:0] tile_rom_pixel = {trom_data_p0[3'd7 - tile_pixel_x_d2], trom_data_p1[3'd7 - tile_pixel_x_d2]};

    reg [7:0] sprite_reg [0:63];
    wire sram_cpu_sel = (cpu_addr >= 16'h9800 && cpu_addr <= 16'h983F);
    assign sram_data_out = sprite_reg[cpu_addr[5:0]];

    integer idx;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 64; idx = idx + 1) sprite_reg[idx] <= 8'h00;
        end else if (cpu_we && sram_cpu_sel) begin
            sprite_reg[cpu_addr[5:0]] <= cpu_data_in;
        end
    end

    reg        line_tgl;        // toggles once per line
    reg [7:0]  lb_build_gy;     // game_y of the line being built (= V+1)
    reg        lb_build_bank;   // bank the FSM should fill
    reg        h_was_zero;
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            line_tgl <= 1'b0; lb_build_gy <= 8'd0; lb_build_bank <= 1'b0;
            h_was_zero <= 1'b0;
        end else begin
            if (h_cnt_in == 9'd0 && !h_was_zero) begin
                line_tgl      <= ~line_tgl;
                lb_build_gy   <= flip_y ? (8'd255 - (v_cnt_in[7:0] + 8'd1))
                                        : (v_cnt_in[7:0] + 8'd1);
                lb_build_bank <= ~v_cnt_in[0];
                h_was_zero    <= 1'b1;
            end else if (h_cnt_in != 9'd0) begin
                h_was_zero <= 1'b0;
            end
        end
    end

    reg line_tgl_s1, line_tgl_s2, line_tgl_s3;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            line_tgl_s1 <= 1'b0; line_tgl_s2 <= 1'b0; line_tgl_s3 <= 1'b0;
        end else begin
            line_tgl_s1 <= line_tgl;
            line_tgl_s2 <= line_tgl_s1;
            line_tgl_s3 <= line_tgl_s2;
        end
    end
    wire build_start = (line_tgl_s2 ^ line_tgl_s3);

    localparam SB_IDLE = 3'd0, SB_FETCH = 3'd1, SB_ADDR = 3'd2,
               SB_WRITE = 3'd3, SB_NEXT = 3'd4;
    reg [2:0] sb_state;
    reg [3:0] sb_idx;       // sprite 0..15
    reg [4:0] sb_col;       // column 0..15 (5 bits to detect 16)
    reg [7:0] sb_gy;
    reg       sb_bank;
    reg [5:0] sb_code;
    reg [7:0] sb_sx;
    reg [2:0] sb_pal;
    reg       sb_flipx, sb_flipy;
    reg [3:0] sb_row;

    wire [3:0] sb_sx_col = sb_flipx ? (4'd15 - sb_col[3:0]) : sb_col[3:0];
    wire [10:0] srom_addr = (sb_code * 11'd32) +
                            {sb_row[3], sb_sx_col[3], sb_row[2:0]};

    wire [7:0] spr_rom_p0;  // gfx2_1 = plane0 (MSB)
    wire [7:0] spr_rom_p1;  // gfx2_2 = plane1 (LSB)
    gfx2_1 u_sprites_rom_0 (.clk(clk_sys), .addr(srom_addr), .data(spr_rom_p0));
    gfx2_2 u_sprites_rom_1 (.clk(clk_sys), .addr(srom_addr), .data(spr_rom_p1));

    wire [7:0] spr_y_byte    = sprite_reg[{sb_idx, 2'b00}];
    wire [7:0] spr_code_byte = sprite_reg[{sb_idx, 2'b01}];
    wire [7:0] spr_attr_byte = sprite_reg[{sb_idx, 2'b10}];
    wire [7:0] spr_x_byte    = sprite_reg[{sb_idx, 2'b11}];
    wire [7:0] spr_y_base    = 8'd239 - spr_y_byte;
    wire [7:0] spr_diff_y    = sb_gy - spr_y_base;
    wire       spr_on_line   = (spr_diff_y < 8'd16) &&
                               (spr_y_byte != 8'h00) && (spr_y_byte != 8'hFF);

    wire       sb_p0    = spr_rom_p0[3'd7 - sb_sx_col[2:0]];
    wire       sb_p1    = spr_rom_p1[3'd7 - sb_sx_col[2:0]];
    wire [1:0] sb_pen   = {sb_p0, sb_p1};               // {plane0,plane1}
    wire [8:0] sb_buf_x = {1'b0, sb_sx} + {5'd0, sb_col[3:0]};

    reg  [8:0] lb_wr_addr;
    reg  [4:0] lb_wr_data;
    reg        lb_wr_en;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sb_state <= SB_IDLE; sb_idx <= 4'd0; sb_col <= 5'd0;
            lb_wr_en <= 1'b0; lb_wr_addr <= 9'd0; lb_wr_data <= 5'd0;
        end else begin
            lb_wr_en <= 1'b0;                       // default: no write
            case (sb_state)
                SB_IDLE: if (build_start) begin
                            sb_gy    <= lb_build_gy;
                            sb_bank  <= lb_build_bank;
                            sb_idx   <= 4'd0;
                            sb_state <= SB_FETCH;
                         end
                SB_FETCH: if (spr_on_line) begin
                            sb_code  <= spr_code_byte[5:0];
                            sb_flipy <= spr_code_byte[7];
                            sb_flipx <= spr_code_byte[6];
                            sb_sx    <= spr_x_byte;
                            sb_pal   <= {spr_attr_byte[0], spr_attr_byte[1], spr_attr_byte[2]};
                            sb_row   <= spr_code_byte[7] ? (4'd15 - spr_diff_y[3:0])
                                                         : spr_diff_y[3:0];
                            sb_col   <= 5'd0;
                            sb_state <= SB_ADDR;
                          end else begin
                            sb_state <= SB_NEXT;
                          end
                SB_ADDR:  sb_state <= SB_WRITE;     // wait one cycle for ROM data
                SB_WRITE: begin
                            lb_wr_addr <= {sb_bank, sb_buf_x[7:0]};
                            lb_wr_data <= {sb_pal, sb_pen};
                            if (sb_pen != 2'b00 && !sb_buf_x[8])
                                lb_wr_en <= 1'b1;
                            if (sb_col == 5'd15) sb_state <= SB_NEXT;
                            else begin
                                sb_col   <= sb_col + 5'd1;
                                sb_state <= SB_ADDR;
                            end
                          end
                SB_NEXT:  if (sb_idx == 4'd15) sb_state <= SB_IDLE;
                          else begin
                            sb_idx   <= sb_idx + 4'd1;
                            sb_state <= SB_FETCH;
                          end
                default:  sb_state <= SB_IDLE;
            endcase
        end
    end

    wire [4:0] lb_q;
    dpram #(.address_width(9), .data_width(5)) u_sprite_linebuf (
        .clock_a   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (lb_wr_en),
        .address_a (lb_wr_addr),
        .data_a    (lb_wr_data),
        .q_a       (),
        .clock_b   (clk_pixel),
        .enable_b  (1'b1),
        .wren_b    (1'b1),                 // erase-after-read (read old, write 0)
        .address_b ({v_cnt_in[0], game_x[7:0]}),
        .data_b    (5'd0),
        .q_b       (lb_q)
    );

    reg [4:0] lb_pix_d1, lb_pix_d2, lb_pix_d3;
    always @(posedge clk_pixel) begin
        lb_pix_d1 <= lb_q;
        lb_pix_d2 <= lb_pix_d1;
        lb_pix_d3 <= lb_pix_d2;
    end
    wire [2:0] spr_pal_disp = lb_pix_d3[4:2];
    wire [1:0] spr_pen_disp = lb_pix_d3[1:0];
    wire       spr_active   = (spr_pen_disp != 2'b00);

    reg        video_on_pipe1, video_on_pipe2, video_on_pipe3;
    reg [2:0]  bg_pal_code_pipe1, bg_pal_code_pipe2, bg_pal_code_pipe3;
    reg [1:0]  tile_rom_pixel_pipe1, tile_rom_pixel_pipe2;
    always @(posedge clk_pixel) begin
        video_on_pipe1       <= video_on;
        video_on_pipe2       <= video_on_pipe1;
        video_on_pipe3       <= video_on_pipe2;
        bg_pal_code_pipe1    <= bg_pal_code;
        bg_pal_code_pipe2    <= bg_pal_code_pipe1;
        bg_pal_code_pipe3    <= bg_pal_code_pipe2;
        tile_rom_pixel_pipe1 <= tile_rom_pixel;
        tile_rom_pixel_pipe2 <= tile_rom_pixel_pipe1;
    end

    wire [4:0] prom_palette_addr;
    wire [7:0] color_prom_data;

    u_color_prom u_color_prom (
        .clk  (clk_pixel),
        .addr (prom_palette_addr),
        .data (color_prom_data)
    );

    assign prom_palette_addr = spr_active ? {spr_pal_disp, spr_pen_disp}
                                          : {bg_pal_code_pipe3, tile_rom_pixel_pipe2};

    wire [2:0] prom_r = color_prom_data[2:0];
    wire [2:0] prom_g = color_prom_data[5:3];
    wire [1:0] prom_b = color_prom_data[7:6];

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            video_r <= 4'h0; video_g <= 4'h0; video_b <= 4'h0;
        end else begin
            if (!video_on_pipe3) begin
                video_r <= 4'h0; video_g <= 4'h0; video_b <= 4'h0;
            end else begin
                video_r <= {prom_r, 1'b0};
                video_g <= {prom_g, 1'b0};
                video_b <= {prom_b, 2'b00};
            end
        end
    end
endmodule