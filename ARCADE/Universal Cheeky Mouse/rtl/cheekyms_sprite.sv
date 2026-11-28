module cheekyms_sprite (
    input  wire        clk_sys,
    input  wire        clk_vid_en,
    input  wire [8:0]  h_cnt,
    input  wire [8:0]  v_cnt,
    input  wire [7:0]  port_80_reg,
    input  wire        cpu_sram_wr,
    input  wire [4:0]  cpu_sram_addr,
    input  wire [7:0]  cpu_sram_data,
    output reg         sprite_opaque,
    output reg  [2:0]  sprite_rgb
);

    wire flip = port_80_reg[7];

    reg [7:0] sprite_ram [0:31];
    always @(posedge clk_sys) begin
        if (cpu_sram_wr) begin
            sprite_ram[cpu_sram_addr] <= cpu_sram_data;
        end
    end

    wire [8:0] eff_h = flip ? (9'd255 - h_cnt) : h_cnt;
    wire [8:0] eff_v = flip ? (9'd255 - v_cnt) : v_cnt;

    reg       sprite_hit;
    reg [3:0] sprite_local_x;
    reg [3:0] sprite_local_y;
    reg [5:0] active_sprite_code;
    reg [2:0] active_sprite_color;

    integer i;
    reg [7:0] s_code, s_y, s_x, s_attrib;
    reg [8:0] diff_y, diff_x;
    reg [4:0] sprite_code_base;
    reg [5:0] sprite_code_final;
    reg       sprite_hit_active;

    always @(*) begin
        sprite_hit          = 1'b0;
        sprite_local_x      = 4'd0;
        sprite_local_y      = 4'd0;
        active_sprite_code  = 6'd0;
        active_sprite_color = 3'd0;

        for (i = 7; i >= 0; i = i - 1) begin
            s_code   = sprite_ram[i*4 + 0];
            s_y      = sprite_ram[i*4 + 1];
            s_x      = sprite_ram[i*4 + 2];
            s_attrib = sprite_ram[i*4 + 3];

            diff_y = eff_v - {1'b0, s_y};
            diff_x = eff_h - (9'd256 - {1'b0, s_x});

            sprite_code_base  = {(~s_code[3:0]), 1'b0};
            sprite_code_final = 6'd0;
            sprite_hit_active = 1'b0;

            if (s_attrib[3]) begin
                if (s_code[7]) begin
                    sprite_code_final = (!flip) ? {1'b0, sprite_code_base + 5'd1} : {1'b0, sprite_code_base};
                    if ((diff_y < 9'd16) && (diff_x < 9'd16)) begin
                        sprite_hit_active = 1'b1;
                    end
                end else if (s_code[1]) begin
                    if ((diff_y < 9'd16) && (diff_x < 9'd32)) begin
                        sprite_hit_active = 1'b1;
                        sprite_code_final = ((diff_x < 9'd16) ^ flip)
                            ? ({1'b0, sprite_code_base} | 6'h20)
                            : ({1'b0, sprite_code_base} | 6'h21);
                    end
                end else begin
                    if ((diff_y < 9'd32) && (diff_x < 9'd16)) begin
                        sprite_hit_active = 1'b1;
                        sprite_code_final = ((diff_y < 9'd16) ^ flip)
                            ? ({1'b0, sprite_code_base} | 6'h20)
                            : ({1'b0, sprite_code_base} | 6'h21);
                    end
                end

                if (sprite_hit_active) begin
                    sprite_hit          = 1'b1;
                    sprite_local_y      = flip ? ~diff_y[3:0] : diff_y[3:0];
                    sprite_local_x      = flip ? ~diff_x[3:0] : diff_x[3:0];
                    active_sprite_code  = sprite_code_final;
                    active_sprite_color = ~s_attrib[2:0];
                end
            end
        end
    end

    wire [10:0] sprite_rom_addr = {active_sprite_code[5:0], sprite_local_y[3:0], sprite_local_x[3]};

    wire [7:0] raw_sprite_data_low;
    wire [7:0] raw_sprite_data_high;

    sprite_pattern_rom_low sprite_rom_l (
        .clk  (clk_sys),
        .addr (sprite_rom_addr),
        .data (raw_sprite_data_low)
    );

    sprite_pattern_rom_high sprite_rom_h (
        .clk  (clk_sys),
        .addr (sprite_rom_addr),
        .data (raw_sprite_data_high)
    );

    reg sp_bit_l;
    reg sp_bit_h;
    always @(*) begin
        case (sprite_local_x[2:0])
            3'd0: begin sp_bit_l = raw_sprite_data_low[7]; sp_bit_h = raw_sprite_data_high[7]; end
            3'd1: begin sp_bit_l = raw_sprite_data_low[6]; sp_bit_h = raw_sprite_data_high[6]; end
            3'd2: begin sp_bit_l = raw_sprite_data_low[5]; sp_bit_h = raw_sprite_data_high[5]; end
            3'd3: begin sp_bit_l = raw_sprite_data_low[4]; sp_bit_h = raw_sprite_data_high[4]; end
            3'd4: begin sp_bit_l = raw_sprite_data_low[3]; sp_bit_h = raw_sprite_data_high[3]; end
            3'd5: begin sp_bit_l = raw_sprite_data_low[2]; sp_bit_h = raw_sprite_data_high[2]; end
            3'd6: begin sp_bit_l = raw_sprite_data_low[1]; sp_bit_h = raw_sprite_data_high[1]; end
            3'd7: begin sp_bit_l = raw_sprite_data_low[0]; sp_bit_h = raw_sprite_data_high[0]; end
        endcase
    end
	 
    wire [1:0] sprite_dot = {sp_bit_h, sp_bit_l};

    wire [4:0] sprite_color_addr = {active_sprite_color[2:0], sprite_dot};
    wire [7:0] prom_sprite_p3d;

    prom_sprite_p3 u_prom_p3 (
        .clk  (clk_sys),
        .addr (sprite_color_addr),
        .data (prom_sprite_p3d)
    );

    always @(*) begin
        sprite_opaque = sprite_hit && (sprite_dot != 2'b00);
        sprite_rgb    = prom_sprite_p3d[2:0];
    end


endmodule
