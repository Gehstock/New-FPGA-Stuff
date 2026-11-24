module Video (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic        ce_pix,
    input  logic [9:0]  vram_addr,
    input  logic [7:0]  vram_din,
    input  logic        vram_we,
    output logic [7:0]  vram_dout,
    input  logic [4:0]  pal_addr,
    input  logic [7:0]  pal_din,
    input  logic        pal_we,
    input  logic        tile_bank,
    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,
    output logic [3:0]  red,
    output logic [3:0]  green,
    output logic [3:0]  blue,
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic        line_irq
);

    logic [8:0] hcnt;
    logic [8:0] vcnt;

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            hcnt     <= 9'd0;
            vcnt     <= 9'd0;
            line_irq <= 1'b0;
        end else if (ce_pix) begin
            line_irq <= 1'b0;
            if (hcnt == 9'd383) begin
                hcnt     <= 9'd0;
                line_irq <= 1'b1;
                if (vcnt == 9'd311) begin
                    vcnt <= 9'd0;
                end else begin
                    vcnt <= vcnt + 9'd1;
                end
            end else begin
                hcnt <= hcnt + 9'd1;
            end
        end
    end

    assign hblank = (hcnt >= 9'd256);
    assign vblank = (vcnt >= 9'd256);
    assign hsync  = (hcnt >= 9'd290 && hcnt < 9'd322);
    assign vsync  = (vcnt >= 9'd270 && vcnt < 9'd274);

    logic [9:0] vid_vram_addr;
    logic [7:0] vid_vram_dout;

    dpram #(10,8) vram_inst (
        .clk_a    (clk_sys),
        .enable_a (1'b1),
        .we_a     (vram_we),
        .addr_a   (vram_addr),
        .din_a    (vram_din),
        .dout_a   (vram_dout),
        .clk_b    (clk_sys),
        .enable_b (1'b1),
        .we_b     (1'b0),
        .addr_b   (vid_vram_addr),
        .din_b    (8'h00),
        .dout_b   (vid_vram_dout)
    );

    logic [3:0] tile_pix;
    Tile tile_inst (
        .clk_sys   (clk_sys),
        .reset     (reset),
        .ce_pix    (ce_pix),
        .hcnt      (hcnt),
        .vcnt      (vcnt),
        .tile_bank (tile_bank),
        .vram_addr (vid_vram_addr),
        .vram_data (vid_vram_dout),
        .cpu3_addr (cpu3_addr),
        .cpu3_q    (cpu3_q),
        .pixel_out (tile_pix)
    );

    logic [15:0] palette_ram [0:15];
    always_ff @(posedge clk_sys) begin
        if (pal_we) begin
            if (pal_addr[0] == 1'b0)
                palette_ram[pal_addr[4:1]][7:0]  <= pal_din;
            else
                palette_ram[pal_addr[4:1]][15:8] <= pal_din;
        end
    end

    logic [3:0]  final_idx;
    logic [15:0] pal_word;

    assign final_idx = tile_pix;
    assign pal_word  = palette_ram[final_idx];

    always_comb begin
        if (hblank || vblank) begin
            red   = 4'd0;
            green = 4'd0;
            blue  = 4'd0;
        end else begin
            blue  = pal_word[11:8];
            red   = pal_word[7:4];
            green = pal_word[3:0];
        end
    end

endmodule
