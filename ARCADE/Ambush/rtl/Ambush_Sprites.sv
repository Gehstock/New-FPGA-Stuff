module Ambush_Sprites (
    input  logic        clk_video,
    input  logic        cen_video,
    input  logic        reset,
    input  logic [8:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [1:0]  color_bank,
    output logic [6:0]  sprite_ram_addr,
    input  logic [7:0]  sprite_vram_q0,
    input  logic [7:0]  sprite_vram_q1,
    input  logic [7:0]  sprite_vram_q2,
    input  logic [7:0]  sprite_vram_q3,
    output logic [12:0] sprite_rom_addr,
    input  logic [7:0]  sprite_rom_data_b0,
    input  logic [7:0]  sprite_rom_data_b1,
    output logic [7:0]  sprite_color_idx
);

    localparam SPRITES_PER_LINE = 8;

    typedef enum logic [1:0] {
        IDLE,
        PRIME,
        SCAN
    } state_t;

    state_t state;

    logic [6:0] scan_idx;
    logic [3:0] build_count;
    logic build_bank;
    logic display_bank;
    logic scan_bank;
    logic [8:0] target_line;
    logic [7:0] line_sx [0:1][0:7];
    logic [7:0] line_attr1 [0:1][0:7];
    logic [7:0] line_attr2 [0:1][0:7];
    logic [3:0] line_y [0:1][0:7];
    logic line_size [0:1][0:7];
    logic line_active [0:1][0:7];
    logic [7:0] scan_top_y;
    logic [8:0] scan_y_diff;
    logic scan_v_hit;
    logic scan_valid;
    logic [2:0] render_select;
    logic render_hit;
    logic [7:0] render_sx, render_attr1, render_attr2;
    logic [3:0] render_y;
    logic render_size;
    logic [7:0] h_diff;
    logic [3:0] final_x, final_y;
    logic [7:0] raw_code;
    logic [1:0] pixel_bit;
    logic [1:0] color_bank_d1;
    logic [3:0] color_idx_d1;
    logic [2:0] final_x_d1;
    logic render_hit_d1;

    integer i, b, j;

    assign scan_top_y = sprite_vram_q2[7] ? (8'd240 - sprite_vram_q0) : (8'd248 - sprite_vram_q0);
    assign scan_y_diff = target_line - {1'b0, scan_top_y};
    assign scan_v_hit = sprite_vram_q2[7] ? (scan_y_diff < 9'd16) : (scan_y_diff < 9'd8);
    assign scan_valid = (sprite_vram_q0 != 8'h00) && (sprite_vram_q0 != 8'hff) && !((sprite_vram_q3 < 8'h40 && sprite_vram_q2[4]) || (sprite_vram_q3 >= 8'hc0 && !sprite_vram_q2[4]));

    always_ff @(posedge clk_video) begin
        if (reset) begin
            state <= IDLE;
            scan_idx <= 7'd0;
            build_count <= 4'd0;
            sprite_ram_addr <= 7'd0;
            build_bank <= 1'b0;
            display_bank <= 1'b0;
            scan_bank <= 1'b1;
            target_line <= 9'd0;
            for (b = 0; b < 2; b = b + 1) begin
                for (i = 0; i < 8; i = i + 1) begin
                    line_active[b][i] <= 1'b0;
                    line_sx[b][i] <= 8'd0;
                    line_attr1[b][i] <= 8'd0;
                    line_attr2[b][i] <= 8'd0;
                    line_y[b][i] <= 4'd0;
                    line_size[b][i] <= 1'b0;
                end
            end
        end else if (cen_video) begin
            case (state)
                IDLE: begin
                    if (h_cnt == 9'd0) begin
                        display_bank <= build_bank;
                        scan_bank <= ~build_bank;
                        build_bank <= ~build_bank;
                        build_count <= 4'd0;
                        scan_idx <= 7'd0;
                        sprite_ram_addr <= 7'd0;
                        if (v_cnt == 9'd263) target_line <= 9'd0;
                        else
                            target_line <= v_cnt + 9'd1;
                        for (i = 0; i < 8; i = i + 1)
                            line_active[~build_bank][i] <= 1'b0;
                        state <= PRIME;
                    end
                end
                PRIME: begin
                    sprite_ram_addr <= 7'd1;
                    state <= SCAN;
                end
                SCAN: begin
                    if (scan_valid && scan_v_hit &&
                        (build_count < 4'd8)) begin
                        line_sx[scan_bank][build_count[2:0]]
                            <= sprite_vram_q3;
                        line_attr1[scan_bank][build_count[2:0]]
                            <= sprite_vram_q1;
                        line_attr2[scan_bank][build_count[2:0]]
                            <= sprite_vram_q2;
                        line_y[scan_bank][build_count[2:0]]
                            <= scan_y_diff[3:0];
                        line_size[scan_bank][build_count[2:0]]
                            <= sprite_vram_q2[7];
                        line_active[scan_bank][build_count[2:0]]
                            <= 1'b1;
                        build_count <= build_count + 4'd1;
                    end
                    if (scan_idx == 7'd127) begin
                        state <= IDLE;
                    end else begin
                        scan_idx <= scan_idx + 7'd1;
                        if (scan_idx < 7'd126)
                            sprite_ram_addr <= scan_idx + 7'd2;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always_comb begin
        render_select = 3'd0;
        render_hit = 1'b0;
        for (j = 7; j >= 0; j = j - 1) begin
            if (line_active[display_bank][j] &&
                (h_cnt[7:0] >= line_sx[display_bank][j]) && ((h_cnt[7:0] - line_sx[display_bank][j]) < (line_size[display_bank][j] ?
                  8'd16 : 8'd8))) begin
                render_select = j[2:0];
                render_hit = 1'b1;
            end
        end
    end

    assign render_sx = line_sx[display_bank][render_select];
    assign render_attr1 = line_attr1[display_bank][render_select];
    assign render_attr2 = line_attr2[display_bank][render_select];
    assign render_y = line_y[display_bank][render_select];
    assign render_size = line_size[display_bank][render_select];
    assign h_diff = h_cnt[7:0] - render_sx;
    assign final_x = render_size ? (render_attr1[6] ? ~h_diff[3:0] : h_diff[3:0]) : {1'b0, (render_attr1[6] ? ~h_diff[2:0] : h_diff[2:0])};
    assign final_y = render_size ? (render_attr1[7] ? ~render_y : render_y) : {1'b0, (render_attr1[7] ? ~render_y[2:0] : render_y[2:0])};
    assign raw_code = {render_attr2[6:5], render_attr1[5:0]};

    always_comb begin
        sprite_rom_addr = 13'd0;
        if (render_hit) begin
            if (render_size) begin
                sprite_rom_addr = {raw_code, final_y[3], final_x[3], final_y[2:0]};
            end else begin
                sprite_rom_addr = {raw_code, 2'b00, final_y[2:0]};
            end
        end
    end

    always_ff @(posedge clk_video) begin
        if (reset) begin
            final_x_d1 <= 3'd0;
            color_bank_d1 <= 2'd0;
            color_idx_d1 <= 4'd0;
            render_hit_d1 <= 1'b0;
        end else begin
            final_x_d1 <= final_x[2:0];
            color_bank_d1 <= color_bank;
            color_idx_d1 <= render_attr2[3:0];
            render_hit_d1 <= render_hit;
        end
    end

    assign pixel_bit = {
        sprite_rom_data_b1[~final_x_d1],
        sprite_rom_data_b0[~final_x_d1]
    };

    always_comb begin
        if (render_hit_d1 && pixel_bit != 2'b00) begin
            sprite_color_idx = {color_bank_d1, color_idx_d1, pixel_bit};
        end else begin
            sprite_color_idx = 8'h00;
        end
    end

endmodule