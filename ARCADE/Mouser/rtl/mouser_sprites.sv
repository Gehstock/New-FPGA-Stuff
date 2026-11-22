module mouser_sprites (
    input  logic        clk_sys,
    input  logic [7:0]  spram_data,
    output logic [7:0]  spram_addr,
    
    input  logic [7:0]  h_count,
    input  logic [7:0]  v_count,
    
    output logic        gfx_en,
    output logic        sprite_p0,
    output logic        sprite_p1,
    output logic [3:0]  sprite_color_idx
);

    logic [2:0]  sprite_select;
    logic [1:0]  byte_select;
    
    logic [7:0]  s_byte0;
    logic [7:0]  s_byte1;
    logic [7:0]  s_byte2;
    logic [7:0]  s_byte3;

    assign sprite_select = h_count[6:4];
    assign byte_select   = h_count[3:2];

    assign spram_addr = h_count ? {2'b10, sprite_select, byte_select} : {2'b01, sprite_select, byte_select};

    always_ff @(posedge clk_sys) begin
        case (byte_select)
            2'b00: s_byte0 <= spram_data;
            2'b01: s_byte1 <= spram_data;
            2'b10: s_byte2 <= spram_data;
            2'b11: s_byte3 <= spram_data;
        endcase
    end

    logic        sprite_visible;
    logic        sprite_bank;
    logic [5:0]  sprite_code;
    logic        flip_x;
    logic        flip_y;
    logic [7:0]  sprite_x;
    logic [7:0]  sprite_y;

    assign sprite_visible = s_byte1;
    assign sprite_bank    = s_byte1;
    assign sprite_code    = s_byte0[5:0];
    assign flip_x         = s_byte0;
    assign flip_y         = s_byte0;
    assign sprite_x       = s_byte3;
    assign sprite_y       = 8'hEF - s_byte2;

    logic in_sprite_window;
    assign in_sprite_window = sprite_visible && 
                              (h_count >= sprite_x && h_count < sprite_x + 8'd16) &&
                              (v_count >= sprite_y && v_count < {1'b0, sprite_y} + 9'd16);

    logic [3:0] pixel_h;
    logic [3:0] pixel_v;
    assign pixel_h = flip_x ? (4'd15 - (h_count[3:0] - sprite_x[3:0])) : (h_count[3:0] - sprite_x[3:0]);
    assign pixel_v = flip_y ? (4'd15 - (v_count[3:0] - sprite_y[3:0])) : (v_count[3:0] - sprite_y[3:0]);

    logic [13:0] sprite_rom_addr;
    assign sprite_rom_addr = {2'b01, sprite_bank, sprite_code[2:0], pixel_v, pixel_h};

    logic [7:0] rom_data_sp0;
    logic [7:0] rom_data_sp1;

//    gfx_rom1 sprite_rom_plane0 (
//        .clk(clk_sys),
//        .addr(sprite_rom_addr),
//        .data(rom_data_sp0)
//    );
//
//    gfx_rom2 sprite_rom_plane1 (
//        .clk(clk_sys),
//        .addr(sprite_rom_addr),
//        .data(rom_data_sp1)
//    );

    logic [2:0] bit_shift;
    assign bit_shift = 3'd7 - pixel_h[2:0];

    assign sprite_p0 = rom_data_sp0[bit_shift];
    assign sprite_p1 = rom_data_sp1[bit_shift];

    assign sprite_color_idx = s_byte1[3:0];
    assign gfx_en = in_sprite_window && (rom_data_sp0[bit_shift] || rom_data_sp1[bit_shift]);

endmodule
