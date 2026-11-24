module Tile (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic        ce_pix,
    input  logic [7:0]  hcnt,
    input  logic [7:0]  vcnt,

    output logic [9:0]  vram_addr,
    input  logic [7:0]  vram_data,

    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,

    output logic [4:0]  pixel_out
);

    logic [7:0] next_h;
    assign next_h    = hcnt;
    assign vram_addr = {next_h[7:3], ~vcnt[7:3]};

    logic [8:0] tile_code;
    assign tile_code = {1'b1, vram_data};

    logic [11:0] rom_byte_offset;
    assign rom_byte_offset = {tile_code, vcnt[2:0]};

    logic [15:0] plane_word_base;
    always_comb begin
        unique case (hcnt[2:1])
            2'b00:   plane_word_base = 16'h2000;
            2'b01:   plane_word_base = 16'h2800;
            default: plane_word_base = 16'h3000;
        endcase
    end

    assign cpu3_addr = plane_word_base + {5'd0, rom_byte_offset[11:1]};

    logic [7:0] rom_byte;
    assign rom_byte = rom_byte_offset[0] ? cpu3_q[15:8] : cpu3_q[7:0];

    logic [7:0] buf_p0, buf_p1, buf_p2;
    logic [7:0] sh_p0, sh_p1, sh_p2;

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            buf_p0 <= 8'h00; buf_p1 <= 8'h00; buf_p2 <= 8'h00;
            sh_p0  <= 8'h00; sh_p1  <= 8'h00; sh_p2  <= 8'h00;
        end else if (ce_pix) begin
            if (hcnt[2:0] == 3'b001) buf_p0 <= rom_byte;
            if (hcnt[2:0] == 3'b011) buf_p1 <= rom_byte;
            if (hcnt[2:0] == 3'b101) buf_p2 <= rom_byte;

            if (hcnt[2:0] == 3'b111) begin
                sh_p0 <= buf_p0;
                sh_p1 <= buf_p1;
                sh_p2 <= buf_p2;
            end else begin
                sh_p0 <= {1'b0, sh_p0[7:1]};
                sh_p1 <= {1'b0, sh_p1[7:1]};
                sh_p2 <= {1'b0, sh_p2[7:1]};
            end
        end
    end

	 assign pixel_out = {2'b01, sh_p0[0], sh_p1[0], sh_p2[0]};

endmodule
