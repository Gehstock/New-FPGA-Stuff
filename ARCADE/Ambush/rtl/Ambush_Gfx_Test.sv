module Ambush_Gfx_Test (
    input  logic        clk_video,
    input  logic        h_blank,
    input  logic [8:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic        test_mode_16x16, // Umschalter: 1 = 16x16 Sprites, 0 = 8x8 Tiles
    output logic [12:0] test_rom_addr,   // Geht an addr_a und addr_b der Dual-Port ROMs
    input  logic [7:0]  rom_data_b0,     // Kommt von q_a (rom_gfx1 / fa1.m4)  should be fa1.l4
    input  logic [7:0]  rom_data_b1,     // Kommt von q_b (rom_gfx2 / fa2.n4)
    output logic [7:0]  video_color_idx
);

    // Interne Pixel-Offsets innerhalb einer Grafik-Kachel
    logic [3:0] tile_pixel_x;
    logic [3:0] tile_pixel_y;
    
    assign tile_pixel_x = h_cnt[3:0];
    assign tile_pixel_y = v_cnt[3:0];

    // Generierung des Kachelcodes basierend auf der Monitor-Position
    logic [7:0] auto_code;
    always_comb begin
        if (test_mode_16x16) begin
            // 16x16 Modus: Ein Sprite alle 16 Pixel horizontal und vertikal
            auto_code = {v_cnt[7:4], h_cnt[7:4]};
        end else begin
            // 8x8 Modus: Eine Kachel alle 8 Pixel horizontal und vertikal (Perfekter Stand aus Bild 1)
            auto_code = {v_cnt[6:3], h_cnt[6:3]};
        end
    end

    // Schaltplangetreue 13-Bit Adress-Generierung für die 8-KB-ROMs
    logic [12:0] calculated_addr;
    always_comb begin
        if (test_mode_16x16) begin
            // Behebt das gezeigte Chaos durch lineare 32-Byte-Objekt-Adressierung:
            calculated_addr = (auto_code << 5) 
                            + (tile_pixel_y[3] ? 13'd16 : 13'd0)  // Y-Offset: +16 Bytes für die untere Hälfte
                            + (tile_pixel_x[3] ? 13'd8  : 13'd0)  // X-Offset: +8 Bytes für die rechte Hälfte
                            + tile_pixel_y[2:0];                  // Zeilen-Index (0-7) im Quadranten
        end else begin
            // 8x8 Tile-Struktur (Das funktionierende Referenz-Timing)
            calculated_addr = {2'b00, auto_code[7:0], tile_pixel_y[2:0]};
        end
    end

    // Ausgabe der Test-Adresse an die Video-Top-Ebene
    assign test_rom_addr = calculated_addr;

    // Pipeline-Register zur exakten Kompensation der BlockRAM-Ausgangslatenz (1 Takt)
    logic [3:0] final_x_d1;
    logic       h_blank_d1;

    always_ff @(posedge clk_video) begin
        final_x_d1 <= tile_pixel_x;
        h_blank_d1 <= h_blank;
    end

    // Planare Pixelextraktion (Bit 7 ist links, Bit 0 ist rechts im Byte)
    logic [1:0] pixel_bit;
    assign pixel_bit = {rom_data_b1[3'd7 - final_x_d1[2:0]], rom_data_b0[3'd7 - final_x_d1[2:0]]};

    // Statische Farbzuweisung für das Testbild (Color-Bank 0, feste Palette)
    always_comb begin
        if (h_blank_d1 || (pixel_bit == 2'b00)) begin
            video_color_idx = 8'h00; // Hintergrund / Schwarz
        end else begin
            // Erzeugt ein gut sichtbares Farbmuster basierend auf den Pixelebenen
            video_color_idx = {2'b00, 4'h3, pixel_bit}; 
        end
    end

endmodule
