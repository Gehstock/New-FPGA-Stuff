module huebler_keyboard (
    input  logic        clk,
    input  logic        clk_2_5mhz_en,
    input  logic        rst_n,
    
    input  logic        ps2_kbd_clk,
    input  logic        ps2_kbd_data,
    
    input  logic        kb_rom_cs,
    input  logic        cpu_a0,
    output logic [7:0]  kb_rom_dout,
    
    input  logic        scan_tick
);

    logic [2:0] ps2_clk_sync;
    logic [1:0] ps2_data_sync;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync  <= 3'b111;
            ps2_data_sync <= 2'b11;
        end else begin
            ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_kbd_clk};
            ps2_data_sync <= {ps2_data_sync[0], ps2_kbd_data};
        end
    end
    
    wire ps2_clk_fall    = (ps2_clk_sync[2:1] == 2'b10); 
    wire stable_ps2_data = ps2_data_sync[1];

    logic [10:0] shift_reg;
    logic [3:0]  bit_count;
    logic        scancode_ready;
    logic [7:0]  raw_scancode;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg      <= 11'd0;
            bit_count      <= 4'd0;
            scancode_ready <= 1'b0;
            raw_scancode   <= 8'd0;
        end else begin
            scancode_ready <= 1'b0;
            if (ps2_clk_fall) begin
                shift_reg <= {stable_ps2_data, shift_reg[10:1]};
                if (bit_count == 4'd10) begin
                    bit_count      <= 4'd0;
                    raw_scancode   <= shift_reg[9:2];
                    scancode_ready <= 1'b1;
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end
        end
    end

    logic shift_pressed;
    logic ctrl_pressed;
    logic is_break;
    logic is_ext;
    logic [7:0] current_char;
    logic key_available;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_break      <= 1'b0;
            is_ext        <= 1'b0;
            shift_pressed <= 1'b0;
            ctrl_pressed  <= 1'b0;
            current_char  <= 8'h00;
            key_available <= 1'b0;
        end else if (scancode_ready) begin
            if (raw_scancode == 8'hF0) begin
                is_break <= 1'b1;
            end else if (raw_scancode == 8'hE0) begin
                is_ext <= 1'b1;
            end else begin
                logic key_state;
                key_state = !is_break;
                is_break  <= 1'b0;
                is_ext    <= 1'b0;

                if (!is_ext && (raw_scancode == 8'h12 || raw_scancode == 8'h59)) begin
                    shift_pressed <= key_state;
                end else if (raw_scancode == 8'h14) begin
                    ctrl_pressed  <= key_state;
                end else if (key_state) begin
                    key_available <= 1'b1;
                    if (is_ext) begin
                        case (raw_scancode)
                            8'h75: current_char <= 8'h0B;
                            8'h72: current_char <= 8'h0A;
                            8'h6B: current_char <= 8'h08;
                            8'h74: current_char <= 8'h09;
                            8'h6C: current_char <= 8'h1E;
                            8'h69: current_char <= 8'h0C;
                            8'h5A: current_char <= 8'h0D;
                            8'h4A: current_char <= 8'h2F;
                            default: begin
                                current_char  <= 8'h00;
                                key_available <= 1'b0;
                            end
                        endcase
                    end else if (ctrl_pressed) begin
                        case (raw_scancode)
                            8'h32: current_char <= 8'h01;
                            8'h1C: current_char <= 8'h02;
                            8'h21: current_char <= 8'h03;
                            8'h23: current_char <= 8'h04;
                            8'h24: current_char <= 8'h05;
                            8'h2B: current_char <= 8'h06;
                            8'h34: current_char <= 8'h07;
                            8'h33: current_char <= 8'h08;
                            8'h43: current_char <= 8'h09;
                            8'h3B: current_char <= 8'h0A;
                            8'h42: current_char <= 8'h0B;
                            8'h4B: current_char <= 8'h0C;
                            8'h3A: current_char <= 8'h0D;
                            8'h31: current_char <= 8'h0E;
                            8'h44: current_char <= 8'h0F;
                            8'h4D: current_char <= 8'h10;
                            8'h15: current_char <= 8'h11;
                            8'h2D: current_char <= 8'h12;
                            8'h1B: current_char <= 8'h13;
                            8'h2C: current_char <= 8'h14;
                            8'h3C: current_char <= 8'h15;
                            8'h2A: current_char <= 8'h16;
                            8'h1D: current_char <= 8'h17;
                            8'h22: current_char <= 8'h18;
                            8'h35: current_char <= 8'h19;
                            8'h1A: current_char <= 8'h1A;
                            default: begin
                                current_char  <= 8'h00;
                                key_available <= 1'b0;
                            end
                        endcase
                    end else if (shift_pressed) begin
                        case (raw_scancode)
                            8'h32: current_char <= 8'h41;
                            8'h1C: current_char <= 8'h42;
                            8'h21: current_char <= 8'h43;
                            8'h23: current_char <= 8'h44;
                            8'h24: current_char <= 8'h45;
                            8'h2B: current_char <= 8'h46;
                            8'h34: current_char <= 8'h47;
                            8'h33: current_char <= 8'h48;
                            8'h43: current_char <= 8'h49;
                            8'h3B: current_char <= 8'h4A;
                            8'h42: current_char <= 8'h4B;
                            8'h4B: current_char <= 8'h4C;
                            8'h3A: current_char <= 8'h4D;
                            8'h31: current_char <= 8'h4E;
                            8'h44: current_char <= 8'h4F;
                            8'h4D: current_char <= 8'h50;
                            8'h15: current_char <= 8'h51;
                            8'h2D: current_char <= 8'h52;
                            8'h1B: current_char <= 8'h53;
                            8'h2C: current_char <= 8'h54;
                            8'h3C: current_char <= 8'h55;
                            8'h2A: current_char <= 8'h56;
                            8'h1D: current_char <= 8'h57;
                            8'h22: current_char <= 8'h58;
                            8'h35: current_char <= 8'h59;
                            8'h1A: current_char <= 8'h5A;
                            8'h16: current_char <= 8'h21;
                            8'h1E: current_char <= 8'h22;
                            8'h26: current_char <= 8'h23;
                            8'h25: current_char <= 8'h24;
                            8'h2E: current_char <= 8'h25;
                            8'h36: current_char <= 8'h26;
                            8'h3D: current_char <= 8'h27;
                            8'h3E: current_char <= 8'h28;
                            8'h46: current_char <= 8'h29;
                            8'h45: current_char <= 8'h3D;
                            8'h4E: current_char <= 8'h5F;
                            8'h55: current_char <= 8'h2B;
                            8'h4C: current_char <= 8'h3A;
                            8'h52: current_char <= 8'h2A;
                            8'h41: current_char <= 8'h3C;
                            8'h49: current_char <= 8'h3E;
                            8'h4A: current_char <= 8'h3F;
                            8'h5A: current_char <= 8'h0D;
                            8'h29: current_char <= 8'h20;
                            8'h66: current_char <= 8'h08;
                            8'h76: current_char <= 8'h1B;
                            default: begin
                                current_char  <= 8'h00;
                                key_available <= 1'b0;
                            end
                        endcase
                    end else begin
                        case (raw_scancode)
                            8'h32: current_char <= 8'h61;
                            8'h1C: current_char <= 8'h62;
                            8'h21: current_char <= 8'h63;
                            8'h23: current_char <= 8'h64;
                            8'h24: current_char <= 8'h65;
                            8'h2B: current_char <= 8'h66;
                            8'h34: current_char <= 8'h67;
                            8'h33: current_char <= 8'h68;
                            8'h43: current_char <= 8'h69;
                            8'h3B: current_char <= 8'h6A;
                            8'h42: current_char <= 8'h6B;
                            8'h4B: current_char <= 8'h6C;
                            8'h3A: current_char <= 8'h6D;
                            8'h31: current_char <= 8'h6E;
                            8'h44: current_char <= 8'h6F;
                            8'h4D: current_char <= 8'h70;
                            8'h15: current_char <= 8'h71;
                            8'h2D: current_char <= 8'h72;
                            8'h1B: current_char <= 8'h73;
                            8'h2C: current_char <= 8'h74;
                            8'h3C: current_char <= 8'h75;
                            8'h2A: current_char <= 8'h76;
                            8'h1D: current_char <= 8'h77;
                            8'h22: current_char <= 8'h78;
                            8'h35: current_char <= 8'h79;
                            8'h1A: current_char <= 8'h7A;
                            8'h45: current_char <= 8'h30;
                            8'h16: current_char <= 8'h31;
                            8'h1E: current_char <= 8'h32;
                            8'h26: current_char <= 8'h33;
                            8'h25: current_char <= 8'h34;
                            8'h2E: current_char <= 8'h35;
                            8'h36: current_char <= 8'h36;
                            8'h3D: current_char <= 8'h37;
                            8'h3E: current_char <= 8'h38;
                            8'h46: current_char <= 8'h39;
                            8'h4E: current_char <= 8'h2D;
                            8'h55: current_char <= 8'h3D;
                            8'h4C: current_char <= 8'h3B;
                            8'h52: current_char <= 8'h27;
                            8'h41: current_char <= 8'h2C;
                            8'h49: current_char <= 8'h2E;
                            8'h4A: current_char <= 8'h2F;
                            8'h54: current_char <= 8'h5B;
                            8'h5B: current_char <= 8'h5D;
                            8'h5D: current_char <= 8'h40;
                            8'h5A: current_char <= 8'h0D;
                            8'h29: current_char <= 8'h20;
                            8'h66: current_char <= 8'h08;
                            8'h76: current_char <= 8'h1B;
                            default: begin
                                current_char  <= 8'h00;
                                key_available <= 1'b0;
                            end
                        endcase
                    end
                end else begin
                    current_char  <= 8'h00;
                    key_available <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        kb_rom_dout = 8'h00;
        if (kb_rom_cs) begin
            if (!cpu_a0)
                kb_rom_dout = current_char;
            else
                kb_rom_dout = key_available ? 8'h80 : 8'h00;
        end
    end

endmodule

