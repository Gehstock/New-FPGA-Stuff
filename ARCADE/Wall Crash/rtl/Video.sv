module Video (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic        ce_pix,

    input  logic [9:0]  vram_addr,
    input  logic [7:0]  vram_din,
    input  logic        vram_we,
    output logic [7:0]  vram_dout,

    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,

    output logic [3:0]  red,
    output logic [3:0]  green,
    output logic [3:0]  blue,
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank
);

    logic [8:0] hcnt;
    logic [8:0] vcnt;

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            hcnt <= 9'd0;
            vcnt <= 9'd0;
        end else if (ce_pix) begin
            if (hcnt == 9'd383) begin
                hcnt <= 9'd0;
                if (vcnt == 9'd311)
                    vcnt <= 9'd0;
                else
                    vcnt <= vcnt + 9'd1;
            end else begin
                hcnt <= hcnt + 9'd1;
            end
        end
    end

    assign hblank = (hcnt < 9'd8) || (hcnt >= 9'd264);
    assign vblank = (vcnt >= 9'd256);
    assign hsync  = (hcnt >= 9'd312 && hcnt < 9'd344);
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

    logic [4:0] tile_pix;
    Tile tile_inst (
        .clk_sys   (clk_sys),
        .reset     (reset),
        .ce_pix    (ce_pix),
        .hcnt      (hcnt[7:0]),
        .vcnt      (vcnt[7:0]),
        .vram_addr (vid_vram_addr),
        .vram_data (vid_vram_dout),
        .cpu3_addr (cpu3_addr),
        .cpu3_q    (cpu3_q),
        .pixel_out (tile_pix)
    );

    logic [7:0] prom_byte;
    col col_inst (
        .clk  (clk_sys),
        .addr (tile_pix),
        .data (prom_byte)
    );

    logic [3:0] prom_r, prom_g, prom_b;
    always_comb begin
        case (prom_byte[6:5])
            2'b00: prom_r = 4'h0;
            2'b01: prom_r = 4'h9;
            2'b10: prom_r = 4'h6;
            2'b11: prom_r = 4'hF;
        endcase
        case (prom_byte[3:2])
            2'b00: prom_g = 4'h0;
            2'b01: prom_g = 4'h9;
            2'b10: prom_g = 4'h6;
            2'b11: prom_g = 4'hF;
        endcase
        case ({prom_byte[7], prom_byte[1:0]})
            3'b000: prom_b = 4'h0;
            3'b001: prom_b = 4'h8;
            3'b010: prom_b = 4'h5;
            3'b011: prom_b = 4'hD;
            3'b100: prom_b = 4'h2;
            3'b101: prom_b = 4'hA;
            3'b110: prom_b = 4'h7;
            3'b111: prom_b = 4'hF;
        endcase
    end


    always_comb begin
        if (hblank || vblank) begin
            red   = 4'd0;
            green = 4'd0;
            blue  = 4'd0;
        end else begin
            red   = prom_r;
            green = prom_g;
            blue  = prom_b;
        end
    end

endmodule
