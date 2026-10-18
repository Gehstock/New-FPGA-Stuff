module mole_inputs (
    input  logic        clk_sys,
    input  logic        rst_n,
    
    input  logic        ps2_kbd_clk,
    input  logic        ps2_kbd_data,
    
    output logic [9:1]  p1_buttons,
    output logic [9:1]  p2_buttons,
    output logic        coin_input,
    output logic        start1_button,
    output logic        start2_button
);

    logic [3:0]  clk_filter;
    logic        clk_edge;
    
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_filter <= 4'b1111;
            clk_edge   <= 1'b0;
        end else begin
            clk_filter <= {clk_filter[2:0], ps2_kbd_clk};
            clk_edge   <= (clk_filter == 4'b1100);
        end
    end

    logic [10:0] shift_reg;
    logic [3:0]  bit_cnt;
    logic        ready;
    logic [7:0]  scancode;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 11'b0;
            bit_cnt   <= 4'd0;
            ready     <= 1'b0;
            scancode  <= 8'h00;
        end else if (clk_edge) begin
            shift_reg <= {ps2_kbd_data, shift_reg[10:1]};
            if (bit_cnt == 4'd10) begin
                bit_cnt  <= 4'd0;
                scancode <= shift_reg[9:2];
                ready    <= 1'b1;
            end else begin
                bit_cnt  <= bit_cnt + 4'd1;
                ready    <= 1'b0;
            end
        end else begin
            ready <= 1'b0;
        end
    end

    logic is_release;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            is_release    <= 1'b0;
            p1_buttons    <= 9'b0;
            p2_buttons    <= 9'b0;
            coin_input    <= 1'b0;
            start1_button <= 1'b0;
            start2_button <= 1'b0;
        end else if (ready) begin
            if (scancode == 8'hF0) begin
                is_release <= 1'b1;
            end else begin
                is_release <= 1'b0;
                case (scancode)
                    8'h1A: p1_buttons[1] <= !is_release;
                    8'h22: p1_buttons[2] <= !is_release;
                    8'h21: p1_buttons[3] <= !is_release;
                    8'h1C: p1_buttons[4] <= !is_release;
                    8'h1B: p1_buttons[5] <= !is_release;
                    8'h23: p1_buttons[6] <= !is_release;
                    8'h15: p1_buttons[7] <= !is_release;
                    8'h1D: p1_buttons[8] <= !is_release;
                    8'h24: p1_buttons[9] <= !is_release;

                    8'h69: p2_buttons[1] <= !is_release;
                    8'h72: p2_buttons[2] <= !is_release;
                    8'h7A: p2_buttons[3] <= !is_release;
                    8'h6B: p2_buttons[4] <= !is_release;
                    8'h73: p2_buttons[5] <= !is_release;
                    8'h74: p2_buttons[6] <= !is_release;
                    8'h6C: p2_buttons[7] <= !is_release;
                    8'h75: p2_buttons[8] <= !is_release;
                    8'h7D: p2_buttons[9] <= !is_release;

                    8'h76: coin_input    <= !is_release;
                    8'h16: start1_button <= !is_release;
                    8'h1E: start2_button <= !is_release;
                    default: ;
                endcase
            end
        end
    end

endmodule
