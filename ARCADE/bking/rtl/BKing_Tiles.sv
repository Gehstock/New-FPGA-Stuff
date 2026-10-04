module BKing_Tiles (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [8:0]  x_pos,
    input  logic [8:0]  y_pos,
    input  logic [7:0]  scroll_x,
    input  logic [7:0]  scroll_y,
    input  logic [1:0]  palette_bank,
    input  logic        flip_screen,
    output logic [10:0] playfield_addr,
    input  logic [7:0]  playfield_q,
    output logic [2:0]  pixel_color,
    output logic [1:0]  pixel_palette
);

    logic [8:0] eff_x, eff_y;
    
    always_comb begin
        if (flip_screen) begin
            eff_x = x_pos; 
            eff_y = 9'd255 - y_pos;
        end else begin
            eff_x = 9'd255 - x_pos; 
            eff_y = y_pos;
        end
    end

    logic [4:0] tile_col, tile_row;
    logic [2:0] pixel_x, pixel_y;
    assign tile_col = eff_x[7:3];
    assign tile_row = eff_y[7:3];
    logic [2:0] raw_x_bit;
    assign raw_x_bit = eff_x[2:0];
    assign pixel_x   = 3'd7 - (raw_x_bit);
    assign pixel_y  = eff_y[2:0];

    logic [9:0] addr_code;
    assign addr_code = {tile_row, tile_col};

    logic [1:0] fetch_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) fetch_cnt <= 2'b00;
        else        fetch_cnt <= fetch_cnt + 2'b01;
    end

    always_comb begin
        if (fetch_cnt == 2'b00) playfield_addr = {addr_code, 1'b0};
        else                    playfield_addr = {addr_code, 1'b1};
    end

    logic [7:0] code0_reg, code1_reg;

    always_ff @(posedge clk) begin
        if (fetch_cnt == 2'b01)      code0_reg <= playfield_q;
        else if (fetch_cnt == 2'b10) code1_reg <= playfield_q;
    end

    logic [9:0]  tile_code;
    logic        tile_flip_x, tile_flip_y;

    assign tile_code   = {code1_reg[1:0], code0_reg};
    assign tile_flip_x = code1_reg[2];
    assign tile_flip_y = code1_reg[3];

    logic [2:0] rom_pixel_x, rom_pixel_y;

    assign rom_pixel_x = tile_flip_x ? (3'd7 - pixel_x) : pixel_x;
    assign rom_pixel_y = tile_flip_y ? (3'd7 - pixel_y) : pixel_y;

    logic [11:0] rom_addr;
    assign rom_addr = {tile_code[8:0], rom_pixel_y};

    logic [7:0] r1_data, r2_data, r3_data, r4_data, r5_data, r6_data;
    rom_gfx1 ic5A (.clk(clk), .addr(rom_addr), .data(r1_data));
    rom_gfx2 ic7A (.clk(clk), .addr(rom_addr), .data(r2_data));
    rom_gfx3 ic8A (.clk(clk), .addr(rom_addr), .data(r3_data));
    rom_gfx4 ic10A (.clk(clk), .addr(rom_addr), .data(r4_data));
    rom_gfx5 ic11A (.clk(clk), .addr(rom_addr), .data(r5_data));
    rom_gfx6 ic13A (.clk(clk), .addr(rom_addr), .data(r6_data));

    logic [7:0] blue_mux, green_mux, red_mux;
    assign blue_mux = tile_code[9] ? r2_data : r1_data;
    assign green_mux = tile_code[9] ? r4_data : r3_data;
    assign red_mux = tile_code[9] ? r6_data : r5_data;
    logic [2:0] final_bit_sel_delayed;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_bit_sel_delayed <= 3'b000;
        end else begin
            final_bit_sel_delayed <= 3'd7 - rom_pixel_x;
        end
    end

    assign pixel_color[0] = blue_mux[final_bit_sel_delayed];
    assign pixel_color[1] = green_mux[final_bit_sel_delayed];
    assign pixel_color[2] = red_mux[final_bit_sel_delayed];

    always_ff @(posedge clk) begin
        pixel_palette <= code1_reg[5:4];
    end

endmodule


