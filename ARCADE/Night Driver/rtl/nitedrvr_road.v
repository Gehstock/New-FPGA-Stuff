module nitedrvr_road (
    input  wire         clk_sys,
    input  wire         rst_n,
    input  wire  [8:0]  h_cnt,
    input  wire  [8:0]  v_cnt,
    input  wire         hvc_posh_we,
    input  wire         hvc_posv_we,
    input  wire         hvc_char_we,
    input  wire  [3:0]  hvc_addr,
    input  wire  [7:0]  hvc_data,
    output reg          road_video
);

    reg [7:0] hvc_reg_h [0:15];
    reg [7:0] hvc_reg_v [0:15];
    reg [7:0] hvc_reg_c [0:15];

    integer i;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                hvc_reg_h[i] <= 8'd0;
                hvc_reg_v[i] <= 8'd0;
                hvc_reg_c[i] <= 8'd0;
            end
        end else begin
            if (hvc_posh_we) hvc_reg_h[hvc_addr] <= hvc_data;
            if (hvc_posv_we) hvc_reg_v[hvc_addr] <= hvc_data;
            if (hvc_char_we) hvc_reg_c[hvc_addr] <= hvc_data;
        end
    end

    wire [15:0] post_hits;
    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : lane_posts
            wire [8:0] bx = {1'b0, hvc_reg_h[g]}; 
            wire [8:0] by = {1'b0, hvc_reg_v[g]};
            wire [3:0] b_width = hvc_reg_c[g][7:4];
            wire [8:0] ex      = bx + b_width;
            wire [4:0] b_height = 5'd16 - hvc_reg_c[g][3:0];
            wire [8:0] ey       = by + b_height;
            assign post_hits[g] = (h_cnt >= bx) && (h_cnt < ex) &&
                                  (v_cnt >= by) && (v_cnt < ey);
        end
    endgenerate

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            road_video <= 1'b0;
        end else begin
            road_video <= |post_hits;
        end
    end
endmodule

