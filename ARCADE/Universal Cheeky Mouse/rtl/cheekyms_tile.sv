module cheekyms_tile (
    input  wire        clk_sys,
    input  wire        clk_vid_en,
    input  wire [8:0]  h_cnt,
    input  wire [8:0]  v_cnt,
    input  wire [7:0]  port_80_reg,
    input  wire        cpu_vram_wr,
    input  wire [9:0]  cpu_vram_addr,
    input  wire [7:0]  cpu_vram_data,
    output wire [7:0]  cpu_vram_rddata,
    output reg         tile_opaque,
    output reg         tile_prio,
    output reg  [2:0]  tile_rgb
);

    wire       flip            = port_80_reg[7];
    wire       palette_select  = port_80_reg[6];
    wire [2:0] scroll_y_offset = port_80_reg[5:3];

    wire in_man_area = flip
        ? ((h_cnt >= 9'd152 && h_cnt < 9'd184) && (v_cnt > 9'd40 && v_cnt < 9'd216))
        : ((h_cnt >= 9'd64  && h_cnt < 9'd96)  && (v_cnt > 9'd40 && v_cnt < 9'd216));

    wire [8:0] scrolled_v   = in_man_area ? (v_cnt + {6'd0, scroll_y_offset}) : v_cnt;
    wire       man_clip_out = in_man_area && (scrolled_v >= 9'd216);

    wire [4:0] tile_x        = flip ? ~h_cnt[7:3]      : h_cnt[7:3];
    wire [4:0] tile_y        = flip ? ~scrolled_v[7:3] : scrolled_v[7:3];
    wire [9:0] vid_vram_addr = {tile_y, tile_x};

    wire [2:0] sub_x = flip ? ~h_cnt[2:0]      : h_cnt[2:0];
    wire [2:0] sub_y = flip ? ~scrolled_v[2:0] : scrolled_v[2:0];

    reg [4:0] tile_color_id;
    always @(*) begin
        if (tile_x >= 5'd30) begin
            if (tile_y < 5'd12)      tile_color_id = 5'h15;
            else if (tile_y < 5'd20) tile_color_id = 5'h16;
            else                     tile_color_id = 5'h14;
        end else begin
            if ((tile_y == 5'd04) || (tile_y == 5'd27))
                tile_color_id = {palette_select, 4'hC};
            else
                tile_color_id = {palette_select, tile_x[4:1]};
        end
    end

    wire [7:0] vid_vram_data;

    dpram #(10,8) video_ram_inst (
        .clock_a   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (cpu_vram_wr),
        .address_a (cpu_vram_addr),
        .data_a    (cpu_vram_data),
        .q_a       (cpu_vram_rddata),
        .clock_b   (clk_sys),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vid_vram_addr),
        .data_b    (8'h00),
        .q_b       (vid_vram_data)
    );

    wire [10:0] tile_rom_addr = {vid_vram_data[7:0], sub_y[2:0]};
    wire [7:0]  tile_data_p0, tile_data_p1;

    tile_pattern_rom_low tile_rom_p0 (
        .clk  (clk_sys),
        .addr (tile_rom_addr),
        .data (tile_data_p0)
    );

    tile_pattern_rom_high tile_rom_p1 (
        .clk  (clk_sys),
        .addr (tile_rom_addr),
        .data (tile_data_p1)
    );

    reg bit_p0;
    reg bit_p1;
    always @(*) begin
        case (sub_x)
            3'd0: begin bit_p0 = tile_data_p0[7]; bit_p1 = tile_data_p1[7]; end
            3'd1: begin bit_p0 = tile_data_p0[6]; bit_p1 = tile_data_p1[6]; end
            3'd2: begin bit_p0 = tile_data_p0[5]; bit_p1 = tile_data_p1[5]; end
            3'd3: begin bit_p0 = tile_data_p0[4]; bit_p1 = tile_data_p1[4]; end
            3'd4: begin bit_p0 = tile_data_p0[3]; bit_p1 = tile_data_p1[3]; end
            3'd5: begin bit_p0 = tile_data_p0[2]; bit_p1 = tile_data_p1[2]; end
            3'd6: begin bit_p0 = tile_data_p0[1]; bit_p1 = tile_data_p1[1]; end
            3'd7: begin bit_p0 = tile_data_p0[0]; bit_p1 = tile_data_p1[0]; end
        endcase
    end
    wire [1:0] tile_dot = {bit_p1, bit_p0};

    wire [4:0] tile_color_addr = {tile_color_id[2:0], tile_dot};
    wire [7:0] prom_tile_m9d;
    wire [7:0] prom_tile_m8d;

    prom_tile_m9 u_prom_m9 (
        .clk  (clk_sys),
        .addr (tile_color_addr),
        .data (prom_tile_m9d)
    );

    prom_tile_m8 u_prom_m8 (
        .clk  (clk_sys),
        .addr (tile_color_addr),
        .data (prom_tile_m8d)
    );

    wire [7:0] active_tile_prom = tile_color_id[4] ? prom_tile_m8d : prom_tile_m9d;

    always @(*) begin
        tile_opaque = (!man_clip_out) && (tile_dot != 2'b00);
        if (tile_color_id[3:3]) begin
            tile_rgb  = active_tile_prom[6:4];
            tile_prio = active_tile_prom[7];
        end else begin
            tile_rgb  = active_tile_prom[2:0];
            tile_prio = active_tile_prom[3];
        end
    end

endmodule
