module mouser_video (
    input  logic        clk_sys,
    input  logic        rst_n,
    input  logic        video_clken,
    input  logic        flip_x,
    input  logic        flip_y,
    
    input  logic [7:0]  vram_data,
    input  logic [7:0]  cram_data,
    input  logic [7:0]  spriteram_data,
    
    output logic [9:0]  video_ram_addr,
    output logic [9:0]  video_cram_addr,
    output logic [7:0]  video_spram_addr,
    
    output logic        video_hs,
    output logic        video_vs,
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b,
    output logic        video_hb,
    output logic        video_vb
);

    logic [8:0] h_count;
    logic [8:0] v_count;
    logic       blank;
    
    logic video_hb_pipe0, video_vb_pipe0;
    
    logic       gfx_p0, gfx_p1;
    logic [3:0] gfx_color_idx;
    
    logic [5:0] prom_addr;
    logic [7:0] prom_data;

	 assign video_hb = (h_count <= 9'd1) || (h_count >= 9'd258);
    assign video_vb = (v_count < 9'd16) || (v_count >= 9'd240);

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            video_hb_pipe0 <= 1'b1;
            video_vb_pipe0 <= 1'b1;
        end else if (video_clken) begin
            video_hb_pipe0 <= video_hb;     
            video_vb_pipe0 <= video_vb;
        end
    end

	 assign blank = video_hb_pipe0 || video_vb_pipe0;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 9'd0;
        end else if (video_clken) begin
            if (h_count == 9'd375) h_count <= 9'd0;
            else                   h_count <= h_count + 9'd1;
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            v_count <= 9'd0;
        end else if (video_clken && (h_count == 9'd375)) begin
            if (v_count == 9'd259) v_count <= 9'd0;
            else                   v_count <= v_count + 9'd1;
        end
    end

    assign video_hs = (h_count >= 9'd280 && h_count < 9'd312) ? 1'b0 : 1'b1;
    assign video_vs = (v_count >= 9'd242 && v_count < 9'd245) ? 1'b0 : 1'b1;

    mouser_gfx graphics_generator (
        .clk_sys(clk_sys),
        .video_clken(video_clken),
        .flip_x(flip_x),
        .flip_y(flip_y),
        .vram_data(vram_data),
        .cram_data(cram_data),
        .spriteram_data(spriteram_data),
        .spriteram_addr(video_spram_addr),
        .video_ram_addr(video_ram_addr),
        .video_cram_addr(video_cram_addr),
        .h_count(h_count),
        .v_count(v_count),
        .gfx_p0(gfx_p0),
        .gfx_p1(gfx_p1),
        .gfx_color_idx(gfx_color_idx)
    );

    assign prom_addr = {gfx_color_idx[3:0], gfx_p1, gfx_p0};

    col_prom inst_col_prom (
        .clk(clk_sys),
        .addr(prom_addr),
        .data(prom_data)
    );

    always_comb begin
        if (blank) begin
            video_r = 3'b000;
            video_g = 3'b000;
            video_b = 3'b000;
        end else begin
            video_r = prom_data[2:0];
            video_g = prom_data[5:3];
            video_b = {prom_data[7:6], 1'b0};
        end
    end

endmodule
