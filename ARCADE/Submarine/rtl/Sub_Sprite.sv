//`define USE_BRAM
module Sub_Sprite (
    input  logic        clk_sys,
    input  logic        ce_pix,
    input  logic [8:0]  hc,
    input  logic [8:0]  vc,
    input  logic        flip_screen,
    output logic [5:0]  spr0_vaddr,
    input  logic [7:0]  spr0_vdata,
    output logic [5:0]  spr1_vaddr,
    input  logic [7:0]  spr1_vdata,
    output logic [13:0] spr_rom_addr,
    input  logic [23:0] spr_rom_data,
    output logic [7:0]  lb_waddr,
    output logic [9:0]  lb_wdata,
    output logic        lb_we
);

    localparam int H_ACTIVE = 256;

    logic [4:0]  sprite_idx;
    logic [2:0]  state;
    logic [4:0]  px;
    logic        byte_cnt;

    logic [7:0]  raw_sx;
    logic [7:0]  raw_code;
    logic [7:0]  raw_col_attr;
    logic [7:0]  raw_sy;

    logic [7:0]  calc_sx;
    logic [7:0]  calc_sy;
    logic        dx;
    logic        flip_x;
    logic        flip_y;
    logic [5:0]  spr_color;

    logic [7:0]  sdy;
    logic        spr_active;
    logic [4:0]  mod_srow;
    logic [3:0]  c_idx;
    logic        half_sel;
    logic [1:0]  block_y;
    logic [2:0]  line_y;
    logic [2:0]  bit_pos;

    logic [23:0] active_rom_data;
    logic [7:0]  rom0_data, rom1_data, rom2_data;
    logic [2:0]  spr_pixel;
    logic [8:0]  out_x;
    logic [2:0]  wait_cnt;

`ifdef USE_BRAM
    logic [7:0] bram_rom0_data;
    logic [7:0] bram_rom1_data;
    logic [7:0] bram_rom2_data;

    sub_spr_rom0 spr_rom0_inst (
        .clk (clk_sys),
        .addr(spr_rom_addr),
        .data(bram_rom0_data)
    );

    sub_spr_rom1 spr_rom1_inst (
        .clk (clk_sys),
        .addr(spr_rom_addr),
        .data(bram_rom1_data)
    );

    sub_spr_rom2 spr_rom2_inst (
        .clk (clk_sys),
        .addr(spr_rom_addr),
        .data(bram_rom2_data)
    );

    assign active_rom_data = {bram_rom2_data, bram_rom1_data, bram_rom0_data};
`else
    assign active_rom_data = spr_rom_data;
`endif

    always_comb begin
        spr0_vaddr   = {sprite_idx, byte_cnt};
        spr1_vaddr   = {sprite_idx, byte_cnt};

        dx           = ~raw_col_attr[7];
        flip_y       = ~raw_col_attr[6];
        flip_x       = flip_screen;
        spr_color    = raw_col_attr[5:0];

        calc_sx      = flip_screen ? (8'hE0 - raw_sx) : raw_sx;
        if (dx)
            calc_sx  = 8'hE0 - calc_sx;

        calc_sy      = 8'hE0 - raw_sy;

        sdy          = vc[7:0] - calc_sy;
        spr_active   = (sdy < 8'd32);
        mod_srow     = flip_y ? (5'd31 - sdy[4:0]) : sdy[4:0];

        block_y      = ~mod_srow[4:3];
        line_y       = ~mod_srow[2:0];

        c_idx        = px[3:0] ^ {4{flip_x}};
        spr_rom_addr = {raw_code, block_y, ~half_sel, line_y};

        bit_pos      = 3'd7 - c_idx[2:0];
        spr_pixel    = {rom2_data[bit_pos], rom1_data[bit_pos], rom0_data[bit_pos]};
        out_x        = {1'b0, calc_sx} + {5'd0, px[3:0]};
    end

    always_ff @(posedge clk_sys) begin
        lb_we <= 1'b0;

        if (hc == H_ACTIVE && ce_pix) begin
            state      <= 3'd0;
            sprite_idx <= 5'd0;
            byte_cnt   <= 1'b0;
            wait_cnt   <= 3'd0;
        end else if (hc >= H_ACTIVE) begin
            case (state)
                3'd0: begin
                    state <= 3'd1;
                end

                3'd1: begin
                    if (!byte_cnt) begin
                        raw_sx       <= spr0_vdata;
                        raw_col_attr <= spr1_vdata;
                        byte_cnt     <= 1'b1;
                        state        <= 3'd0;
                    end else begin
                        raw_code <= spr0_vdata;
                        raw_sy   <= spr1_vdata;
                        state    <= 3'd2;
                    end
                end

                3'd2: begin
                    if (spr_active) begin
                        px       <= 5'd0;
                        half_sel <= flip_x;
                        wait_cnt <= 3'd0;
                        state    <= 3'd3;
                    end else begin
                        state    <= 3'd4;
                    end
                end

                3'd3: begin
                    if (wait_cnt < 3'd4) begin
                        wait_cnt <= wait_cnt + 3'd1;
                        if (wait_cnt == 3'd3) begin
                            rom0_data <= active_rom_data[7:0];
                            rom1_data <= active_rom_data[15:8];
                            rom2_data <= active_rom_data[23:16];
                        end
                    end else begin
                        lb_waddr <= out_x[7:0];
                        lb_wdata <= {1'b0, spr_color, spr_pixel};
                        lb_we    <= (out_x < 9'd256);

                        if (px == 5'd15) begin
                            state <= 3'd4;
                        end else begin
                            px <= px + 5'd1;
                            if (px == 5'd7) begin
                                half_sel <= ~flip_x;
                                wait_cnt <= 3'd0;
                            end
                        end
                    end
                end

                3'd4: begin
                    byte_cnt <= 1'b0;
                    if (sprite_idx == 5'd31) begin
                        sprite_idx <= 5'd0;
                        state      <= 3'd5;
                    end else begin
                        sprite_idx <= sprite_idx + 5'd1;
                        state      <= 3'd0;
                    end
                end

                default: ;
            endcase
        end
    end

endmodule
