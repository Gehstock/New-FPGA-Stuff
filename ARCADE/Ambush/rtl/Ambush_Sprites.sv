`timescale 1ns / 1ps

module Ambush_Sprites (
    input  logic        clk_video,
    input  logic        cen_video,
    input  logic        reset,
    input  logic [8:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [1:0]  color_bank,   
    output logic [7:0]  sprite_ram_addr, 
    input  logic [7:0]  sprite_vram_q,       
    output logic [13:0] sprite_rom_addr,
    input  logic [7:0]  sprite_rom_data_b0,
    input  logic [7:0]  sprite_rom_data_b1,
    output logic [7:0]  sprite_color_idx
);

    typedef struct packed {
        logic [7:0] sx;
        logic [7:0] attr_1;
        logic [7:0] attr_2;
        logic [3:0] sprite_y_offset; 
        logic       is_16x16;
        logic       active;
    } sprite_buffer_t;

    sprite_buffer_t line_buffer [0:7];
    logic [2:0] sprite_count;

    typedef enum logic [1:0] { IDLE, WAIT_RAM, FETCH_BYTE, CHECK_SPRITE } state_t;
    state_t state;

    logic [5:0] search_idx;      
    logic [1:0] byte_idx;        
    logic [8:0] next_v_cnt;
    logic [31:0] temp_sprite_data;

    logic [8:0] v_visible;
    assign v_visible = v_cnt - 9'd16;
    assign next_v_cnt = v_visible + 9'd1; 

    logic [7:0] check_sy;
    logic [7:0] check_attr_1;
    logic [7:0] check_attr_2;
    logic [7:0] check_sx;
    logic       check_is_16x16;
    logic [7:0] check_active_sy;
    logic [8:0] check_v_diff;
    logic       check_v_hit;
    logic       check_valid_sy;

    assign check_sy       = temp_sprite_data[7:0];
    assign check_attr_1   = temp_sprite_data[15:8];
    assign check_attr_2   = temp_sprite_data[23:16];
    assign check_sx       = temp_sprite_data[31:24];
    assign check_is_16x16 = check_attr_2[7];
    assign check_active_sy = check_is_16x16 ? (8'd240 - check_sy) : (8'd248 - check_sy);
    assign check_v_diff    = next_v_cnt - {1'b0, check_active_sy};
    assign check_v_hit     = check_is_16x16 ? (check_v_diff < 9'd16) : (check_v_diff < 9'd8);
    assign check_valid_sy  = (check_sy != 8'h00 && check_sy != 8'hFF);

    always_ff @(posedge clk_video) begin
        if (reset) begin
            state <= IDLE;
            search_idx <= 6'd0;
            byte_idx <= 2'd0;
            sprite_count <= 3'd0;
            sprite_ram_addr <= 8'd0;
            for (int i=0; i<8; i++) line_buffer[i].active <= 1'b0;
        end else if (cen_video) begin
            case (state)
                IDLE: begin
                    if (h_cnt == 9'd256) begin
                        sprite_count <= 3'd0;
                        search_idx <= 6'd0;
                        byte_idx <= 2'd0;
                        sprite_ram_addr <= 8'd0; 
                        state <= WAIT_RAM;
                        for (int i=0; i<8; i++) line_buffer[i].active <= 1'b0;
                    end
                end

                WAIT_RAM: begin
                    byte_idx <= 2'd0;
                    sprite_ram_addr <= {search_idx, 2'd1}; 
                    state <= FETCH_BYTE;
                end

                FETCH_BYTE: begin
                    case (byte_idx)
                        2'b00: temp_sprite_data[7:0]   <= sprite_vram_q;
                        2'b01: temp_sprite_data[15:8]  <= sprite_vram_q;
                        2'b10: temp_sprite_data[23:16] <= sprite_vram_q;
                        2'b11: temp_sprite_data[31:24] <= sprite_vram_q;
                    endcase

                    if (byte_idx == 2'b11) begin
                        state <= CHECK_SPRITE;
                    end else begin
                        byte_idx <= byte_idx + 2'd1;
                        sprite_ram_addr <= {search_idx, byte_idx + 2'd1};
                    end
                end

                CHECK_SPRITE: begin
                    if (check_v_hit && check_valid_sy && (sprite_count < 3'd7)) begin
                        line_buffer[sprite_count].sx              <= check_sx;
                        line_buffer[sprite_count].attr_1          <= check_attr_1;
                        line_buffer[sprite_count].attr_2          <= check_attr_2;
                        line_buffer[sprite_count].sprite_y_offset <= check_v_diff[3:0];
                        line_buffer[sprite_count].is_16x16        <= check_is_16x16;
                        line_buffer[sprite_count].active          <= 1'b1;
                        sprite_count <= sprite_count + 3'd1;
                    end

                    if (search_idx == 6'd63) begin
                        state <= IDLE;
                    end else begin
                        search_idx <= search_idx + 6'd1;
                        byte_idx <= 2'd0;
                        sprite_ram_addr <= {search_idx + 6'd1, 2'b00}; 
                        state <= WAIT_RAM; 
                    end
                end
            endcase
        end
    end

    logic [2:0] render_select;
    logic       render_hit;
    logic [3:0] final_x;
    logic [3:0] final_y;
    logic [7:0] sprite_code;
    
    logic [7:0] h_diff_arr [0:7];
    logic       h_hit_arr  [0:7];
    logic       wrap_arr   [0:7];
    logic       allowed_arr[0:7];

    assign h_diff_arr[0] = h_cnt[7:0] - line_buffer[0].sx;
    assign h_hit_arr[0]  = line_buffer[0].is_16x16 ? (h_diff_arr[0] < 8'd16) : (h_diff_arr[0] < 8'd8);
    assign wrap_arr[0]   = line_buffer[0].attr_2[4];
    assign allowed_arr[0] = ((line_buffer[0].sx >= 8'h40 || !wrap_arr[0]) && (line_buffer[0].sx < 8'hc0 || wrap_arr[0]));

    assign h_diff_arr[1] = h_cnt[7:0] - line_buffer[1].sx;
    assign h_hit_arr[1]  = line_buffer[1].is_16x16 ? (h_diff_arr[1] < 8'd16) : (h_diff_arr[1] < 8'd8);
    assign wrap_arr[1]   = line_buffer[1].attr_2[4];
    assign allowed_arr[1] = ((line_buffer[1].sx >= 8'h40 || !wrap_arr[1]) && (line_buffer[1].sx < 8'hc0 || wrap_arr[1]));

    assign h_diff_arr[2] = h_cnt[7:0] - line_buffer[2].sx;
    assign h_hit_arr[2]  = line_buffer[2].is_16x16 ? (h_diff_arr[2] < 8'd16) : (h_diff_arr[2] < 8'd8);
    assign wrap_arr[2]   = line_buffer[2].attr_2[4];
    assign allowed_arr[2] = ((line_buffer[2].sx >= 8'h40 || !wrap_arr[2]) && (line_buffer[2].sx < 8'hc0 || wrap_arr[2]));

    assign h_diff_arr[3] = h_cnt[7:0] - line_buffer[3].sx;
    assign h_hit_arr[3]  = line_buffer[3].is_16x16 ? (h_diff_arr[3] < 8'd16) : (h_diff_arr[3] < 8'd8);
    assign wrap_arr[3]   = line_buffer[3].attr_2[4];
    assign allowed_arr[3] = ((line_buffer[3].sx >= 8'h40 || !wrap_arr[3]) && (line_buffer[3].sx < 8'hc0 || wrap_arr[3]));

    assign h_diff_arr[4] = h_cnt[7:0] - line_buffer[4].sx;
    assign h_hit_arr[4]  = line_buffer[4].is_16x16 ? (h_diff_arr[4] < 8'd16) : (h_diff_arr[4] < 8'd8);
    assign wrap_arr[4]   = line_buffer[4].attr_2[4];
    assign allowed_arr[4] = ((line_buffer[4].sx >= 8'h40 || !wrap_arr[4]) && (line_buffer[4].sx < 8'hc0 || wrap_arr[4]));

    assign h_diff_arr[5] = h_cnt[7:0] - line_buffer[5].sx;
    assign h_hit_arr[5]  = line_buffer[5].is_16x16 ? (h_diff_arr[5] < 8'd16) : (h_diff_arr[5] < 8'd8);
    assign wrap_arr[5]   = line_buffer[5].attr_2[4];
    assign allowed_arr[5] = ((line_buffer[5].sx >= 8'h40 || !wrap_arr[5]) && (line_buffer[5].sx < 8'hc0 || wrap_arr[5]));

    assign h_diff_arr[6] = h_cnt[7:0] - line_buffer[6].sx;
    assign h_hit_arr[6]  = line_buffer[6].is_16x16 ? (h_diff_arr[6] < 8'd16) : (h_diff_arr[6] < 8'd8);
    assign wrap_arr[6]   = line_buffer[6].attr_2[4];
    assign allowed_arr[6] = ((line_buffer[6].sx >= 8'h40 || !wrap_arr[6]) && (line_buffer[6].sx < 8'hc0 || wrap_arr[6]));

    assign h_diff_arr[7] = h_cnt[7:0] - line_buffer[7].sx;
    assign h_hit_arr[7]  = line_buffer[7].is_16x16 ? (h_diff_arr[7] < 8'd16) : (h_diff_arr[7] < 8'd8);
    assign wrap_arr[7]   = line_buffer[7].attr_2[4];
    assign allowed_arr[7] = ((line_buffer[7].sx >= 8'h40 || !wrap_arr[7]) && (line_buffer[7].sx < 8'hc0 || wrap_arr[7]));

    always_comb begin
        render_select = 3'd0;
        render_hit    = 1'b0;
        for (int i = 7; i >= 0; i--) begin
            if (line_buffer[i].active && h_hit_arr[i] && allowed_arr[i]) begin
                render_select = i[2:0];
                render_hit    = 1'b1;
            end
        end
    end

    logic flipx, flipy;
assign flipx = line_buffer[render_select].attr_1[7];
assign flipy = line_buffer[render_select].attr_1[6];
    
    assign final_x = flipx ? (~h_diff_arr[render_select][3:0]) : h_diff_arr[render_select][3:0];
    assign final_y = flipy ? (~line_buffer[render_select].sprite_y_offset) : line_buffer[render_select].sprite_y_offset;

    logic [7:0] base_code;
    assign base_code = {line_buffer[render_select].attr_2[6:5], line_buffer[render_select].attr_1[5:0]};

    logic [13:0] full_addr_16x16;
    logic [13:0] full_addr_8x8;
    
    assign full_addr_16x16 = {1'b0, base_code[5:0], 7'b0} | {6'b0, final_y[3:0], final_x[3:1]};
    assign full_addr_8x8   = {1'b0, base_code[5:0], 7'b0} | {6'b0, final_y[3], final_x[3], final_y[2:0], final_x[2:1]};
    
    assign sprite_rom_addr = line_buffer[render_select].is_16x16 ? full_addr_16x16 : full_addr_8x8;

    logic [1:0] color_bank_d1;
    logic [3:0] color_idx_d1;
    logic       render_hit_d1;
    logic [1:0] pixel_bit;

    always_ff @(posedge clk_video) begin
        if (cen_video) begin
            pixel_bit        <= {sprite_rom_data_b1[final_x[2:0]], sprite_rom_data_b0[final_x[2:0]]};
            color_bank_d1    <= color_bank;
            color_idx_d1     <= line_buffer[render_select].attr_2[3:0];
            render_hit_d1    <= render_hit;
        end
    end

    always_comb begin
        if (render_hit_d1 && (pixel_bit != 2'b00)) begin
            sprite_color_idx = {color_bank_d1, color_idx_d1, pixel_bit};
        end else begin
            sprite_color_idx = 8'h00; 
        end
    end

endmodule
