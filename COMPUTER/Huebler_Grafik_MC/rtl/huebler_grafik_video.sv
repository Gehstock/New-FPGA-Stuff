module huebler_grafik_video (
    input  logic        clk_10mhz,
    input  logic        rst_n,
    
    input  logic [7:0]  video_ctrl,
    input  logic        vram_enable,
    input  logic        vram_we,
    input  logic [12:0] vram_addr,
    input  logic [7:0]  vram_din,
    output logic [7:0]  vram_dout,
    
    output logic        hsync,         
    output logic        vsync,         
    output logic        hblank,        
    output logic        vblank,        
    output logic        video_out
);

    logic pixel_en;
    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            pixel_en <= 1'b0;
        end else begin
            pixel_en <= ~pixel_en;
        end
    end

    localparam int H_ACTIVE = 256;
    localparam int H_TOTAL  = 320;     
    localparam int H_SYNC_W = 24;      
    localparam int H_FP     = 8;       

    localparam int V_ACTIVE = 256;
    localparam int V_TOTAL  = 312;     
    localparam int V_SYNC_W = 4;       
    localparam int V_FP     = 12;      

    logic [8:0] h_cnt;
    logic [8:0] v_cnt;

    logic [4:0] sx;
    logic [2:0] x_pixel;

    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt   <= 9'd0;
            sx      <= 5'd0;
            x_pixel <= 3'd0;
        end else if (pixel_en) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt   <= 9'd0;
                sx      <= 5'd0;
                x_pixel <= 3'd0;
            end else begin
                h_cnt <= h_cnt + 9'd1;
                if (h_cnt < H_ACTIVE) begin
                    if (x_pixel == 3'd7) begin
                        x_pixel <= 3'd0;
                        sx      <= sx + 5'd1;
                    end else begin
                        x_pixel <= x_pixel + 3'd1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= 9'd0;
        end else if (pixel_en) begin
            if (h_cnt == H_TOTAL - 1) begin
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 9'd0;
                end else begin
                    v_cnt <= v_cnt + 9'd1;
                end
            end
        end
    end

    logic hblank_reg, vblank_reg;
    logic hsync_reg, vsync_reg;

    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            hsync      <= 1'b1;
            vsync      <= 1'b1;
            hsync_reg  <= 1'b1;
            vsync_reg  <= 1'b1;
            hblank     <= 1'b1;
            vblank     <= 1'b1;
            hblank_reg <= 1'b1;
            vblank_reg <= 1'b1;
        end else if (pixel_en) begin
            hsync_reg  <= ~((h_cnt >= (H_ACTIVE + H_FP)) && (h_cnt < (H_ACTIVE + H_FP + H_SYNC_W)));
            vsync_reg  <= ~((v_cnt >= (V_ACTIVE + V_FP)) && (v_cnt < (V_ACTIVE + V_FP + V_SYNC_W)));
            hblank_reg <= (h_cnt >= H_ACTIVE);
            vblank_reg <= (v_cnt >= V_ACTIVE);

            hblank     <= hblank_reg;
            vblank     <= vblank_reg;
            hsync      <= hsync_reg; 
            vsync      <= vsync_reg;
        end
    end

    wire video_active = (!hblank && !vblank);
    wire [12:0] vram_rd_addr = {v_cnt[7:0], sx};
    logic [7:0] vram_rd_data;

    dpram #(
        .address_width (13),
        .data_width    (8)
    ) vram_inst (
        .clock_a   (clk_10mhz), 
        .enable_a  (vram_enable),
        .wren_a    (vram_we),
        .address_a (vram_addr),
        .data_a    (vram_din),
        .q_a       (vram_dout),
        .clock_b   (clk_10mhz),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vram_rd_addr),
        .data_b    (8'h00),
        .q_b       (vram_rd_data)
    );

    logic [7:0] pixel_shift;

    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            pixel_shift <= 8'h00;
        end else if (pixel_en) begin
            if (x_pixel == 3'd7) begin
                pixel_shift <= vram_rd_data;
            end else begin
                pixel_shift <= {1'b0, pixel_shift[7:1]};
            end
        end
    end

    wire raw_pixel     = pixel_shift;
    wire invert_screen = video_ctrl;

    always_comb begin
        if (video_active) begin
            video_out = raw_pixel ^ invert_screen;
        end else begin
            video_out = 1'b0;
        end
    end

endmodule
