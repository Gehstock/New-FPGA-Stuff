//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module bcs3_video (
    input  logic        clk_sys,        
    input  logic        reset_n,        

    input  logic        video_ce,       
    input  logic        video_wr,
    input  logic [11:0] video_addr,     
    input  logic [7:0]  video_data_in,
    output logic [7:0]  video_data_out,
    output logic        video_wait_n,

    input  logic        video_r_ce,     
    input  logic        zx_n_ce,        
    output logic [7:0]  hack_bus_data,  

    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic        video_out
);

    localparam [9:0] S_INIT         = 10'h050; 
    localparam [5:0] S_COLS         = 6'd28;     
    localparam [4:0] S_ROWS         = 5'd12;     
    localparam [9:0] H_TOTAL_VAL    = 10'd320;
    localparam [9:0] H_SYNC_START   = 10'd250;   
    localparam [9:0] H_SYNC_END     = 10'd280;
    localparam [9:0] V_TOTAL        = 10'd312;

    localparam [9:0] H_ACTIVE_PIXELS = S_COLS * 4'd8; 
    localparam [9:0] V_ACTIVE_PIXELS = S_ROWS * 4'd10; 

    logic [9:0] vga_read_addr;
    logic [7:0] vram_char_code;

    dpram #(
        .address_width (10), .data_width (8)
    ) u_video_ram (
        .clock     (clk_sys),
        .enable_a  (video_addr[11:10] == 2'b11), 
        .wren_a    (video_wr),
        .address_a (video_addr[9:0]),
        .data_a    (video_data_in),
        .q_a       (video_data_out),
        
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vga_read_addr),
        .data_b    (8'h00),
        .q_b       (vram_char_code)
    );

    assign hack_bus_data = video_r_ce ? 8'h00 : 
                           zx_n_ce    ? 8'hF7 : 8'hFF;

    logic [9:0] h_cnt;
    logic [9:0] v_cnt;
    logic       h_blank_trigger;
    logic       display_on;

    always_ff @(posedge clk_sys or negedge reset_n) begin
        if (!reset_n) begin
            h_cnt           <= '0;
            v_cnt           <= '0;
            h_blank_trigger <= 1'b0;
        end else begin
            h_blank_trigger <= 1'b0;
            
            if (h_cnt >= H_TOTAL_VAL - 1) begin
                h_cnt           <= '0;
                h_blank_trigger <= 1'b1; 
                v_cnt           <= (v_cnt >= V_TOTAL - 1) ? '0 : v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    assign hsync  = (h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END); 
    assign vsync  = (v_cnt >= 10'd290) && (v_cnt < 10'd295);         
    assign hblank = (h_cnt >= H_ACTIVE_PIXELS);
    assign vblank = (v_cnt >= V_ACTIVE_PIXELS);
    assign display_on = !hblank && !vblank;

    logic [5:0] char_col;
    logic [5:0] char_row;
    logic [3:0] ra_cnt;
    logic [2:0] pixel_bit_sel;

    assign char_col      = h_cnt[8:3];     
    assign pixel_bit_sel = h_cnt[2:0];     
    assign char_row      = 6'(v_cnt / 10'd10);
    assign ra_cnt        = 4'(v_cnt % 10'd10);

    assign vga_read_addr = S_INIT + (char_row * 5'd28) + char_col;

    logic [10:0] font_rom_addr;
    logic [7:0]  font_rom_data;
    logic [7:0]  gfx_byte; 
    logic [2:0]  rat_calc;

    assign rat_calc      = 3'((ra_cnt + 4'd1) & 4'h7);
    assign font_rom_addr = {vram_char_code[6:0], rat_calc};

    char_24 u_font_rom (
        .clk  (clk_sys),
        .addr (font_rom_addr), 
        .data (font_rom_data)
    );

    logic       display_on_d1, display_on_d2;
    logic [3:0] ra_cnt_d1, ra_cnt_d2;
    logic [2:0] pixel_bit_sel_d1, pixel_bit_sel_d2;

    always_ff @(posedge clk_sys or negedge reset_n) begin
        if (!reset_n) begin
            display_on_d1    <= 1'b0;
            display_on_d2    <= 1'b0;
            ra_cnt_d1        <= '0;
            ra_cnt_d2        <= '0;
            pixel_bit_sel_d1 <= '0;
            pixel_bit_sel_d2 <= '0;
        end else begin
            display_on_d1    <= display_on;
            display_on_d2    <= display_on_d1;
            ra_cnt_d1        <= ra_cnt;
            ra_cnt_d2        <= ra_cnt_d1;
            pixel_bit_sel_d1 <= pixel_bit_sel;
            pixel_bit_sel_d2 <= pixel_bit_sel_d1;
        end
    end

    always_comb begin
        video_out = 1'b0;
        gfx_byte  = 8'h00;

        if (display_on_d2) begin
            if (ra_cnt_d2 < 4'd8) begin
                gfx_byte  = font_rom_data ^ 8'hFF;
                video_out = gfx_byte[3'd7 - pixel_bit_sel_d2];
            end else begin
                gfx_byte  = 8'hFF;
                video_out = gfx_byte[3'd7 - pixel_bit_sel_d2];
            end
        end
    end

    logic wait_state;

    always_ff @(posedge clk_sys or negedge reset_n) begin
        if (!reset_n) begin
            wait_state <= 1'b0;
        end else begin
            if (video_ce && (video_addr[11:8] == 4'h4)) begin
                wait_state <= 1'b1;
            end 
            else if (h_blank_trigger) begin
                wait_state <= 1'b0;
            end
        end
    end
    
    assign video_wait_n = !wait_state;

endmodule
`default_nettype wire
