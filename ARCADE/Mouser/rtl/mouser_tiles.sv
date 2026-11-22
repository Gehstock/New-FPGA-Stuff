module mouser_tiles (
    input  logic        clk_sys,
    input  logic [7:0]  vram_data,
    input  logic [7:0]  cram_data,
    input  logic [7:0]  spriteram_row_scroll,
    
    output logic [9:0]  video_ram_addr,
    output logic [9:0]  video_cram_addr,
    output logic [7:0]  video_spram_addr,
    
    input  logic [7:0]  h_count,
    input  logic [7:0]  v_count,
    
    output logic        tile_p0,
    output logic        tile_p1,
    output logic [3:0]  tile_color_idx
);

    logic [4:0]  tile_col;
    logic [7:0]  scrolled_v;
    logic [4:0]  tile_row;
    
    logic [12:0] tile_rom_addr;
    logic [7:0]  rom_data_p0;
    logic [7:0]  rom_data_p1;

    assign tile_col         = h_count[7:3];
    assign video_spram_addr = {3'b000, tile_col}; 

    assign scrolled_v = v_count - spriteram_row_scroll;
    assign tile_row   = scrolled_v[7:3];

    assign video_ram_addr  = {tile_row, tile_col};
    assign video_cram_addr = {tile_row, tile_col};

    assign tile_rom_addr = {cram_data[6:5], vram_data, scrolled_v[2:0]};

    gfx_rom1 tile_rom_plane0 (
        .clk(clk_sys),
        .addr(tile_rom_addr),
        .data(rom_data_p0)
    );

    gfx_rom2 tile_rom_plane1 (
        .clk(clk_sys),
        .addr(tile_rom_addr),
        .data(rom_data_p1)
    );

    logic [2:0] pixel_offset;
    assign pixel_offset = 3'd7 - h_count[2:0];

    assign tile_p0 = rom_data_p0[pixel_offset];
    assign tile_p1 = rom_data_p1[pixel_offset];
    assign tile_color_idx = cram_data[3:0];

endmodule
