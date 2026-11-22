module mouser_sprite (
    input  logic        clk_sys,
    input  logic [7:0]  spriteram_data,
    output logic [7:0]  spriteram_addr,
    input  logic [8:0]  h_count,
    input  logic [8:0]  v_count,
    output logic        sprite_active,
    output logic [13:0] sprite_rom_addr,
    output logic [3:0]  sprite_color_idx,
    output logic [2:0]  sprite_bit_sel
);

    logic [5:0] sprite_read_ptr;
    logic [7:0] active_spram_addr;

    logic [7:0] s_attrib0 [0:15];
    logic [7:0] s_attrib1 [0:15];
    logic [7:0] s_attrib2 [0:15];
    logic [7:0] s_attrib3 [0:15];

    logic [7:0] hardware_x;
    logic [7:0] hardware_y;
    logic [3:0] sp_pixel_h;
    logic [3:0] sp_pixel_v;
    logic       sp_hit;
    
    logic [7:0] distanz_x;
    logic [7:0] distanz_y;

    always_ff @(posedge clk_sys) begin
        if (h_count == 9'd255) begin
            sprite_read_ptr <= 6'd0;
        end else if (h_count >= 9'd256 && h_count < 9'd320) begin
            sprite_read_ptr <= sprite_read_ptr + 6'd1;
        end
    end

    always_comb begin
        if (h_count >= 9'd256 && h_count < 9'd320) begin
            active_spram_addr = {2'b10, sprite_read_ptr[5:0]};
        end else begin
            active_spram_addr = {3'b000, h_count[7:3]};
        end
    end

    assign spriteram_addr = active_spram_addr;

    always_ff @(posedge clk_sys) begin
        if (h_count >= 9'd257 && h_count < 9'd321) begin
            case (sprite_read_ptr[1:0])
                2'b01: s_attrib0[sprite_read_ptr[5:2]] <= spriteram_data;
                2'b10: s_attrib1[sprite_read_ptr[5:2]] <= spriteram_data;
                2'b11: s_attrib2[sprite_read_ptr[5:2]] <= spriteram_data;
                2'b00: s_attrib3[sprite_read_ptr[5:2]] <= spriteram_data;
            endcase
        end
    end

    always_comb begin
        sprite_active    = 1'b0;
        sprite_rom_addr  = 14'h0;
        sprite_color_idx = 4'd0;
        hardware_x       = 8'h0;
        hardware_y       = 8'h0;
        sp_pixel_h       = 4'd0;
        sp_pixel_v       = 4'd0;
        sp_hit           = 1'b0;
        distanz_x        = 8'h0;
        distanz_y        = 8'h0;
        sprite_bit_sel   = 3'd0;
        
        for (int i = 0; i < 16; i++) begin
            if (!sprite_active) begin
                hardware_x = s_attrib2[i];
                hardware_y = s_attrib3[i];
                
                distanz_x  = h_count[7:0] - hardware_x;
                distanz_y  = v_count[7:0] - hardware_y;
                
                sp_hit     = (distanz_x < 8'd16) && (distanz_y < 8'd16) && (s_attrib1[i][4]);
                
                if (sp_hit) begin
                    sp_pixel_h = s_attrib0[i][6] ? (4'd15 - distanz_x[3:0]) : distanz_x[3:0];
                    sp_pixel_v = s_attrib0[i][7] ? (4'd15 - distanz_y[3:0]) : distanz_y[3:0];
                    
                    sprite_active    = 1'b1;
                    sprite_rom_addr  = {1'b1, s_attrib1[i][5], s_attrib0[i][5:0], sp_pixel_v[3], sp_pixel_v[2:0]};
                    sprite_bit_sel   = 3'd7 - sp_pixel_h[2:0];
                    sprite_color_idx = s_attrib1[i][3:0];
                end
            end
        end
    end

endmodule
