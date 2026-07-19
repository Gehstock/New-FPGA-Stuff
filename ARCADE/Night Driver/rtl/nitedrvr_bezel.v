module bezel_overlay (
    input  wire        clk,
	 input  wire        ena,
    input  wire [9:0]  h_cnt,
    input  wire [9:0]  v_cnt,
    input  wire        game_pixel,
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    localparam IMG_WIDTH          = 10'd160;
    localparam IMG_HEIGHT         = 10'd66;   
    localparam START_X            = 10'd48;  
    localparam START_Y            = 10'd174; 
    localparam BMP_PALETTE_OFFSET = 16'd54;
    localparam BMP_DATA_OFFSET    = 16'd118;

    reg  [15:0] rom_addr_reg;
    wire [7:0]  rom_data_out;
    
    reg         in_window_d1,  in_window_d2,  in_window_d3;
    reg         pixel_sel_d1,  pixel_sel_d2,  pixel_sel_d3;
    reg         game_pixel_d1, game_pixel_d2, game_pixel_d3;
    reg [7:0]   rom_data_d1; 

    reg [3:0] palette_r [0:15];
    reg [3:0] palette_g [0:15];
    reg [3:0] palette_b [0:15];
    
    reg [6:0] init_counter = 7'd0;
    reg       init_done = 1'b0;
    wire [15:0] pixel_rom_addr;
    
    always @(*) begin
        if (!init_done) begin
            rom_addr_reg = BMP_PALETTE_OFFSET + init_counter;
        end else begin
            rom_addr_reg = pixel_rom_addr;
        end
    end

    wire [3:0] palette_idx = init_counter[5:2];
    wire [1:0] color_subidx = init_counter[1:0];

    always @(posedge clk) begin
        if (!init_done) begin
            init_counter <= init_counter + 7'd1;
            if (init_counter >= 7'd0 && init_counter < 7'd64) begin
                case (color_subidx)
                    2'd0: ;
                    2'd1: palette_b[palette_idx] <= rom_data_out[7:4];
                    2'd2: palette_g[palette_idx] <= rom_data_out[7:4];
                    2'd3: palette_r[palette_idx] <= rom_data_out[7:4];
                endcase
            end           
            if (init_counter == 7'd66) begin
                init_done <= 1'b1;
            end
        end
    end


    wire signed [10:0] rel_x = $signed({1'b0, h_cnt}) - $signed({1'b0, START_X});
    wire signed [10:0] rel_y = $signed({1'b0, v_cnt}) - $signed({1'b0, START_Y});
    wire [9:0] local_x = (rel_x >= 0) ? rel_x[9:0] : 10'd0;
    wire [9:0] local_y = (rel_y >= 0) ? rel_y[9:0] : 10'd0;
    wire [9:0] src_y = (IMG_HEIGHT - 1'b1) - local_y;
    wire [9:0] src_x = local_x; 
    
    assign pixel_rom_addr = (src_y * 16'd80) + (src_x >> 1) + BMP_DATA_OFFSET;

    always @(posedge clk) begin
        if (init_done) begin
            if ((h_cnt >= START_X) && (h_cnt < START_X + IMG_WIDTH) &&
                (v_cnt >= START_Y) && (v_cnt < START_Y + IMG_HEIGHT)) begin
                in_window_d1 <= 1'b1;
                pixel_sel_d1 <= src_x[0];
            end else begin
                in_window_d1 <= 1'b0;
                pixel_sel_d1 <= 1'b0;
            end
            game_pixel_d1   <= game_pixel;

            in_window_d2    <= in_window_d1;
            pixel_sel_d2    <= pixel_sel_d1;
            game_pixel_d2   <= game_pixel_d1;
            rom_data_d1     <= rom_data_out; 

            in_window_d3    <= in_window_d2;
            pixel_sel_d3    <= pixel_sel_d2;
            game_pixel_d3   <= game_pixel_d2;
        end
    end

    bezel your_bezel_rom (
        .clk(clk),
        .addr(rom_addr_reg), 
        .data(rom_data_out)
    );

    wire [3:0] color_index = (in_window_d3) ? 
                             ((pixel_sel_d3) ? rom_data_d1[3:0] : rom_data_d1[7:4]) : 
                             4'd0;
    
    wire [3:0] dynamic_r = palette_r[color_index];
    wire [3:0] dynamic_g = palette_g[color_index];
    wire [3:0] dynamic_b = palette_b[color_index];

    always @(*) begin
        if (init_done && in_window_d3 && (color_index != 4'd0) && ena) begin
            r = dynamic_r;
            g = dynamic_g;
            b = dynamic_b;
        end else begin
            if (game_pixel_d3) begin
                r = 4'hF; g = 4'hF; b = 4'hF; 
            end else begin
                r = 4'h0; g = 4'h0; b = 4'h0; 
            end
        end
    end

endmodule
