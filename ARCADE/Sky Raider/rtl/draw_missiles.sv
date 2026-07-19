`timescale 1ns / 1ps

module draw_missiles (
    input  logic        clk_12M,
    input  logic        rst_n,
    input  logic [6:0]  terrain_h_cnt,
    input  logic        inside_trapezoid,
    input  logic [8:0]  v_cnt,
    input  logic [7:0]  m_pos_ram [15:0],
    input  logic [7:0]  m_obj_ram [15:0],
    output logic        missile_pixel
);

    logic [7:0] missiles_rom_addr;
    logic [7:0] missiles_rom_data;

    n5 n5_inst (
        .clk(clk_12M),
        .addr(missiles_rom_addr),
        .data(missiles_rom_data[3:0])
    );

    m4 m4_inst (
        .clk(clk_12M),
        .addr(missiles_rom_addr),
        .data(missiles_rom_data[7:4])
    );

    logic [3:0] v_calc       [3:0];
    logic       in_v_window  [3:0];
    logic [6:0] h_start      [3:0];
    logic       active       [3:0];
    logic [3:0] missile_x    [3:0];
    logic       active_d     [3:0];
    logic [3:0] missile_x_d  [3:0];
    logic [6:0] last_terrain_h;

    always_comb begin
        missiles_rom_addr = '0;
        for (int i = 0; i < 4; i++) begin
            logic [7:0] line_diff;
            line_diff    = v_cnt[7:0] - m_pos_ram[2*i] + 8'd15;
            v_calc[i]    = line_diff[3:0];
            in_v_window[i] = (line_diff[7:4] == 4'h0);
            h_start[i]   = (m_pos_ram[2*i+1] - 8'd31) >> 1;
            if (active[i] && in_v_window[i] && inside_trapezoid) begin
                missiles_rom_addr = { ~m_obj_ram[2*i][2:0], v_calc[i], missile_x[i][3] };
            end
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            last_terrain_h <= '0;
            for (int i = 0; i < 4; i++) begin
                active[i]      <= '0;
                missile_x[i]   <= '0;
                active_d[i]    <= '0;
                missile_x_d[i] <= '0;
            end
        end else begin
            last_terrain_h <= terrain_h_cnt;

            for (int i = 0; i < 4; i++) begin
                active_d[i]    <= active[i];
                missile_x_d[i] <= missile_x[i];

                if (in_v_window[i] && inside_trapezoid) begin
                    if (!active[i] && (terrain_h_cnt == h_start[i])) begin
                        active[i]    <= 1'b1;
                        missile_x[i] <= '0;
                    end else if (active[i] && (terrain_h_cnt != last_terrain_h)) begin
                        if (missile_x[i] == 4'd15) begin
                            active[i] <= 1'b0;
                        end else begin
                            missile_x[i] <= missile_x[i] + 1'b1;
                        end
                    end
                end else if (!in_v_window[i]) begin
                    active[i] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        missile_pixel = 1'b0;
        for (int i = 3; i >= 0; i--) begin
            if (active_d[i]) begin

                missile_pixel = missiles_rom_data[3'd7 - missile_x_d[i][2:0]];
            end
        end
    end

endmodule
