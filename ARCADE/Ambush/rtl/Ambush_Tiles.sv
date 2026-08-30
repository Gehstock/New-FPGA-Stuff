`timescale 1ns / 1ps

module Ambush_Tiles (
    input  logic        clk_video,
    input  logic [8:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [1:0]  color_bank,
    input  logic [7:0]  tile_code,
    input  logic [7:0]  tile_attr,
    input  logic [7:0]  scroll_data,
    output logic [13:0] tile_rom_addr,
    input  logic [7:0]  tile_rom_data_b0,
    input  logic [7:0]  tile_rom_data_b1,
    output logic [7:0]  tile_color_idx,
    output logic        tile_priority
);

    logic [8:0] scrolled_v;
    logic [2:0] pixel_x, pixel_y;
    logic [9:0] full_tile_code;
    logic [1:0] pixel_bit;

    assign scrolled_v     = v_cnt - 9'd16 + {1'b0, scroll_data};
    assign pixel_x        = h_cnt[2:0];
    assign pixel_y        = scrolled_v[2:0];
    
    assign full_tile_code = {tile_attr[6:5], tile_code};   
    assign tile_rom_addr  = {1'b0, full_tile_code, pixel_y};

    assign tile_priority = tile_attr[4];
    assign pixel_bit = {tile_rom_data_b1[3'd7 - pixel_x], tile_rom_data_b0[3'd7 - pixel_x]};

    always_comb begin
        if (pixel_bit == 2'b00) begin
            tile_color_idx = 8'h00; 
        end else begin
            tile_color_idx = {color_bank, tile_attr[3:0], pixel_bit};
        end
    end

endmodule
