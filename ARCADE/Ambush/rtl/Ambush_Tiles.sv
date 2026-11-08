//module Ambush_Tiles (
//    input  logic        clk_video,
//    input  logic        h_blank,
//    input  logic [8:0]  h_cnt,
//    input  logic [8:0]  v_cnt,
//    input  logic [1:0]  color_bank,
//    input  logic [7:0]  tile_code,
//    input  logic [7:0]  tile_attr,
//    input  logic [7:0]  scroll_data,
//    output logic [12:0] tile_rom_addr,
//    input  logic [7:0]  tile_rom_data_b0,
//    input  logic [7:0]  tile_rom_data_b1,
//    output logic [7:0]  tile_color_idx,
//    output logic        tile_priority
//);
//
//    logic [2:0] pixel_x, pixel_y, pixel_x_d1, pixel_x_d2;
//    logic [9:0] full_tile_code;
//    logic [8:0] scrolled_v;
//    logic [7:0] tile_attr_d1, tile_attr_d2;
//    logic [1:0] color_bank_d1, color_bank_d2;
//    logic h_blank_d1, h_blank_d2;
//    logic [1:0] pixel_bit;
//    assign pixel_x = h_cnt[2:0];
//    assign scrolled_v = v_cnt - 9'd16 + {1'b0, scroll_data};
//    assign pixel_y = scrolled_v[2:0];
//    assign full_tile_code = {tile_attr[6:5], tile_code};
//
//    assign tile_rom_addr = {full_tile_code, pixel_y};
//
//    always_ff @(posedge clk_video) begin
//        pixel_x_d1    <= pixel_x;
//        pixel_x_d2    <= pixel_x_d1;
//        tile_attr_d1  <= tile_attr;
//        tile_attr_d2  <= tile_attr_d1;
//        color_bank_d1 <= color_bank;
//        color_bank_d2 <= color_bank_d1;
//        h_blank_d1    <= h_blank;
//        h_blank_d2    <= h_blank_d1;
//    end
//
//    assign pixel_bit = {
//        tile_rom_data_b1[3'd5 - pixel_x_d2],
//        tile_rom_data_b0[3'd5 - pixel_x_d2]
//    };
//
//    assign tile_priority = tile_attr_d2[4];
//
//    always_comb begin
//        if (h_blank_d2) begin
//            tile_color_idx = 8'h00;
//        end else begin
//            tile_color_idx = {
//                color_bank_d2,
//                tile_attr_d2[3:0],
//                pixel_bit
//            };
//        end
//    end
//
//endmodule

module Ambush_Tiles (
    input  logic        clk_video,
    input  logic        h_blank,
    input  logic [8:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [1:0]  color_bank,
    input  logic [7:0]  tile_code,
    input  logic [7:0]  tile_attr,
    input  logic [7:0]  scroll_data,
    output logic [12:0] tile_rom_addr,
    input  logic [7:0]  tile_rom_data_b0,
    input  logic [7:0]  tile_rom_data_b1,
    output logic [7:0]  tile_color_idx,
    output logic        tile_priority
);

    logic [2:0] pixel_x, pixel_y;
    logic [9:0] full_tile_code;
    logic [8:0] scrolled_v;
    logic [2:0] pixel_x_d1;
    logic [7:0] tile_attr_d1;
    logic [1:0] color_bank_d1;
    logic h_blank_d1;
    logic [1:0] pixel_bit;
    assign pixel_x = h_cnt[2:0];
    assign scrolled_v = v_cnt - 9'd16 + {1'b0, scroll_data};
    assign pixel_y = scrolled_v[2:0];
    assign full_tile_code = {tile_attr[6:5], tile_code};
    assign tile_rom_addr = {full_tile_code, pixel_y};

    always_ff @(posedge clk_video) begin
        pixel_x_d1    <= pixel_x;
        tile_attr_d1  <= tile_attr;
        color_bank_d1 <= color_bank;
        h_blank_d1    <= h_blank;
    end

    assign pixel_bit = {
        tile_rom_data_b1[3'd6 - pixel_x_d1],
        tile_rom_data_b0[3'd6 - pixel_x_d1]
    };

    assign tile_priority = tile_attr_d1[4];

    always_comb begin
        if (h_blank_d1) begin
            tile_color_idx = 8'h00;
        end else begin
            tile_color_idx = {
                color_bank_d1,
                tile_attr_d1[3:0],
                pixel_bit
            };
        end
    end

endmodule
