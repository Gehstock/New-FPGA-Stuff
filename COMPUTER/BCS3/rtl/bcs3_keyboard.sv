//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module bcs3_keyboard_sys (
    input  logic        clk,          
    input  logic        rst_n,        
    
    input  logic [9:0]  addr_offset,  
    input  logic        rd_n,         
    output logic [7:0]  data_out,     
    
    input  logic        cassette_in,  
    
    input  logic        ps2_kbd_clk,
    input  logic        ps2_kbd_data,
    output logic        NMI_n
);

    logic [3:0] key_matrix [0:9];

    logic [9:0] inverted_offset;
    assign inverted_offset = addr_offset ^ 10'h3FF; 

    logic [3:0] combined_keys;

    always_comb begin
        combined_keys = 4'h0; 
        
        if (inverted_offset[0]) combined_keys |= key_matrix[0];
        if (inverted_offset[1]) combined_keys |= key_matrix[1];
        if (inverted_offset[2]) combined_keys |= key_matrix[2];
        if (inverted_offset[3]) combined_keys |= key_matrix[3];
        if (inverted_offset[4]) combined_keys |= key_matrix[4];
        if (inverted_offset[5]) combined_keys |= key_matrix[5];
        if (inverted_offset[6]) combined_keys |= key_matrix[6];
        if (inverted_offset[7]) combined_keys |= key_matrix[7];
        if (inverted_offset[8]) combined_keys |= key_matrix[8];
        if (inverted_offset[9]) combined_keys |= key_matrix[9];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'hFF;
        end else begin
            if (!rd_n) begin
                data_out[3:0] <= combined_keys;
                data_out[6:4] <= 3'b000; 
                
                if (addr_offset == 10'h000) begin
                    data_out[7] <= cassette_in;
                end else begin
                    data_out[7] <= 1'b0; 
                end
            end else begin
                data_out <= 8'hFF; 
            end
        end
    end

    logic [3:0]  clk_filter;
    logic        ps2_clk_clean;
    logic        ps2_clk_edge;
    logic [7:0]  shift_reg;
    logic [3:0]  bit_cnt;
    logic [7:0]  ps2_code;
    logic        ps2_new_code;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            clk_filter    <= 4'b1111;
            ps2_clk_clean <= 1'b1;
        end else begin
            clk_filter <= {clk_filter[2:0], ps2_kbd_clk};
            if (clk_filter == 4'b0000)      ps2_clk_clean <= 1'b0;
            else if (clk_filter == 4'b1111) ps2_clk_clean <= 1'b1;
        end
    end

    logic ps2_clk_clean_last;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) ps2_clk_clean_last <= 1'b1;
        else         ps2_clk_clean_last <= ps2_clk_clean;
    end
    assign ps2_clk_edge = ps2_clk_clean_last && !ps2_clk_clean;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg    <= 8'h00;
            bit_cnt      <= 4'd0;
            ps2_code     <= 8'h00;
            ps2_new_code <= 1'b0;
        end else begin
            ps2_new_code <= 1'b0;
            if (ps2_clk_edge) begin
                if (bit_cnt == 4'd0) begin
                    if (!ps2_kbd_data) begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end else if (bit_cnt >= 4'd1 && bit_cnt <= 4'd8) begin
                    shift_reg <= {ps2_kbd_data, shift_reg[7:1]};
                    bit_cnt   <= bit_cnt + 1'b1;
                end else if (bit_cnt == 4'd9) begin
                    bit_cnt <= bit_cnt + 1'b1;
                end else if (bit_cnt == 4'd10) begin
                    bit_cnt <= 4'd0;
                    if (ps2_kbd_data) begin
                        ps2_code     <= shift_reg; 
                        ps2_new_code <= 1'b1;           
                    end
                end
            end
        end
    end

    logic is_break;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 10; i++) key_matrix[i] <= 4'h0;
            is_break <= 1'b0;
            NMI_n    <= 1'b1; // NMI ist im Reset inaktiv (High)
        end else if (ps2_new_code) begin
            if (ps2_code == 8'hF0) begin
                is_break <= 1'b1; 
            end else begin
                case (ps2_code)
                    8'h76: begin NMI_n <= is_break ? 1'b1 : 1'b0; end // ESC generiert NMI (Low-aktiv)
                    
                    8'h3C: begin key_matrix[0][0] <= is_break ? 1'b0 : 1'b1; end // U
                    8'h42: begin key_matrix[0][1] <= is_break ? 1'b0 : 1'b1; end // K - :
                    8'h1C: begin key_matrix[0][2] <= is_break ? 1'b0 : 1'b1; end // A - &
                    8'h45: begin key_matrix[0][3] <= is_break ? 1'b0 : 1'b1; end // 0 - SPACE

                    8'h2A: begin key_matrix[1][0] <= is_break ? 1'b0 : 1'b1; end // V
                    8'h4B: begin key_matrix[1][1] <= is_break ? 1'b0 : 1'b1; end // L - ;
                    8'h32: begin key_matrix[1][2] <= is_break ? 1'b0 : 1'b1; end // B - 				  
                    8'h16: begin key_matrix[1][3] <= is_break ? 1'b0 : 1'b1; end // 1 - !

                    8'h1D: begin key_matrix[2][0] <= is_break ? 1'b0 : 1'b1; end // W
                    8'h3A: begin key_matrix[2][1] <= is_break ? 1'b0 : 1'b1; end // M - <
                    8'h21: begin key_matrix[2][2] <= is_break ? 1'b0 : 1'b1; end // C - (
                    8'h1E: begin key_matrix[2][3] <= is_break ? 1'b0 : 1'b1; end // 2 - "

                    8'h22: begin key_matrix[3][0] <= is_break ? 1'b0 : 1'b1; end // X
                    8'h31: begin key_matrix[3][1] <= is_break ? 1'b0 : 1'b1; end // N - =
                    8'h23: begin key_matrix[3][2] <= is_break ? 1'b0 : 1'b1; end // D - )
                    8'h26: begin key_matrix[3][3] <= is_break ? 1'b0 : 1'b1; end // 3 - #

                    8'h1A: begin key_matrix[4][0] <= is_break ? 1'b0 : 1'b1; end // Y - German layout
                    8'h44: begin key_matrix[4][1] <= is_break ? 1'b0 : 1'b1; end // O - >
                    8'h24: begin key_matrix[4][2] <= is_break ? 1'b0 : 1'b1; end // E - *
                    8'h25: begin key_matrix[4][3] <= is_break ? 1'b0 : 1'b1; end // 4 - $

                    8'h35: begin key_matrix[5][0] <= is_break ? 1'b0 : 1'b1; end // Z - German layout
                    8'h4D: begin key_matrix[5][1] <= is_break ? 1'b0 : 1'b1; end // P - ?
                    8'h2B: begin key_matrix[5][2] <= is_break ? 1'b0 : 1'b1; end // F - +
                    8'h2E: begin key_matrix[5][3] <= is_break ? 1'b0 : 1'b1; end // 5 - %

                    8'h29: begin key_matrix[6][0] <= is_break ? 1'b0 : 1'b1; end // Space
                    8'h15: begin key_matrix[6][1] <= is_break ? 1'b0 : 1'b1; end // Q - @
                    8'h34: begin key_matrix[6][2] <= is_break ? 1'b0 : 1'b1; end // G - ,
                    8'h36: begin key_matrix[6][3] <= is_break ? 1'b0 : 1'b1; end // 6 - &

                    8'h66: begin key_matrix[7][0] <= is_break ? 1'b0 : 1'b1; end // Backspace
                    8'h2D: begin key_matrix[7][1] <= is_break ? 1'b0 : 1'b1; end // R - A
                    8'h33: begin key_matrix[7][2] <= is_break ? 1'b0 : 1'b1; end // H - -
                    8'h3D: begin key_matrix[7][3] <= is_break ? 1'b0 : 1'b1; end // 7 - '

                    8'h5A: begin key_matrix[8][0] <= is_break ? 1'b0 : 1'b1; end // Enter
                    8'h1B: begin key_matrix[8][1] <= is_break ? 1'b0 : 1'b1; end // S - B
                    8'h43: begin key_matrix[8][2] <= is_break ? 1'b0 : 1'b1; end // I - Right
                    8'h3E: begin key_matrix[8][3] <= is_break ? 1'b0 : 1'b1; end // 8 - (

                    8'h12: begin key_matrix[9][0] <= is_break ? 1'b0 : 1'b1; end // Left Shift
                    8'h59: begin key_matrix[9][0] <= is_break ? 1'b0 : 1'b1; end // Right Shift
                    8'h2C: begin key_matrix[9][1] <= is_break ? 1'b0 : 1'b1; end // T - C
                    8'h3B: begin key_matrix[9][2] <= is_break ? 1'b0 : 1'b1; end // J - /
                    8'h46: begin key_matrix[9][3] <= is_break ? 1'b0 : 1'b1; end // 9 - )
                    default: ;
                endcase
                is_break <= 1'b0; 
            end
        end
    end

endmodule
`default_nettype wire
