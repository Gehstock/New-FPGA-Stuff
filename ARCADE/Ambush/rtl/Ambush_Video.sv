`timescale 1ns / 1ps

module Ambush_Video (
    input  logic        clk_sys,         
    input  logic        cen_video,       
    input  logic        reset,
    input  logic [1:0]  color_bank,   
    input  logic        vram_cpu_enable,
    input  logic        vram_cpu_wren,
    input  logic [9:0]  vram_cpu_addr,
    input  logic [7:0]  vram_cpu_data_in,
    output logic [7:0]  vram_cpu_data_out,
    input  logic        sprite_cpu_enable,
    input  logic        sprite_cpu_wren,
    input  logic [8:0]  sprite_cpu_addr,
    input  logic [7:0]  sprite_cpu_data_in,
    output logic [7:0]  sprite_cpu_data_out,
    input  logic        attr_cpu_enable,
    input  logic        attr_cpu_wren,
    input  logic [7:0]  attr_cpu_addr,
    input  logic [7:0]  attr_cpu_data_in,
    output logic [7:0]  attr_cpu_data_out,
    input  logic        scroll_cpu_enable,
    input  logic        scroll_cpu_wren,
    input  logic [4:0]  scroll_cpu_addr,
    input  logic [7:0]  scroll_cpu_data_in,
    output logic [7:0]  scroll_cpu_data_out,
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b
);

    logic [8:0]  h_cnt, v_cnt; 
    logic [7:0]  prom_col1_q;
    logic [4:0]  tile_x, tile_y;
    logic [7:0]  sprite_vram_q;
    logic [9:0]  vram_video_addr;
    logic [7:0]  vram_video_data_out;
    logic [7:0]  scroll_ram_raw_q_b;
    logic [7:0]  scroll_video_data_out;
    logic [8:0]  scrolled_v_bus;
    logic [7:0]  attr_video_data_out;
    
    logic [13:0] tile_rom_addr;
    logic [7:0]  tile_rom_data_b0;
    logic [7:0]  tile_rom_data_b1;
    logic [7:0]  tile_color_idx;
    logic        tile_priority;
    
    logic [13:0] sprite_rom_addr;
    logic [7:0]  sprite_rom_data_b0;
    logic [7:0]  sprite_rom_data_b1;
    logic [7:0]  sprite_color_idx;	 
    logic [7:0]  final_color_idx;
    
    logic [1:0]  color_bank_reg;
    logic [7:0]  sprite_video_addr;
    
    logic [8:0]  h_cnt_next;
    assign h_cnt_next = (h_cnt < 9'd383) ? (h_cnt + 9'd1) : 9'd0;

    assign tile_x = h_cnt_next[7:3];
    assign scroll_video_data_out = scroll_ram_raw_q_b + 8'd1; 
    assign scrolled_v_bus = v_cnt - 9'd16 + {1'b0, scroll_video_data_out};
    assign tile_y = scrolled_v_bus[7:3];
	 
    assign vram_video_addr = {tile_y, tile_x};
    
    logic [7:0] final_attr_addr;
    assign final_attr_addr = { {vram_video_addr[9:7], 2'b00} & 5'b11100, 3'b000 } | { 3'b000, vram_video_addr[4:0] };

    assign video_r = prom_col1_q[2:0];
    assign video_g = prom_col1_q[5:3];
    assign video_b = {prom_col1_q[7:6], prom_col1_q[7]};

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            h_cnt  <= 9'd0;
            v_cnt  <= 9'd0;
            hsync  <= 1'b1;
            vsync  <= 1'b1;
            hblank <= 1'b0;
            vblank <= 1'b0;
            color_bank_reg <= 2'b00;
        end else if (cen_video) begin
            color_bank_reg <= color_bank;

            if (h_cnt == 9'd383) begin
                h_cnt <= 9'd0;
                if (v_cnt == 9'd263) begin
                    v_cnt <= 9'd0;
                end else begin
                    v_cnt <= v_cnt + 9'd1;
                end
            end else begin
                h_cnt <= h_cnt + 9'd1;
            end

            hblank <= (h_cnt >= 9'd255 && h_cnt < 9'd383);
            vblank <= (v_cnt < 9'd16 || v_cnt >= 9'd255);
            hsync  <= !(h_cnt >= 9'd271 && h_cnt < 9'd303); 
            vsync  <= !(v_cnt >= 9'd0 && v_cnt < 9'd4);
        end
    end

    dpram #(
        .address_width(10), 
        .data_width(8)
    ) video_ram_inst (
        .clock_a   ( clk_sys ), .enable_a  ( vram_cpu_enable ), .wren_a    ( vram_cpu_wren ), 
        .address_a ( vram_cpu_addr ), .data_a    ( vram_cpu_data_in ), .q_a       ( vram_cpu_data_out ),
        .clock_b   ( clk_sys ), .enable_b  ( 1'b1 ), .wren_b    ( 1'b0 ), 
        .address_b ( vram_video_addr ), .data_b    ( 8'h00 ), .q_b       ( vram_video_data_out )
    );

    dpram #(
        .address_width(8), 
        .data_width(8)
    ) sprite_ram_inst (
        .clock_a   ( clk_sys ), .enable_a  ( sprite_cpu_enable ), .wren_a    ( sprite_cpu_wren ), 
        .address_a ( sprite_cpu_addr ), .data_a    ( sprite_cpu_data_in ), .q_a       ( sprite_cpu_data_out ),
        .clock_b   ( clk_sys ), .enable_b  ( 1'b1 ), .wren_b    ( 1'b0 ), 
        .address_b ( sprite_video_addr ), .data_b    ( 8'h00 ), .q_b       ( sprite_vram_q )
    );

    (* syn_noprune = 1 *) dpram #(
        .address_width(8), 
        .data_width(8)
    ) attr_ram_inst (
        .clock_a   ( clk_sys ), .enable_a  ( attr_cpu_enable ), .wren_a    ( attr_cpu_wren ), 
        .address_a ( attr_cpu_addr ), .data_a    ( attr_cpu_data_in ), .q_a       ( attr_cpu_data_out ),
        .clock_b   ( clk_sys ), .enable_b  ( 1'b1 ), .wren_b    ( 1'b0 ), 
        .address_b ( final_attr_addr ), .data_b    ( 8'h00 ), .q_b       ( attr_video_data_out )
    );

    dpram #(
        .address_width(5), 
        .data_width(8)
    ) scroll_ram_inst (
        .clock_a   ( clk_sys ), .enable_a  ( scroll_cpu_enable ), .wren_a    ( scroll_cpu_wren ), 
        .address_a ( scroll_cpu_addr ), .data_a    ( scroll_cpu_data_in ), .q_a       ( scroll_cpu_data_out ),
        .clock_b   ( clk_sys ), .enable_b  ( 1'b1 ), .wren_b    ( 1'b0 ), 
        .address_b ( tile_x ), .data_b    ( 8'h00 ), .q_b       ( scroll_ram_raw_q_b )
    );

    rom_gfx1 u_rom_gfx1 (
        .clk_a  ( clk_sys ), .addr_a ( tile_rom_addr[12:0] ),   .q_a    ( tile_rom_data_b0 ),
        .clk_b  ( clk_sys ), .addr_b ( sprite_rom_addr[12:0] ), .q_b    ( sprite_rom_data_b0 )
    );

    rom_gfx2 u_rom_gfx2 (
        .clk_a  ( clk_sys ), .addr_a ( tile_rom_addr[12:0] ),   .q_a    ( tile_rom_data_b1 ),
        .clk_b  ( clk_sys ), .addr_b ( sprite_rom_addr[12:0] ), .q_b    ( sprite_rom_data_b1 )
    );

    Ambush_Tiles tiles_inst (
        .clk_video        ( clk_sys ),
        .h_cnt            ( h_cnt ),
        .v_cnt            ( v_cnt ),
        .color_bank       ( color_bank_reg ),
        .tile_code        ( vram_video_data_out ),
        .tile_attr        ( attr_video_data_out ),
        .scroll_data      ( scroll_video_data_out ),
        .tile_rom_addr    ( tile_rom_addr ),
        .tile_rom_data_b0 ( tile_rom_data_b0 ),
        .tile_rom_data_b1 ( tile_rom_data_b1 ),
        .tile_color_idx   ( tile_color_idx ),
        .tile_priority    ( tile_priority )
    );

    Ambush_Sprites sprites_inst (
        .clk_video          ( clk_sys ),
        .cen_video          ( cen_video ),
        .reset              ( reset ),
        .h_cnt              ( h_cnt ),
        .v_cnt              ( v_cnt ),
        .color_bank         ( color_bank_reg ),
        .sprite_ram_addr    ( sprite_video_addr ),
        .sprite_vram_q      ( sprite_vram_q ),
        .sprite_rom_addr    ( sprite_rom_addr ),
        .sprite_rom_data_b0 ( sprite_rom_data_b0 ),
        .sprite_rom_data_b1 ( sprite_rom_data_b1 ),
        .sprite_color_idx   ( sprite_color_idx )
    );

    always_comb begin
        if (tile_priority && (tile_color_idx[1:0] != 2'b00)) begin
            final_color_idx = tile_color_idx;
        end else if (sprite_color_idx[1:0] != 2'b00) begin
            final_color_idx = sprite_color_idx;
        end else begin
            final_color_idx = tile_color_idx;
        end
    end

    prom_col1 u_prom_col1 (
        .clk  ( clk_sys ),
        .addr ( final_color_idx ),
        .data ( prom_col1_q )
    );

endmodule










void ambush_state::get_bg_tile_info(offline_info &tileinfo, int tile_index)
{

    uint8_t const code = m_video_ram[tile_index];
    uint8_t const attr = m_attribute_ram[((tile_index >> 2) & 0xe0) | (tile_index & 0x1f)];

    int const color = (m_color_bank << 4) | (attr & 0x0f);
    
    tileinfo.set(0, code, color, (attr & 0x10) ? TILEMAP_FLIPY : 0);
    tileinfo.category = BIT(attr, 4); 
}

