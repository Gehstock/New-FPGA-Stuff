//uses to many Ressources
module mouser_gfx (
    input  logic        clk_sys,
    input  logic        video_clken,
    input  logic        flip_x,
    input  logic        flip_y,
    
    input  logic [7:0]  vram_data,
    input  logic [7:0]  cram_data,
    input  logic [7:0]  spriteram_data,
    output logic [7:0]  spriteram_addr,
    
    output logic [9:0]  video_ram_addr,
    output logic [9:0]  video_cram_addr,
    
    input  logic [8:0]  h_count,
    input  logic [8:0]  v_count,
    
    output logic        gfx_p0,
    output logic        gfx_p1,
    output logic [3:0]  gfx_color_idx
);

    logic [7:0] eff_x;
    logic [7:0] eff_y;
    assign eff_x = flip_x ? (8'd255 - h_count[7:0]) : h_count[7:0];
    assign eff_y = flip_y ? (8'd255 - v_count[7:0]) : v_count[7:0];
    logic [8:0] v_next;
    logic [7:0] eff_y_next;
    assign v_next     = (v_count == 9'd259) ? 9'd0 : (v_count + 9'd1);
    assign eff_y_next = flip_y ? (8'd255 - v_next[7:0]) : v_next[7:0];
    logic [5:0] sprite_read_ptr;
    logic [3:0] sp_load_idx;
    logic [1:0] sp_load_byte;
    assign sp_load_idx  = sprite_read_ptr[5:2];
    assign sp_load_byte = sprite_read_ptr[1:0];

    always_ff @(posedge clk_sys) begin
        if (video_clken) begin
            if (h_count == 9'd255) begin
                sprite_read_ptr <= 6'd0;
            end else if (h_count >= 9'd256 && h_count < 9'd316) begin
                sprite_read_ptr <= sprite_read_ptr + 6'd1;
            end
        end
    end

    logic [7:0] fetch_spram_addr;
    always_comb begin
        if (h_count >= 9'd256 && h_count < 9'd316) begin
            if (sp_load_idx < 4'd7)
                fetch_spram_addr = 8'h84 + {2'b00, sprite_read_ptr};
            else
                fetch_spram_addr = 8'hC4 + {2'b00, (sprite_read_ptr - 6'd28)};
        end else begin
            fetch_spram_addr = {3'b000, eff_x[7:3]};
        end
    end
    assign spriteram_addr = fetch_spram_addr;

    logic [7:0] s_attrib0 [0:14];
    logic [7:0] s_attrib1 [0:14];
    logic [7:0] s_attrib2 [0:14];
    logic [7:0] s_attrib3 [0:14];

    always_ff @(posedge clk_sys) begin
        if (video_clken && h_count >= 9'd256 && h_count < 9'd316) begin
            case (sp_load_byte)
                2'b00: s_attrib0[sp_load_idx] <= spriteram_data;
                2'b01: s_attrib1[sp_load_idx] <= spriteram_data;
                2'b10: s_attrib2[sp_load_idx] <= spriteram_data;
                2'b11: s_attrib3[sp_load_idx] <= spriteram_data;
            endcase
        end
    end

    logic [7:0] scrolled_y;
    assign scrolled_y = eff_y + spriteram_data;
    assign video_ram_addr  = {scrolled_y[7:3], eff_x[7:3]};
    assign video_cram_addr = {eff_y[7:3], eff_x[7:3]};
    logic [9:0]  tile_code;
    logic [13:0] tile_rom_addr;
    logic [2:0]  tile_bit_sel;
    assign tile_code     = {cram_data[4], cram_data[5], vram_data};
    assign tile_rom_addr = {1'b0, tile_code, scrolled_y[2:0]};
    assign tile_bit_sel  = 3'd7 - eff_x[2:0];
    logic [5:0]  render_cnt;
    logic [3:0]  rend_idx;
    logic [1:0]  rend_step;
    logic        rend_active;
    assign rend_active = (h_count >= 9'd316 && h_count < 9'd376);
    assign rend_idx    = render_cnt[5:2];
    assign rend_step   = render_cnt[1:0];

    always_ff @(posedge clk_sys) begin
        if (video_clken) begin
            if (h_count == 9'd315)
                render_cnt <= 6'd0;
            else if (rend_active)
                render_cnt <= render_cnt + 6'd1;
        end
    end

    logic [7:0] r_sx, r_sy, r_dy;
    logic       r_en, r_y_hit, r_flip_x, r_flip_y;
    logic [3:0] r_py;
    logic       r_half;
    logic [13:0] sp_rom_addr; 
    always_comb begin
        r_sx     = s_attrib3[rend_idx];
        r_sy     = 8'hEF - s_attrib2[rend_idx];
        r_en     = s_attrib1[rend_idx][4];
        r_flip_x = s_attrib0[rend_idx][6];
        r_flip_y = s_attrib0[rend_idx][7];
        r_dy     = eff_y_next - r_sy;
        r_y_hit  = r_en && (r_dy < 8'd16);
        r_py     = r_flip_y ? (4'd15 - r_dy[3:0]) : r_dy[3:0];
		  r_half = (rend_step == 2'd1) ? r_flip_x : ~r_flip_x;
        sp_rom_addr = {1'b1, s_attrib1[rend_idx][5], s_attrib0[rend_idx][5:0], r_py[3], r_half, r_py[2:0]};
    end

    logic [13:0] mux_rom_addr;
    logic [7:0]  rom_data_p0;
    logic [7:0]  rom_data_p1;

    assign mux_rom_addr = rend_active ? sp_rom_addr : tile_rom_addr;

    gfx_rom1 gfx_rom_plane0 (
        .clk(clk_sys),
        .addr(mux_rom_addr),
        .data(rom_data_p0)
    );

    gfx_rom2 gfx_rom_plane1 (
        .clk(clk_sys),
        .addr(mux_rom_addr),
        .data(rom_data_p1)
    );

    (* ramstyle = "M9K" *) logic [5:0] linebuf [0:255];
    logic [5:0] sp_pixel_out;
    logic [7:0] base_x;
    assign base_x = (rend_step == 2'd1) ? r_sx : (r_sx + 8'd8);
	 
    always_ff @(posedge clk_sys) begin
        if (video_clken) begin
            if (h_count < 9'd256) begin
                sp_pixel_out   <= linebuf[eff_x];
                linebuf[eff_x] <= 6'd0;
            end else begin
                sp_pixel_out   <= 6'd0;
            end
            if (rend_active && r_y_hit && (rend_step == 2'd1 || rend_step == 2'd2)) begin
                for (int b = 0; b < 8; b++) begin
                    logic [2:0] bit_idx;
                    logic [7:0] dst_x;
                    logic       p0_val, p1_val;

                    bit_idx = r_flip_x ? b[2:0] : (3'd7 - b[2:0]);
                    p0_val  = rom_data_p0[bit_idx];
                    p1_val  = rom_data_p1[bit_idx];
                    if (p0_val || p1_val) begin
//                        dst_x = r_sx + ((rend_step == 2'd1) ? 8'd0 : 8'd8) + b[7:0];
								dst_x = base_x + b[2:0];
                        linebuf[dst_x] <= {s_attrib1[rend_idx][3:0], p1_val, p0_val};
                    end
                end
            end
        end
    end

    logic [2:0] tl_bit_d1;
    logic [3:0] tl_col_d1;

    always_ff @(posedge clk_sys) begin
        if (video_clken) begin
            tl_bit_d1 <= tile_bit_sel;
            tl_col_d1 <= cram_data[3:0];
        end
    end

    always_ff @(posedge clk_sys) begin
        if (video_clken) begin
            if (sp_pixel_out[1:0] != 2'b00) begin
                gfx_p0        <= sp_pixel_out[0];
                gfx_p1        <= sp_pixel_out[1];
                gfx_color_idx <= sp_pixel_out[5:2];
            end else begin
                gfx_p0        <= rom_data_p0[tl_bit_d1];
                gfx_p1        <= rom_data_p1[tl_bit_d1];
                gfx_color_idx <= tl_col_d1;
            end
        end
    end

endmodule
