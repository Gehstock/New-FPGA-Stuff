`timescale 1ns / 1ps

module draw_text (
    input  logic        clk_12M,
    input  logic        blank,
    input  logic [9:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [7:0]  m_alpha_num_ram,
    output logic [10:0] video_alpha_addr,
    output logic        text_pixel
);


    logic [8:0] text_line_div;
    logic [1:0] text_line_raw;
    logic [1:0] text_line_xor;
    logic [4:0] text_char_col;
    assign text_line_div = v_cnt - 9'd136;    
    assign text_line_raw = text_line_div[5:4];
    assign text_line_xor = text_line_raw ^ 2'b01;
    assign text_char_col = h_cnt[8:4]; 
    assign video_alpha_addr = {4'b0000, text_line_xor, text_char_col};
    logic [8:0] chars_rom_addr;
    logic [7:0] chars_rom_data;
    logic [2:0] v_cnt_inv;
    logic [2:0] v_cnt_inv_d1;
    assign v_cnt_inv = ~text_line_div[2:0];
    assign chars_rom_addr = {m_alpha_num_ram[5:0], v_cnt_inv_d1};

    h2 h2_inst (
        .clk(clk_12M),
        .addr(chars_rom_addr),
        .data(chars_rom_data)
    );

    logic [2:0] text_rom_bit_sel_d1;
    logic [2:0] text_rom_bit_sel_d2;
    logic text_window_raw;
    logic text_window_d1;
    logic text_window_d2;
    logic text_half_mask_raw;
    logic text_half_mask_d1;
    logic text_half_mask_d2;
    assign text_window_raw = (!blank && (v_cnt >= 9'd136) && (v_cnt < 9'd200));
    assign text_half_mask_raw = (text_line_div[3] == 1'b0); 

    always_ff @(posedge clk_12M) begin
        v_cnt_inv_d1        <= v_cnt_inv;
        text_rom_bit_sel_d1 <= h_cnt[3:1];
        text_window_d1      <= text_window_raw;
        text_half_mask_d1   <= text_half_mask_raw;
        text_rom_bit_sel_d2 <= text_rom_bit_sel_d1;
        text_window_d2      <= text_window_d1;
        text_half_mask_d2   <= text_half_mask_d1;
    end

    always_comb begin
        if (text_window_d2 && text_half_mask_d2) begin
            text_pixel = chars_rom_data[3'd7 - text_rom_bit_sel_d2];
        end else begin
            text_pixel = 1'b0;
        end
    end

endmodule
