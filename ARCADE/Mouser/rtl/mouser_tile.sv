module mouser_tile (
    input  logic        clk_sys,
    input  logic [7:0]  vram_data,
    input  logic [7:0]  cram_data,
    input  logic [7:0]  spriteram_data,
    input  logic [8:0]  h_count,
    input  logic [8:0]  v_count,
    output logic [9:0]  video_ram_addr,
    output logic [9:0]  video_cram_addr,
    output logic [13:0] tile_rom_addr,
    output logic [3:0]  tile_color_idx,
    output logic [2:0]  tile_pixel_offset
);

    logic [4:0] tile_col;
    logic [4:0] tile_row;
    logic [7:0] tile_scrolled_v;
    logic [4:0] tile_row_scrolled;
    logic [9:0] tile_code;

    assign tile_col          = h_count[7:3];
    assign tile_row          = v_count[7:3];
    assign tile_scrolled_v   = v_count[7:0] - spriteram_data;
    assign tile_row_scrolled = tile_scrolled_v[7:3];

    assign video_ram_addr    = {tile_row, tile_col};
    assign video_cram_addr   = {tile_row_scrolled, tile_col};

    assign tile_code         = {cram_data[4], cram_data[5], vram_data};
    assign tile_rom_addr     = {1'b0, tile_code, tile_scrolled_v[2:0]};

    always_ff @(posedge clk_sys) begin
        tile_color_idx    <= cram_data[3:0];
        tile_pixel_offset <= 3'd7 - h_count[2:0];
    end

endmodule
