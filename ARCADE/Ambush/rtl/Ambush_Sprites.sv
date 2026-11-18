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

    logic [6:0] linebuf [0:1][0:255];
    logic       buf_sel;

    typedef enum logic [2:0] {
        S_IDLE,
        S_CLEAR,
        S_FETCH_RAM,
        S_WAIT_RAM,
        S_CHECK_SPRITE,
        S_FETCH_ROM,
        S_WAIT_ROM,
        S_DRAW_PIXEL
    } state_t;

    state_t state;

    logic [7:0] clr_x;
    logic [6:0] spr_idx;
    logic [8:0] target_y;
    logic [7:0] sy, attr1, attr2, sx;
    logic       is_16x16, flip_y, flip_x, wrap;
    logic [7:0] code;
    logic [3:0] pal;
    logic [7:0] top_y;
    logic [8:0] y_diff;
    logic [3:0] pix_x;
    logic [3:0] final_x, final_y;
    logic [8:0] draw_x;
    logic [1:0] rom_pix;

    assign is_16x16 = attr2[7];
    assign flip_y   = attr1[7];
    assign flip_x   = attr1[6];
    assign wrap     = attr2[4];
    assign code     = {attr2[6:5], attr1[5:0]};
    assign pal      = attr2[3:0];
    assign top_y    = is_16x16 ? (8'd240 - sy) : (8'd248 - sy);
    assign y_diff   = target_y - {1'b0, top_y};
    assign final_x  = is_16x16 ? (flip_x ? ~pix_x : pix_x) : {1'b0, (flip_x ? ~pix_x[2:0] : pix_x[2:0])};
    assign final_y  = is_16x16 ? (flip_y ? ~y_diff[3:0] : y_diff[3:0]) : {1'b0, (flip_y ? ~y_diff[2:0] : y_diff[2:0])};
    assign rom_pix  = {sprite_rom_data_b1[~final_x[2:0]], sprite_rom_data_b0[~final_x[2:0]]};

    always_comb begin
        if (is_16x16)
            sprite_rom_addr = {code, final_y[3], final_x[3], final_y[2:0]};
        else
            sprite_rom_addr = {code, 2'b00, final_y[2:0]};
    end

    always_ff @(posedge clk_video) begin
        if (reset) begin
            state           <= S_IDLE;
            buf_sel         <= 1'b0;
            clr_x           <= 8'd0;
            spr_idx         <= 7'd127;
            sprite_ram_addr <= 7'd127;
            target_y        <= 9'd0;
            pix_x           <= 4'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (cen_video && h_cnt == 9'd0) begin
                        buf_sel  <= ~buf_sel;
                        target_y <= (v_cnt == 9'd263) ? 9'd0 : (v_cnt + 9'd1);
                        clr_x    <= 8'd0;
                        state    <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    linebuf[buf_sel][clr_x] <= 7'd0;
                    if (clr_x == 8'd255) begin
                        spr_idx         <= 7'd127;
                        sprite_ram_addr <= 7'd127;
                        state           <= S_WAIT_RAM;
                    end else begin
                        clr_x <= clr_x + 8'd1;
                    end
                end

                S_FETCH_RAM: begin
                    sprite_ram_addr <= spr_idx;
                    state           <= S_WAIT_RAM;
                end

                S_WAIT_RAM: begin
                    state <= S_CHECK_SPRITE;
                end

                S_CHECK_SPRITE: begin
                    sy    <= sprite_vram_q0;
                    attr1 <= sprite_vram_q1;
                    attr2 <= sprite_vram_q2;
                    sx    <= sprite_vram_q3;

                    if ((sprite_vram_q0 != 8'h00) && (sprite_vram_q0 != 8'hff) &&
                        !((sprite_vram_q3 < 8'h40 && sprite_vram_q2[4]) || (sprite_vram_q3 >= 8'hc0 && !sprite_vram_q2[4])) &&
                        ((target_y - {1'b0, (sprite_vram_q2[7] ? (8'd240 - sprite_vram_q0) : (8'd248 - sprite_vram_q0))}) < (sprite_vram_q2[7] ? 9'd16 : 9'd8))) begin
                        pix_x <= 4'd0;
                        state <= S_FETCH_ROM;
                    end else begin
                        if (spr_idx == 7'd0)
                            state <= S_IDLE;
                        else begin
                            spr_idx <= spr_idx - 7'd1;
                            state   <= S_FETCH_RAM;
                        end
                    end
                end

                S_FETCH_ROM: begin
                    state <= S_WAIT_ROM;
                end

                S_WAIT_ROM: begin
                    state <= S_DRAW_PIXEL;
                end

                S_DRAW_PIXEL: begin
                    draw_x = {1'b0, sx} + {5'd0, pix_x};
                    if (!draw_x[8] && (rom_pix != 2'b00)) begin
                        linebuf[buf_sel][draw_x[7:0]] <= {1'b1, pal, rom_pix};
                    end

                    if (pix_x == (is_16x16 ? 4'd15 : 4'd7)) begin
                        if (spr_idx == 7'd0)
                            state <= S_IDLE;
                        else begin
                            spr_idx <= spr_idx - 7'd1;
                            state   <= S_FETCH_RAM;
                        end
                    end else begin
                        pix_x <= pix_x + 4'd1;
                        if (is_16x16 && (pix_x == 4'd7))
                            state <= S_FETCH_ROM;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    logic [6:0] out_pix;
    always_ff @(posedge clk_video) begin
        if (reset) begin
            sprite_color_idx <= 8'h00;
        end else begin
            if (h_cnt < 9'd256) begin
                out_pix = linebuf[~buf_sel][h_cnt[7:0]];
                if (out_pix[6])
                    sprite_color_idx <= {color_bank, out_pix[5:0]};
                else
                    sprite_color_idx <= 8'h00;
            end else begin
                sprite_color_idx <= 8'h00;
            end
        end
    end

endmodule
