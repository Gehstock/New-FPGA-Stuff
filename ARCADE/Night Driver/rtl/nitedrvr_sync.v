module nitedrvr_sync (
    input  wire         CLK12,
    input  wire         RESET,
    output reg          CLK6,
    output wire         CLK_STAR,
    output reg          HSYNC,
    output reg          VSYNC,
    output wire         HBLANK,
    output reg          VBLANK,
    output reg          IRQn,
    output reg [8:0] 	h_cnt,
    output reg [8:0] 	v_cnt
);

    reg       pix_en;
    reg       VRESET;
    wire [3:0] sync_prom_data;

    assign CLK_STAR = ~CLK12;

    always @(posedge CLK12) begin
        if (RESET) begin
            pix_en <= 1'b0;
            CLK6   <= 1'b0;
        end else begin
            pix_en <= !pix_en;
            if (pix_en) CLK6 <= !CLK6;
        end
    end

    always @(posedge CLK12) begin
        if (RESET) begin
            h_cnt <= 9'd0;
        end else if (pix_en) begin
            if (h_cnt == 9'd383) h_cnt <= 9'd0;
            else                 h_cnt <= h_cnt + 1'b1;
        end
    end


    always @(posedge CLK12) begin
        if (RESET) begin
            v_cnt <= 9'd0;
        end else if (pix_en && h_cnt == 9'd383) begin
            if (VRESET || v_cnt == 9'd261) v_cnt <= 9'd0;
            else                           v_cnt <= v_cnt + 1'b1;
        end
    end

    assign HBLANK = (h_cnt >= 9'd256);

    always @(posedge CLK12) begin
        if (pix_en) begin
            HSYNC <= ((h_cnt >= 9'd272) && (h_cnt < 9'd304));
        end
    end

    nitedrvr_sync_rom icH7 (
        .clk(CLK12),
        .addr({VBLANK, v_cnt[7:5],  v_cnt[3:0]}),
        .data(sync_prom_data)
    );

    always @(posedge CLK12) begin
        if (RESET) begin
            VRESET <= 1'b0;
            VSYNC  <= 1'b0;
            VBLANK <= 1'b0;
            IRQn   <= 1'b1;
        end else if (pix_en && h_cnt == 9'd383) begin
            VRESET <= sync_prom_data[0];
            VSYNC  <= sync_prom_data[1];
            VBLANK <= sync_prom_data[2];
            IRQn   <= !sync_prom_data[3];
        end
    end
endmodule
