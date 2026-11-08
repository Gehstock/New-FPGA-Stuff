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

    logic [8:0] h_cnt, v_cnt;
    logic [7:0] prom_col1_q, prom_col1_reg;
    logic [4:0] tile_x, tile_y;
    logic [9:0] vram_video_addr;
    logic [7:0] vram_video_data_out, scroll_ram_raw_q_b, scroll_video_data_out;
    logic [8:0] scrolled_v_bus;
    logic [7:0] attr_video_data_out, final_attr_addr;
    logic [12:0] tile_rom_addr;
    logic [7:0] tile_rom_data_b0, tile_rom_data_b1, tile_color_idx;
    logic tile_priority;
    logic [12:0] sprite_rom_addr;
    logic [7:0] sprite_rom_data_b0, sprite_rom_data_b1, sprite_color_idx;
    logic [7:0] final_color_idx;
    logic [1:0] color_bank_reg;
    logic [6:0] sprite_video_addr;
    logic [7:0] sprite_vram_q0, sprite_vram_q1, sprite_vram_q2, sprite_vram_q3;
    logic [7:0] sprite_cpu_q0, sprite_cpu_q1, sprite_cpu_q2, sprite_cpu_q3;
    logic [1:0] sprite_cpu_bank_d1;
    logic hblank_reg, vblank_reg;
    logic [8:0] h_cnt_next;

    assign h_cnt_next = (h_cnt < 9'd383) ? h_cnt + 9'd1 : 9'd0;
    assign tile_x = h_cnt_next[7:3];
    assign scroll_video_data_out = scroll_ram_raw_q_b + 8'd1;
    assign scrolled_v_bus = v_cnt - 9'd16 + {1'b0, scroll_video_data_out};
    assign tile_y = scrolled_v_bus[7:3];
    assign vram_video_addr = {tile_y, tile_x};
    assign final_attr_addr = {tile_y[4:2], tile_x[4:0]};

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            color_bank_reg <= 2'b00;
            prom_col1_reg <= 8'd0;
            hblank_reg <= 1'b0;
            vblank_reg <= 1'b0;
            sprite_cpu_bank_d1 <= 2'd0;
        end else begin
            prom_col1_reg <= prom_col1_q;
            hblank_reg <= hblank;
            vblank_reg <= vblank;

            if (cen_video)
                color_bank_reg <= color_bank;

            if (sprite_cpu_enable)
                sprite_cpu_bank_d1 <= sprite_cpu_addr[1:0];
        end
    end

    assign video_r = (hblank_reg || vblank_reg) ? 3'd0 : prom_col1_reg[2:0];
    assign video_g = (hblank_reg || vblank_reg) ? 3'd0 : prom_col1_reg[5:3];
    assign video_b = (hblank_reg || vblank_reg) ? 3'd0 : {prom_col1_reg[7:6], prom_col1_reg[7]};

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            h_cnt <= 9'd0;
            v_cnt <= 9'd0;
            hsync <= 1'b1;
            vsync <= 1'b1;
            hblank <= 1'b0;
            vblank <= 1'b0;
        end else if (cen_video) begin

            if (h_cnt == 9'd383) begin
                h_cnt <= 9'd0;

                if (v_cnt == 9'd263)
                    v_cnt <= 9'd0;
                else
                    v_cnt <= v_cnt + 9'd1;

            end else begin
                h_cnt <= h_cnt + 9'd1;
            end

            hblank <=(h_cnt >= 9'd256 && h_cnt < 9'd383);
            vblank <=(v_cnt < 9'd16 || v_cnt >= 9'd240);
            hsync <=!(h_cnt >= 9'd274 && h_cnt < 9'd306);
            vsync <=!(v_cnt < 9'd4);
        end
    end

    dpram #(10,8) video_ram_inst (
        .clock_a(clk_sys),
        .enable_a(vram_cpu_enable),
        .wren_a(vram_cpu_wren),
        .address_a(vram_cpu_addr),
        .data_a(vram_cpu_data_in),
        .q_a(vram_cpu_data_out),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(vram_video_addr),
        .data_b(8'h00),
        .q_b(vram_video_data_out)
    );

    dpram #(7,8) sprite_ram0 (
        .clock_a(clk_sys),
        .enable_a(sprite_cpu_enable && sprite_cpu_addr[1:0] == 2'd0),
        .wren_a(sprite_cpu_wren),
        .address_a(sprite_cpu_addr[8:2]),
        .data_a(sprite_cpu_data_in),
        .q_a(sprite_cpu_q0),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(sprite_video_addr),
        .data_b(8'h00),
        .q_b(sprite_vram_q0)
    );

    dpram #(7,8) sprite_ram1 (
        .clock_a(clk_sys),
        .enable_a(sprite_cpu_enable && sprite_cpu_addr[1:0] == 2'd1),
        .wren_a(sprite_cpu_wren),
        .address_a(sprite_cpu_addr[8:2]),
        .data_a(sprite_cpu_data_in),
        .q_a(sprite_cpu_q1),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(sprite_video_addr),
        .data_b(8'h00),
        .q_b(sprite_vram_q1)
    );

    dpram #(7,8) sprite_ram2 (
        .clock_a(clk_sys),
        .enable_a(sprite_cpu_enable && sprite_cpu_addr[1:0] == 2'd2),
        .wren_a(sprite_cpu_wren),
        .address_a(sprite_cpu_addr[8:2]),
        .data_a(sprite_cpu_data_in),
        .q_a(sprite_cpu_q2),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(sprite_video_addr),
        .data_b(8'h00),
        .q_b(sprite_vram_q2)
    );

    dpram #(7,8) sprite_ram3 (
        .clock_a(clk_sys),
        .enable_a(sprite_cpu_enable && sprite_cpu_addr[1:0] == 2'd3),
        .wren_a(sprite_cpu_wren),
        .address_a(sprite_cpu_addr[8:2]),
        .data_a(sprite_cpu_data_in),
        .q_a(sprite_cpu_q3),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(sprite_video_addr),
        .data_b(8'h00),
        .q_b(sprite_vram_q3)
    );

    always_comb begin
        case (sprite_cpu_bank_d1)
            2'd0: sprite_cpu_data_out = sprite_cpu_q0;
            2'd1: sprite_cpu_data_out = sprite_cpu_q1;
            2'd2: sprite_cpu_data_out = sprite_cpu_q2;
            2'd3: sprite_cpu_data_out = sprite_cpu_q3;
            default: sprite_cpu_data_out = 8'h00;
        endcase
    end

    dpram #(8,8) attr_ram_inst (
        .clock_a(clk_sys),
        .enable_a(attr_cpu_enable),
        .wren_a(attr_cpu_wren),
        .address_a(attr_cpu_addr),
        .data_a(attr_cpu_data_in),
        .q_a(attr_cpu_data_out),

        .clock_b(clk_sys),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(final_attr_addr),
        .data_b(8'h00),
        .q_b(attr_video_data_out)
    );

    dpram #(5,8) scroll_ram_inst (
    .clock_a(clk_sys),
    .enable_a(scroll_cpu_enable),
    .wren_a(scroll_cpu_wren),
    .address_a(scroll_cpu_addr),
    .data_a(scroll_cpu_data_in),
    .q_a(scroll_cpu_data_out),

    .clock_b(clk_sys),
    .enable_b(1'b1),
    .wren_b(1'b0),
    .address_b(tile_x),
    .data_b(8'h00),
    .q_b(scroll_ram_raw_q_b)
);

    rom_gfx1 u_rom_gfx1 (
        .clk_a(clk_sys),
        .addr_a(tile_rom_addr),
        .q_a(tile_rom_data_b0),

        .clk_b(clk_sys),
        .addr_b(sprite_rom_addr),
        .q_b(sprite_rom_data_b0)
    );

    rom_gfx2 u_rom_gfx2 (
        .clk_a(clk_sys),
        .addr_a(tile_rom_addr),
        .q_a(tile_rom_data_b1),

        .clk_b(clk_sys),
        .addr_b(sprite_rom_addr),
        .q_b(sprite_rom_data_b1)
    );

    Ambush_Tiles tiles_inst (
        .clk_video(clk_sys),
        .h_blank(hblank),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .color_bank(color_bank_reg),
        .tile_code(vram_video_data_out),
        .tile_attr(attr_video_data_out),
        .scroll_data(scroll_video_data_out),
        .tile_rom_addr(tile_rom_addr),
        .tile_rom_data_b0(tile_rom_data_b0),
        .tile_rom_data_b1(tile_rom_data_b1),
        .tile_color_idx(tile_color_idx),
        .tile_priority(tile_priority)
    );

    Ambush_Sprites sprites_inst (
        .clk_video(clk_sys),
        .cen_video(cen_video),
        .reset(reset),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .color_bank(color_bank_reg),
        .sprite_ram_addr(sprite_video_addr),
        .sprite_vram_q0(sprite_vram_q0),
        .sprite_vram_q1(sprite_vram_q1),
        .sprite_vram_q2(sprite_vram_q2),
        .sprite_vram_q3(sprite_vram_q3),
        .sprite_rom_addr(sprite_rom_addr),
        .sprite_rom_data_b0(sprite_rom_data_b0),
        .sprite_rom_data_b1(sprite_rom_data_b1),
        .sprite_color_idx(sprite_color_idx)
    );

    always_comb begin
        if (tile_priority &&
            (tile_color_idx[1:0] != 2'b00)) begin
            final_color_idx = tile_color_idx;
        end else if (sprite_color_idx[1:0] != 2'b00) begin
            final_color_idx = sprite_color_idx;
        end else begin
            final_color_idx = tile_color_idx;
        end
    end

    prom_col1 u_prom_col1 (
        .clk(clk_sys),
        .addr(final_color_idx),
        .data(prom_col1_q)
    );

endmodule 