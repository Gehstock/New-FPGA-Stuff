module cheekyms_video (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        clk_vid_en,
    input  wire [7:0]  port_80_reg,
    input  wire        cpu_vram_wr,
    input  wire [9:0]  cpu_vram_addr,
    input  wire [7:0]  cpu_vram_data,
    output wire [7:0]  cpu_vram_rddata,
    input  wire        cpu_sram_wr,
    input  wire [4:0]  cpu_sram_addr,
    input  wire [7:0]  cpu_sram_data,
    output wire        vblank_irq,
    output reg         video_r,
    output reg         video_g,
    output reg         video_b,
    output wire        video_hs,
    output wire        video_vs,
    output wire        video_hb,
    output wire        video_vb
);

    localparam H_ACTIVE      = 9'd256;
    localparam H_FRONT_PORCH = 9'd8;
    localparam H_SYNC_PULSE  = 9'd24;
    localparam H_BACK_PORCH  = 9'd64;
    localparam H_TOTAL       = 9'd352;

    localparam V_TOP_BLANK   = 9'd32;
    localparam V_ACTIVE_END  = 9'd224;
    localparam V_SYNC_START  = 9'd244;
    localparam V_SYNC_END    = 9'd248;
    localparam V_TOTAL       = 9'd262;

    reg [8:0] h_cnt;
    reg [8:0] v_cnt;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 9'd0;
            v_cnt <= 9'd0;
        end else if (clk_vid_en) begin
            if (h_cnt == H_TOTAL) begin
                h_cnt <= 9'd0;
                if (v_cnt == V_TOTAL - 9'd1) v_cnt <= 9'd0;
                else                         v_cnt <= v_cnt + 9'd1;
            end else begin
                h_cnt <= h_cnt + 9'd1;
            end
        end
    end

    reg hb_q1;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            hb_q1 <= 1'b0;
        end else if (clk_vid_en) begin
            hb_q1 <= (h_cnt >= H_ACTIVE);
        end
    end

    assign video_hs   = (h_cnt >= (H_ACTIVE + H_FRONT_PORCH)) && (h_cnt < (H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE));
    assign video_vs   = (v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END);
    assign video_hb   = hb_q1;
    assign video_vb   = (v_cnt < V_TOP_BLANK) || (v_cnt >= V_ACTIVE_END);
    assign vblank_irq = (v_cnt >= V_ACTIVE_END);


    wire       tile_opaque;
    wire       tile_prio;
    wire [2:0] tile_rgb;

    cheekyms_tile u_tile (
        .clk_sys         (clk_sys),
        .clk_vid_en      (clk_vid_en),
        .h_cnt           (h_cnt),
        .v_cnt           (v_cnt),
        .port_80_reg     (port_80_reg),
        .cpu_vram_wr     (cpu_vram_wr),
        .cpu_vram_addr   (cpu_vram_addr),
        .cpu_vram_data   (cpu_vram_data),
        .cpu_vram_rddata (cpu_vram_rddata),
        .tile_opaque     (tile_opaque),
        .tile_prio       (tile_prio),
        .tile_rgb        (tile_rgb)
    );

    wire       sprite_opaque;
    wire [2:0] sprite_rgb;

    cheekyms_sprite u_sprite (
        .clk_sys       (clk_sys),
        .clk_vid_en    (clk_vid_en),
        .h_cnt         (h_cnt),
        .v_cnt         (v_cnt),
        .port_80_reg   (port_80_reg),
        .cpu_sram_wr   (cpu_sram_wr),
        .cpu_sram_addr (cpu_sram_addr),
        .cpu_sram_data (cpu_sram_data),
        .sprite_opaque (sprite_opaque),
        .sprite_rgb    (sprite_rgb)
    );

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            video_r <= 1'b0;
            video_g <= 1'b0;
            video_b <= 1'b0;
        end else if (clk_vid_en) begin
            if (video_hb || video_vb) begin
                video_r <= 1'b0;
                video_g <= 1'b0;
                video_b <= 1'b0;
            end else if (tile_opaque && tile_prio) begin
                video_r <= tile_rgb[0];
                video_g <= tile_rgb[1];
                video_b <= tile_rgb[2];
            end else if (sprite_opaque) begin
                video_r <= sprite_rgb[0];
                video_g <= sprite_rgb[1];
                video_b <= sprite_rgb[2];
            end else if (tile_opaque) begin
                video_r <= tile_rgb[0];
                video_g <= tile_rgb[1];
                video_b <= tile_rgb[2];
            end else begin
                video_r <= 1'b0;
                video_g <= 1'b0;
                video_b <= 1'b0;
            end
        end
    end

endmodule
