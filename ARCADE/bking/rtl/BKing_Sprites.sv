module BKing_Sprites (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [8:0]  x_pos,
    input  logic [8:0]  y_pos,
    input  logic [7:0]  ball1_x,
    input  logic [7:0]  ball1_y,
    input  logic [2:0]  ball1_pic,
    input  logic [7:0]  ball2_x,
    input  logic [7:0]  ball2_y,
    input  logic [2:0]  ball2_pic,
    input  logic [7:0]  crow_x,
    input  logic [7:0]  crow_y,
    input  logic [3:0]  crow_pic,
    input  logic        crow_flip,
    output logic        ball1_active,
    output logic        ball1_pixel,
    output logic        ball2_active,
    output logic        ball2_pixel,
    output logic        crow_active,
    output logic [1:0]  crow_pixel
);

    logic [7:0] eff_ball1_x, eff_ball1_y, eff_ball2_x, eff_ball2_y, eff_crow_x, eff_crow_y;

    assign eff_ball1_x = ball1_x;
    assign eff_ball1_y = ball1_y;
    assign eff_ball2_x = ball2_x;
    assign eff_ball2_y = ball2_y;

    always_comb begin
        if (crow_flip) begin
            eff_crow_x = crow_x - 8'd16;
            eff_crow_y = crow_y - 8'd16;
        end else begin
            eff_crow_x = crow_x;
            eff_crow_y = crow_y;
        end
    end

    logic [7:0] b1_dx_raw, b1_dy_raw, b2_dx_raw, b2_dy_raw, cr_dx_raw, cr_dy_raw;

    assign b1_dx_raw = x_pos[7:0] - eff_ball1_x;
    assign b1_dy_raw = y_pos[7:0] - eff_ball1_y;
    assign b2_dx_raw = x_pos[7:0] - eff_ball2_x;
    assign b2_dy_raw = y_pos[7:0] - eff_ball2_y;
    assign cr_dx_raw = x_pos[7:0] - eff_crow_x;
    assign cr_dy_raw = y_pos[7:0] - eff_crow_y;

    logic ball1_inside, ball2_inside, crow_inside;

    assign ball1_inside = (b1_dx_raw < 8'd8)  && (b1_dy_raw < 8'd16);
    assign ball2_inside = (b2_dx_raw < 8'd8)  && (b2_dy_raw < 8'd16);
    assign crow_inside  = (cr_dx_raw < 8'd16) && (cr_dy_raw < 8'd32);

    logic [6:0] ball1_rom_addr;
    assign ball1_rom_addr = {ball1_pic[2:0], b1_dy_raw[3:0]};

    logic [7:0] ball1_rom_q;
    rom_ball1 ic9E (
        .clk(clk),
        .addr(ball1_rom_addr),
        .data(ball1_rom_q)
    );

    logic [6:0] ball2_rom_addr;
    assign ball2_rom_addr = {ball2_pic[2:0], b2_dy_raw[3:0]};

    logic [7:0] ball2_rom_q;
    rom_ball2 ic7E (
        .clk(clk),
        .addr(ball2_rom_addr),
        .data(ball2_rom_q)
    );

    logic [4:0] crow_pix_y;
    assign crow_pix_y = crow_flip ? (5'd31 - cr_dy_raw[4:0]) : cr_dy_raw[4:0];

    logic [10:0] crow_rom_addr;
    assign crow_rom_addr = {crow_pic[3:0], cr_dx_raw[3:2], crow_pix_y[4:0]};

    logic [7:0] crow_rom_q;
    rom_crow ic10E (
        .clk(clk),
        .addr(crow_rom_addr),
        .data(crow_rom_q)
    );

    logic [2:0] ball1_bit_sel_d1;
    logic [2:0] ball2_bit_sel_d1;
    logic [1:0] crow_pix_x_d1;
    logic       ball1_inside_d1;
    logic       ball2_inside_d1;
    logic       crow_inside_d1;

    always_ff @(posedge clk) begin
        ball1_bit_sel_d1 <= b1_dx_raw[2:0];
        ball2_bit_sel_d1 <= b2_dx_raw[2:0];
        crow_pix_x_d1    <= crow_flip ? (2'd3 - cr_dx_raw[1:0]) : cr_dx_raw[1:0];
        ball1_inside_d1  <= ball1_inside;
        ball2_inside_d1  <= ball2_inside;
        crow_inside_d1   <= crow_inside;
    end

    logic crow_bit0, crow_bit1;
    logic [3:0] crow_rom_l, crow_rom_h;
    
    assign crow_rom_l = crow_rom_q[3:0];
    assign crow_rom_h = crow_rom_q[7:4];
    assign crow_bit0  = crow_rom_l[crow_pix_x_d1];
    assign crow_bit1  = crow_rom_h[crow_pix_x_d1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ball1_active <= 1'b0;
            ball1_pixel  <= 1'b0;
            ball2_active <= 1'b0;
            ball2_pixel  <= 1'b0;
            crow_active  <= 1'b0;
            crow_pixel   <= 2'b00;
        end else begin
            ball1_active <= ball1_inside_d1;
            ball1_pixel  <= ball1_rom_q[ball1_bit_sel_d1];
            ball2_active <= ball2_inside_d1;
            ball2_pixel  <= ball2_rom_q[ball2_bit_sel_d1];
            crow_active  <= crow_inside_d1;
            crow_pixel   <= {crow_bit1, crow_bit0};
        end
    end

endmodule
