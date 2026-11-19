`timescale 1ns / 1ps
`default_nettype none

module huebler_grafik_video (
    input  logic        clk_9mhz,
	 input  logic        clk_2_5mhz,
    input  logic        rst_n,
    
    input  logic        vram_enable,
    input  logic        vram_we,
    input  logic [10:0] vram_addr,
    input  logic [7:0]  vram_din,
    output logic [7:0]  vram_dout,
    
    output logic        hsync,         
    output logic        vsync,         
    output logic        hblank,        
    output logic        vblank,        
    output logic 			video_out
);

    localparam int H_ACTIVE = 384;
    localparam int H_TOTAL  = 576;     
    localparam int H_SYNC_W = 44;      
    localparam int H_FP     = 24;      

    localparam int V_ACTIVE = 240;
    localparam int V_TOTAL  = 320;     
    localparam int V_SYNC_W = 3;       
    localparam int V_FP     = 10;      

    logic [9:0] h_cnt;
    logic [8:0] v_cnt;

    logic [5:0] sx;
    logic [2:0] x_pixel;
    logic [4:0] y_div_10;
    logic [3:0] line_mod_10;

    // Schlanke, synchrone Zähler-Pipeline ersetzt komplexe Divisions-Logik
    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt       <= '0;
            sx          <= '0;
            x_pixel     <= '0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt   <= '0;
                sx      <= '0;
                x_pixel <= '0;
            end else begin
                h_cnt   <= h_cnt + 1'b1;
                if (h_cnt < H_ACTIVE - 1) begin
                    if (x_pixel == 3'd5) begin
                        x_pixel <= '0;
                        sx      <= sx + 1'b1;
                    end else begin
                        x_pixel <= x_pixel + 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt       <= '0;
            y_div_10    <= '0;
            line_mod_10 <= '0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt       <= '0;
                    y_div_10    <= '0;
                    line_mod_10 <= '0;
                end else begin
                    v_cnt       <= v_cnt + 1'b1;
                    if (v_cnt < V_ACTIVE - 1) begin
                        if (line_mod_10 == 4'd9) begin
                            line_mod_10 <= '0;
                            y_div_10    <= y_div_10 + 1'b1;
                        end else begin
                            line_mod_10 <= line_mod_10 + 1'b1;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin
            hsync  <= 1'b1;
            vsync  <= 1'b1;
            hblank <= 1'b1;
            vblank <= 1'b1;
        end else begin
            hsync  <= ~((h_cnt >= (H_ACTIVE + H_FP)) && (h_cnt < (H_ACTIVE + H_FP + H_SYNC_W)));
            vsync  <= ~((v_cnt >= (V_ACTIVE + V_FP)) && (v_cnt < (V_ACTIVE + V_FP + V_SYNC_W)));
            hblank <= (h_cnt >= H_ACTIVE);
            vblank <= (v_cnt >= V_ACTIVE);
        end
    end

    wire video_active = (!hblank && !vblank);
    wire [10:0] vram_rd_addr = 11'((11'(y_div_10) * 11'd64) + 11'(sx));
    logic [7:0] vram_rd_data;

    dpram #(
        .address_width (11),
        .data_width    (8)
    ) vram_inst (
        .clock_a   (clk_2_5mhz), 
        .enable_a  (vram_enable),
        .wren_a    (vram_we),
        .address_a (vram_addr & 11'h7FF),
        .data_a    (vram_din),
        .q_a       (vram_dout),
		  .clock_b     (clk_9mhz),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vram_rd_addr & 11'h7FF),
        .data_b    (8'h00),
        .q_b       (vram_rd_data)
    );

    wire [9:0] chargen_addr = {vram_rd_data[6:0], line_mod_10[2:0]};
    logic [7:0] font_byte;

    hemcfont chargen_inst(
        .clk(clk_9mhz),
        .addr(chargen_addr & 10'h3FF),
        .data(font_byte)
    );

    logic [2:0] x_pixel_q;
    logic [3:0] line_mod_10_q;
    logic [7:0] vram_rd_data_q;

    always_ff @(posedge clk_9mhz) begin
        x_pixel_q       <= x_pixel;
        line_mod_10_q   <= line_mod_10;
        vram_rd_data_q  <= vram_rd_data;
    end

    wire raw_pixel = font_byte[3'd7 - x_pixel_q];
    wire invert_bit = vram_rd_data_q[7];

    logic color_bit;
    always_comb begin
        if (line_mod_10_q > 4'd7) begin
            color_bit = 1'b0 ^ invert_bit;
        end else begin
            color_bit = raw_pixel ^ invert_bit;
        end
    end

    always_comb begin
        if (video_active && color_bit) begin
            video_out = 1'b1;
        end else begin
            video_out = 1'b0;
        end
    end

endmodule
`default_nettype wire
