//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module ac1_video (
    input  logic        clk_pixel, 
    input  logic        rst_n,
    input  logic [1:0]  system_mode, 
    output logic [10:0] vram_addr, 
    input  logic [7:0]  vram_data, 
    output logic        hsync, 
    output logic        vsync, 
    output logic        hblank,
    output logic        vblank,
    output logic        video_out 
);

    localparam int H_TOTAL       = 768; 
    localparam int H_SYNC_START  = 612; 
    localparam int H_SYNC_END    = 668; 
    localparam int V_TOTAL       = 312; 
    localparam int V_SYNC_START  = 290; 
    localparam int V_SYNC_END    = 293; 
    
    localparam int AC1_H_START   = 96;
    localparam int AC1_H_END     = 96 + 384; 

    logic [9:0] h_count; 
    logic [9:0] v_count; 

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= '0;
            v_count <= '0;
        end else begin
            if (h_count == (H_TOTAL - 1)) begin
                h_count <= '0;
                if (v_count == (V_TOTAL - 1))
                    v_count <= '0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    assign hsync  = (h_count >= H_SYNC_START && h_count < H_SYNC_END) ? 1'b0 : 1'b1;
    assign vsync  = (v_count >= V_SYNC_START && v_count < V_SYNC_END) ? 1'b0 : 1'b1;
    assign hblank = (h_count >= 576); 
    assign vblank = (v_count >= 280);
    logic [9:0] ac1_v_start;
    logic [9:0] ac1_v_end;
    logic mode_32;
    assign mode_32 = (system_mode != 2'd0); 
    
    always_comb begin
        if (mode_32) begin
            ac1_v_start = 10'd12;
            ac1_v_end   = 10'd268; 
        end else begin
            ac1_v_start = 10'd76;
            ac1_v_end   = 10'd204; 
        end
    end

    logic ac1_zone;
    assign ac1_zone = (h_count >= AC1_H_START && h_count < AC1_H_END) &&
                      (v_count >= ac1_v_start && v_count < ac1_v_end);

    logic [9:0] rel_y;
    always_comb begin
        if (ac1_zone) begin
            if (mode_32) rel_y = 10'd255 - (v_count - ac1_v_start); 
            else         rel_y = 10'd127 - (v_count - ac1_v_start); 
        end else begin
            rel_y = 10'd0;
        end
    end

    logic [2:0] char_x;
    logic [5:0] char_col;
    logic       load_shifter;

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            char_x   <= '0;
            char_col <= '0;
        end else begin
            if (h_count == (10'(AC1_H_START) - 10'd3)) begin
                char_x   <= '0;
                char_col <= '0;
            end else if (h_count >= (AC1_H_START - 10'd3) && h_count < (AC1_H_END - 10'd3)) begin
                if (char_x == 3'd5) begin
                    char_x   <= '0;
                    char_col <= char_col + 1'b1;
                end else begin
                    char_x   <= char_x + 1'b1;
                end
            end
        end
    end


    assign load_shifter = (char_x == 3'd5);
    logic [5:0] vram_col_addr;
    assign vram_col_addr = 6'd63 - char_col;
    assign vram_addr     = 11'(11'(vram_col_addr) + (11'(rel_y[7:3]) << 6));
    logic [2:0] char_y;
    assign char_y = 3'(v_count - ac1_v_start); 
    logic [10:0] font_rom_addr;
    assign font_rom_addr = {vram_data[7:0], char_y};


    logic [7:0] font_data_16, font_data_128, font_data_256, font_data_scch;
    font_16_rom font_16_inst   (
		.clk(clk_pixel), 
		.addr(font_rom_addr[9:0]), 
		.data(font_data_16)
	);
	
    font_128_rom font_128_inst (
		.clk(clk_pixel), 
		.addr(font_rom_addr[9:0]), 
		.data(font_data_128)
	);
	
    font_256_rom font_256_inst (
		.clk(clk_pixel), 
		.addr(font_rom_addr),       
		.data(font_data_256)
	);
	
    font_scch_rom font_scch_inst(
		.clk(clk_pixel), 
		.addr(font_rom_addr),       
		.data(font_data_scch)
	);

    logic [7:0] font_byte;
    always_comb begin
        case (system_mode)
            2'b00:   font_byte = font_data_16;
            2'b01:   font_byte = font_data_128;
            2'b10:   font_byte = font_data_256;
            2'b11:   font_byte = font_data_scch;
            default: font_byte = 8'h00;
        endcase
    end


    logic [5:0] shift_reg;
    logic       ac1_zone_reg;

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg    <= '0;
            video_out    <= 1'b0;
            ac1_zone_reg <= 1'b0;
        end else begin
            ac1_zone_reg <= ac1_zone;
            if (load_shifter) begin
                shift_reg <= font_byte[5:0]; 
            end else begin
                shift_reg <= {1'b0, shift_reg[5:1]};
            end
            if (ac1_zone_reg) begin
                video_out <= shift_reg[0];
            end else begin
                video_out <= 1'b0;
            end
        end
    end

endmodule
`default_nettype wire
