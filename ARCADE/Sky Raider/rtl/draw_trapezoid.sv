
`timescale 1ns / 1ps

module draw_trapezoid (
    input  logic        clk_12M,
    input  logic        rst_n,
    input  logic [9:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [7:0]  m_pos_ram [15:0],
    input  logic [7:0]  m_obj_ram [15:0],
    output logic        inside_trapezoid,
    output logic [6:0]  terrain_h_cnt,
    output logic        sprite_pixel,
    output logic [1:0]  sprite_color
);

    logic [7:0] prom_addr;
    logic [3:0] prom_b6_msb;
    logic [3:0] prom_a6_lsb;
    assign prom_addr = {v_cnt[7:1], h_cnt[7]};

    b6 prom_b6 (
        .clk(clk_12M),
        .addr(prom_addr),
        .data(prom_b6_msb)
    );

    a6 prom_a6 (
        .clk(clk_12M),
        .addr(prom_addr),
        .data(prom_a6_lsb)
    );

    logic [9:0] h_cnt_d1;
    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) h_cnt_d1 <= 10'b0;
        else        h_cnt_d1 <= h_cnt;
    end

    logic [7:0] x_left_reg;
    logic [7:0] x_right_reg;

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            x_left_reg  <= 8'h00;
            x_right_reg <= 8'hFF;
        end else begin
            if (h_cnt_d1[7] == 1'b0) begin
                x_left_reg <= {prom_b6_msb[3:0], prom_a6_lsb[3:0]};
            end else begin
                x_right_reg <= {prom_b6_msb[3:0], prom_a6_lsb[3:0]};
            end
        end
    end

    logic [9:0] x_left;
    logic [9:0] x_right;
    logic [9:0] width;
    logic [15:0] step_width;

    always_comb begin
        x_left   = {2'b00, x_left_reg};        
        x_right  = 10'h100 + {2'b00, x_right_reg};       
        width    = x_right - x_left;
        
        if (width > 10'd8)
            step_width = 16'd65535 / width;
        else
            step_width = 16'd0;
    end

    logic [15:0] accumulator;
    logic        inside_trapezoid_raw;
    logic [6:0]  terrain_h_cnt_raw;

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            inside_trapezoid_raw <= 1'b0;
            accumulator          <= '0;
            terrain_h_cnt_raw    <= 7'd0;
        end else begin
            if ((h_cnt_d1 >= x_left) && (h_cnt_d1 < x_right) && (width > 10'd8)) begin
                inside_trapezoid_raw <= 1'b1;
                if (h_cnt_d1 == x_left) begin
                    accumulator   <= '0;
                    terrain_h_cnt_raw <= 7'd0;
                end else begin
                    accumulator   <= accumulator + step_width;
                    terrain_h_cnt_raw <= accumulator[15:9];
                end
            end else begin
                inside_trapezoid_raw <= 1'b0;
                accumulator          <= '0;
                terrain_h_cnt_raw    <= 7'd0;
            end
        end
    end

    logic [10:0] sprites_rom_addr;
    logic [7:0]  sprites_rom_data;

    m7 m7_inst (
        .clk(clk_12M),
        .addr(sprites_rom_addr),
        .data(sprites_rom_data)
    );

    logic [4:0] v_calc [3:0];
    logic       in_v_window [3:0];
    logic       sprite_enabled [3:0];
    logic       active [3:0];
    logic [4:0] sprite_x [3:0];
    logic [1:0] pixel_color_layer [3:0];

    logic [4:0] sprite_x_delayed [3:0];
    logic       active_delayed [3:0];
    logic [6:0] last_terrain_h_cnt;

    always_comb begin
        sprites_rom_addr = '0;
        for (int i = 0; i < 4; i++) begin
            v_calc[i] = 5'(v_cnt - (m_pos_ram[8 + 2*i] - 8'd31));
            in_v_window[i] = (v_cnt >= (m_pos_ram[8 + 2*i] - 8'd31)) && 
                             (v_cnt <  (m_pos_ram[8 + 2*i] + 8'd1));                            
            sprite_enabled[i] = m_obj_ram[8 + 2*i + 1][0];                 
            if (active[i] && in_v_window[i]) begin
                sprites_rom_addr = { (m_obj_ram[8 + 2*i][2:0] ^ 3'h7), v_calc[i], sprite_x[i][4:2] };
            end
        end
    end
    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            last_terrain_h_cnt <= '0;
            for (int i = 0; i < 4; i++) begin
                active[i]            <= 1'b0;
                sprite_x[i]          <= '0;
                active_delayed[i]    <= 1'b0;
                sprite_x_delayed[i]  <= '0;
                pixel_color_layer[i] <= 2'b10;
            end
        end else begin
            last_terrain_h_cnt <= terrain_h_cnt_raw;

            for (int i = 0; i < 4; i++) begin
                active_delayed[i]    <= active[i];
                sprite_x_delayed[i]  <= sprite_x[i];
                if (in_v_window[i] && sprite_enabled[i] && inside_trapezoid_raw) begin                   
                    if (terrain_h_cnt_raw == (m_pos_ram[8 + 2*i + 1] >> 1)) begin
                        active[i]   <= 1'b1;
                        sprite_x[i] <= '0;
                    end
                    else if (active[i] && (terrain_h_cnt_raw != last_terrain_h_cnt)) begin
                        if (sprite_x[i] == 5'd31) begin
                            active[i] <= 1'b0;
                        end else begin
                            sprite_x[i] <= sprite_x[i] + 1'b1;
                        end
                    end
                end else begin
                    active[i] <= 1'b0;
                end
                if (active_delayed[i]) begin
                    case (sprite_x_delayed[i][1:0])
                        2'd0: pixel_color_layer[i] <= sprites_rom_data[7:6];
                        2'd1: pixel_color_layer[i] <= sprites_rom_data[5:4];
                        2'd2: pixel_color_layer[i] <= sprites_rom_data[3:2];
                        2'd3: pixel_color_layer[i] <= sprites_rom_data[1:0];
                    endcase
                end else begin
                    pixel_color_layer[i] <= 2'b10;
                end
            end
        end
    end

    always_comb begin
        sprite_pixel = 1'b0;
        sprite_color = 2'b00;
        for (int i = 3; i >= 0; i--) begin
            if (pixel_color_layer[i] != 2'b10 && active_delayed[i]) begin 
                sprite_pixel = 1'b1;
                sprite_color = pixel_color_layer[i];
            end
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            inside_trapezoid <= 1'b0;
            terrain_h_cnt    <= 7'd0;
        end else begin
            inside_trapezoid <= inside_trapezoid_raw;
            terrain_h_cnt    <= terrain_h_cnt_raw;
        end
    end

endmodule
