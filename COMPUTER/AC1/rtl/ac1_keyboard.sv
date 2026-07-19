//Gehstock 2026
`timescale 1ns / 1ps
`default_nettype none

module ac1_keyboard (
    input  logic        clk,
    input  logic        rst_n,                
    input  logic        ps2_kbd_clk,
    input  logic        ps2_kbd_data,  
    output logic [7:0]  ascii_out,
    output logic        nmi_n
);

    logic [2:0] clk_sync;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_sync <= 3'b111;
        else        clk_sync <= {clk_sync[1:0], ps2_kbd_clk};
    end
    
    wire clk_fall = (clk_sync[2:1] == 2'b10); 
    logic [10:0] shift_reg;
    logic [3:0]  bit_count;
    logic        scancode_ready;
    logic [7:0]  raw_scancode;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg      <= '0;
            bit_count      <= '0;
            scancode_ready <= 1'b0;
            raw_scancode   <= '0;
        end else begin
            scancode_ready <= 1'b0;
            if (clk_fall) begin
                shift_reg <= {ps2_kbd_data, shift_reg[10:1]};
                
                if (bit_count == 4'd10) begin
                    bit_count <= '0;
                    raw_scancode   <= shift_reg[9:2]; 
                    scancode_ready <= 1'b1;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end

    logic shift_active;
    logic ctrl_active;
    logic is_break;
    logic [7:0] current_ascii;
    logic [7:0] lut_ascii;
    logic [2:0] nmi_timer; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_active  <= 1'b0;
            ctrl_active   <= 1'b0;
            is_break      <= 1'b0;
            current_ascii <= 8'h00;
            nmi_n         <= 1'b1;
            nmi_timer     <= 3'd0;
        end else begin
            if (nmi_timer > 0) begin
                nmi_timer <= nmi_timer - 1'b1;
                nmi_n     <= 1'b0;
            end else begin
                nmi_n     <= 1'b1;
            end
            if (scancode_ready) begin
                if (raw_scancode == 8'hF0) begin
                    is_break <= 1'b1;
                end else begin
                    if (raw_scancode == 8'h12 || raw_scancode == 8'h59) begin
                        shift_active <= !is_break;
                        is_break     <= 1'b0;
                    end else if (raw_scancode == 8'h14) begin//ESC = BREAK
                        ctrl_active  <= !is_break;
                        is_break     <= 1'b0;
                    end else begin
                        if (!is_break) begin
                            if (raw_scancode == 8'h76) begin
                                nmi_timer <= 3'd4;
                            end
                            
                            if (raw_scancode == 8'h29)      current_ascii <= 8'hA0; // Space
                            else if (raw_scancode == 8'h5A) current_ascii <= 8'h8D; // Enter
                            else if (raw_scancode == 8'h66) current_ascii <= 8'h88; // Backspace
                            else                            current_ascii <= lut_ascii;
                        end else begin
                            current_ascii <= 8'h00;
                            is_break      <= 1'b0;
                        end
                    end
                end
            end
        end
    end

    assign ascii_out = current_ascii;

    always_comb begin
        case (raw_scancode)
            8'h45: lut_ascii = shift_active ? 8'hA0 : 8'hB0; // '0'
            8'h16: lut_ascii = shift_active ? 8'hA1 : 8'hB1; // '1'
            8'h1E: lut_ascii = shift_active ? 8'hA2 : 8'hB2; // '2'
            8'h26: lut_ascii = shift_active ? 8'hA3 : 8'hB3; // '3'
            8'h25: lut_ascii = shift_active ? 8'hA4 : 8'hB4; // '4'
            8'h2E: lut_ascii = shift_active ? 8'hA5 : 8'hB5; // '5'
            8'h36: lut_ascii = shift_active ? 8'hA6 : 8'hB6; // '6'
            8'h3D: lut_ascii = shift_active ? 8'hA7 : 8'hB7; // '7'
            8'h3E: lut_ascii = shift_active ? 8'hA8 : 8'hB8; // '8'
            8'h46: lut_ascii = shift_active ? 8'hA9 : 8'hB9; // '9'
            8'h4C: lut_ascii = shift_active ? 8'hAA : 8'hBA; // ':'
            8'h52: lut_ascii = shift_active ? 8'hAB : 8'hBB; // ';'
            8'h41: lut_ascii = shift_active ? 8'hBC : 8'hAC; // ','
            8'h4E: lut_ascii = shift_active ? 8'hBD : 8'hAD; // '-'
            8'h49: lut_ascii = shift_active ? 8'hBE : 8'hAE; // '.'
            8'h4A: lut_ascii = shift_active ? 8'hBF : 8'hAF; // '/'
            8'h55: lut_ascii = ctrl_active ? 8'h80 : (shift_active ? 8'hE0 : 8'hC0); // '='  '@'
            8'h1C: lut_ascii = ctrl_active ? 8'h81 : (shift_active ? 8'hE1 : 8'hC1); // 'A'
            8'h32: lut_ascii = ctrl_active ? 8'h82 : (shift_active ? 8'hE2 : 8'hC2); // 'B'
            8'h21: lut_ascii = ctrl_active ? 8'h83 : (shift_active ? 8'hE3 : 8'hC3); // 'C'
            8'h23: lut_ascii = ctrl_active ? 8'h84 : (shift_active ? 8'hE4 : 8'hC4); // 'D'
            8'h24: lut_ascii = ctrl_active ? 8'h85 : (shift_active ? 8'hE5 : 8'hC5); // 'E'
            8'h2B: lut_ascii = ctrl_active ? 8'h86 : (shift_active ? 8'hE6 : 8'hC6); // 'F'
            8'h34: lut_ascii = ctrl_active ? 8'h87 : (shift_active ? 8'hE7 : 8'hC7); // 'G'
            8'h33: lut_ascii = ctrl_active ? 8'h88 : (shift_active ? 8'hE8 : 8'hC8); // 'H'
            8'h43: lut_ascii = ctrl_active ? 8'h89 : (shift_active ? 8'hE9 : 8'hC9); // 'I'
            8'h3B: lut_ascii = ctrl_active ? 8'h8A : (shift_active ? 8'hEA : 8'hCA); // 'J'
            8'h42: lut_ascii = ctrl_active ? 8'h8B : (shift_active ? 8'hEB : 8'hCB); // 'K'
            8'h4B: lut_ascii = ctrl_active ? 8'h8C : (shift_active ? 8'hEC : 8'hCC); // 'L'
            8'h3A: lut_ascii = ctrl_active ? 8'h8D : (shift_active ? 8'hED : 8'hCD); // 'M'
            8'h31: lut_ascii = ctrl_active ? 8'h8E : (shift_active ? 8'hEE : 8'hCE); // 'N'
            8'h44: lut_ascii = ctrl_active ? 8'h8F : (shift_active ? 8'hEF : 8'hCF); // 'O'
            8'h4D: lut_ascii = ctrl_active ? 8'h90 : (shift_active ? 8'hF0 : 8'hD0); // 'P'
            8'h15: lut_ascii = ctrl_active ? 8'h91 : (shift_active ? 8'hF1 : 8'hD1); // 'Q'
            8'h2D: lut_ascii = ctrl_active ? 8'h92 : (shift_active ? 8'hF2 : 8'hD2); // 'R'
            8'h1B: lut_ascii = ctrl_active ? 8'h93 : (shift_active ? 8'hF3 : 8'hD3); // 'S'
            8'h2C: lut_ascii = ctrl_active ? 8'h94 : (shift_active ? 8'hF4 : 8'hD4); // 'T'
            8'h3C: lut_ascii = ctrl_active ? 8'h95 : (shift_active ? 8'hF5 : 8'hD5); // 'U'
            8'h2A: lut_ascii = ctrl_active ? 8'h96 : (shift_active ? 8'hF6 : 8'hD6); // 'V'
            8'h1D: lut_ascii = ctrl_active ? 8'h97 : (shift_active ? 8'hF7 : 8'hD7); // 'W'
            8'h22: lut_ascii = ctrl_active ? 8'h98 : (shift_active ? 8'hF8 : 8'hD8); // 'X'
            8'h1A: lut_ascii = ctrl_active ? 8'h99 : (shift_active ? 8'hF9 : 8'hD9); // 'Y'
            8'h35: lut_ascii = ctrl_active ? 8'h9A : (shift_active ? 8'hFA : 8'hDA); // 'Z'
            8'h54: lut_ascii = ctrl_active ? 8'h9B : (shift_active ? 8'hFB : 8'hDB); // '['
            8'h5D: lut_ascii = ctrl_active ? 8'h9C : (shift_active ? 8'hFC : 8'hDC); // '\'
            8'h5B: lut_ascii = ctrl_active ? 8'h9D : (shift_active ? 8'hFD : 8'hDD); // ']'
            8'h0E: lut_ascii = ctrl_active ? 8'h9E : (shift_active ? 8'hFE : 8'hDE); // '^'
            8'h6B: lut_ascii = ctrl_active ? 8'h9F : (shift_active ? 8'hFF : 8'hDF); // '_'

            default: lut_ascii = 8'h00;
        endcase
    end

endmodule
