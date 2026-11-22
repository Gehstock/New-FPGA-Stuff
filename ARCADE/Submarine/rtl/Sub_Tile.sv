module Sub_Tile (
    input  logic        clk_sys,
    input  logic        ce_pix,
    input  logic        flip_screen,
    input  logic [8:0]  mod_hc,
    input  logic [8:0]  mod_vc,
    output logic [9:0]  vram_addr,
    input  logic [7:0]  vram_data,
    input  logic [7:0]  attr_data,
    output logic [4:0]  scroll_addr,
    input  logic [7:0]  scroll_data,
    output logic [14:0] tile_rom_addr,
    input  logic [15:0] tile_rom_data,
    output logic [2:0]  tile_pixel,
    output logic [6:0]  tile_color
);

    logic [2:0]  step;
    logic [4:0]  fetch_col;
    logic [7:0]  scroll_reg;
    logic [7:0]  scroll_vc;

    logic [7:0]  code_next, attr_next;
    logic [7:0]  code_curr, attr_curr;

    logic [2:0]  tile_hc;
    logic [2:0]  tile_vc;
    logic [13:0] base_rom_addr;
    logic        rom_word_sel;

    logic [15:0] rom_lo_d1;
    logic [7:0]  rom0_data, rom1_data, rom2_data;

    always_comb begin
        step          = flip_screen ? ~mod_hc[2:0] : mod_hc[2:0];
        fetch_col     = flip_screen ? (mod_hc[7:3] - 5'd1) : (mod_hc[7:3] + 5'd1);
        scroll_addr   = fetch_col;
        scroll_vc     = flip_screen ? (mod_vc[7:0] - scroll_reg) : (mod_vc[7:0] + scroll_reg);
        vram_addr     = {scroll_vc[7:3], fetch_col};

        tile_hc       = flip_screen ? mod_hc[2:0] : ~mod_hc[2:0];
        tile_vc       = ~scroll_vc[2:0];
        base_rom_addr = {attr_next[7:5], code_next, tile_vc};
        tile_rom_addr = {base_rom_addr, rom_word_sel};

        tile_pixel    = {rom2_data[tile_hc], rom1_data[tile_hc], rom0_data[tile_hc]};
        tile_color    = {2'b10, attr_curr[4:0]};
    end

    always_ff @(posedge clk_sys) begin
        if (ce_pix) begin
            case (step)
                3'd0: rom_word_sel <= 1'b0;
                3'd1: scroll_reg   <= scroll_data;
                3'd3: begin
                    code_next <= vram_data;
                    attr_next <= attr_data;
                end
                3'd5: begin
                    rom_lo_d1    <= tile_rom_data;
                    rom_word_sel <= 1'b1;
                end
                3'd7: begin
                    rom0_data <= rom_lo_d1[7:0];
                    rom1_data <= rom_lo_d1[15:8];
                    rom2_data <= tile_rom_data[7:0];
                    code_curr <= code_next;
                    attr_curr <= attr_next;
                end
                default: ;
            endcase
        end
    end

endmodule
