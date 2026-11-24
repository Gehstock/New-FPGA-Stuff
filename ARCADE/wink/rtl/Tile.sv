module Tile (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic        ce_pix,
    input  logic [8:0]  hcnt,
    input  logic [8:0]  vcnt,
    input  logic        tile_bank,
    output logic [9:0]  vram_addr,
    input  logic [7:0]  vram_data,
    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,
    output logic [3:0]  pixel_out
);

    wire [7:0] next_h = (hcnt >= 9'd376) ? 8'd0 : (hcnt[7:0] + 8'd8);
    wire [7:0] next_v = (hcnt >= 9'd376) ? ((vcnt == 9'd311) ? 8'd0 : (vcnt[7:0] + 8'd1)) : vcnt[7:0];
    assign vram_addr  = {next_v[7:3], next_h[7:3]};

    logic [9:0] tile_code;
    always_comb begin
        tile_code[7:0] = vram_data;
        tile_code[8] = (vram_addr < 10'h360) ? 1'b1 : 1'b0;
        tile_code[9] = tile_bank;
    end

    logic [12:0] rom_byte_offset;
    assign rom_byte_offset = {tile_code, next_v[2:0]};

    logic [15:0] plane_word_base;
    always_comb begin
        unique case (hcnt[2:0])
            3'd0, 3'd1, 3'd2: plane_word_base = 16'h5000;
            3'd3, 3'd4, 3'd5: plane_word_base = 16'h6000;
            default:          plane_word_base = 16'h7000;
        endcase
    end

    assign cpu3_addr = plane_word_base + {4'd0, rom_byte_offset[12:1]};

    logic [7:0] rom_byte;
    assign rom_byte = rom_byte_offset[0] ? cpu3_q[15:8] : cpu3_q[7:0];

    logic [7:0] buf_p0, buf_p1;
    logic [7:0] sh_p0, sh_p1, sh_p2;

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            buf_p0 <= 8'h00;
            buf_p1 <= 8'h00;
            sh_p0  <= 8'h00;
            sh_p1  <= 8'h00;
            sh_p2  <= 8'h00;
        end else if (ce_pix) begin
            if (hcnt[2:0] == 3'd2) buf_p0 <= rom_byte;
            if (hcnt[2:0] == 3'd5) buf_p1 <= rom_byte;

            if (hcnt[2:0] == 3'd7) begin
                sh_p0 <= buf_p0;
                sh_p1 <= buf_p1;
                sh_p2 <= rom_byte;
            end else begin
                sh_p0 <= {sh_p0[6:0], 1'b0};
                sh_p1 <= {sh_p1[6:0], 1'b0};
                sh_p2 <= {sh_p2[6:0], 1'b0};
            end
        end
    end

    assign pixel_out = {1'b0, sh_p2[7], sh_p1[7], sh_p0[7]};

endmodule

