//`timescale 1ns / 1ps
//
//module draw_sprites (
//    input  logic        clk_12M,
//    input  logic        rst_n,
//    input  logic [7:0]  h_cnt,
//    input  logic [8:0]  v_cnt,
//    input  logic [7:0]  m_pos_ram [15:0], 
//    input  logic [7:0]  m_obj_ram [15:0], 
//    output logic        sprite_pixel,
//    output logic [1:0]  sprite_color
//);
//
//    logic [10:0] sprites_rom_addr;
//    logic [7:0]  sprites_rom_data;
//
//    m7 m7_inst (
//        .clk(clk_12M),
//        .addr(sprites_rom_addr),
//        .data(sprites_rom_data)
//    );
//
//    logic [4:0] v_calc [3:0];
//    logic       in_v_window [3:0];
//    logic       sprite_enabled [3:0];
//    logic       active [3:0];
//    logic [4:0] sprite_x [3:0];
//    logic [1:0] pixel_color_layer [3:0];
//
//    logic [4:0] sprite_x_delayed [3:0];
//    logic       active_delayed [3:0];
//    logic [7:0] last_h_cnt;
//
//    always_comb begin
//        sprites_rom_addr = '0;
//        for (int i = 0; i < 4; i++) begin
//            v_calc[i] = 5'(v_cnt - (m_pos_ram[8 + 2*i] - 8'd31));
//            
//            in_v_window[i] = (v_cnt >= (m_pos_ram[8 + 2*i] - 8'd31)) && 
//                             (v_cnt <  (m_pos_ram[8 + 2*i] + 8'd1));
//                             
//            sprite_enabled[i] = m_obj_ram[8 + 2*i + 1][0];            
//            if (active[i]) begin
//                sprites_rom_addr = { (m_obj_ram[8 + 2*i][2:0] ^ 3'h7), v_calc[i], sprite_x[i][4:2] };
//            end
//        end
//    end
//
//    always_ff @(posedge clk_12M or negedge rst_n) begin
//        if (!rst_n) begin
//            last_h_cnt <= '0;
//            for (int i = 0; i < 4; i++) begin
//                active[i]            <= 1'b0;
//                sprite_x[i]          <= '0;
//                active_delayed[i]    <= 1'b0;
//                sprite_x_delayed[i]  <= '0;
//                pixel_color_layer[i] <= '0;
//            end
//        end else begin
//            last_h_cnt <= h_cnt;
//
//            for (int i = 0; i < 4; i++) begin
//                active_delayed[i]    <= active[i];
//                sprite_x_delayed[i]  <= sprite_x[i];
//
//                if (in_v_window[i] && sprite_enabled[i]) begin
//                    if (h_cnt == (({1'b0, m_pos_ram[8 + 2*i + 1]} >= 9'd31) ? ((m_pos_ram[8 + 2*i + 1] - 8'd31) >> 1) : 8'd0)) begin
//                        active[i]   <= 1'b1;
//                        sprite_x[i] <= '0;
//                    end
//                    else if (active[i] && (h_cnt != last_h_cnt)) begin
//                        if (sprite_x[i] == 5'd31) begin
//                            active[i] <= 1'b0;
//                        end else begin
//                            sprite_x[i] <= sprite_x[i] + 1'b1;
//                        end
//                    end
//                end else begin
//                    active[i] <= 1'b0;
//                end
//
//                if (active_delayed[i]) begin
//                    case (sprite_x_delayed[i][1:0])
//                        2'd0: pixel_color_layer[i] <= sprites_rom_data[7:6];
//                        2'd1: pixel_color_layer[i] <= sprites_rom_data[5:4];
//                        2'd2: pixel_color_layer[i] <= sprites_rom_data[3:2];
//                        2'd3: pixel_color_layer[i] <= sprites_rom_data[1:0];
//                    endcase
//                end else begin
//                    pixel_color_layer[i] <= '0;
//                end
//            end
//        end
//    end
//
//    always_comb begin
//        sprite_pixel = 1'b0;
//        sprite_color = 2'b00;
//        for (int i = 3; i >= 0; i--) begin
//            if (pixel_color_layer[i] != 2'b10 && pixel_color_layer[i] != 2'b00) begin 
//                sprite_pixel = 1'b1;
//                sprite_color = pixel_color_layer[i];
//            end
//        end
//    end
//
//endmodule



//`timescale 1ns / 1ps
//
//module draw_sprites (
//    input  logic        clk_12M,
//    input  logic        rst_n,
//    input  logic [7:0]  h_cnt,
//    input  logic [8:0]  v_cnt,
//    input  logic [7:0]  m_pos_ram [15:0], 
//    input  logic [7:0]  m_obj_ram [15:0], 
//    output logic        sprite_pixel,
//    output logic [1:0]  sprite_color
//);
//
//    // Array, um den ROM-Adresskonflikt zwischen den 4 Sprites sauber aufzulösen
//    logic [10:0] sprites_rom_addr [3:0];
//    logic [7:0]  sprites_rom_data [3:0];
//
//    // 4 parallele Instanzen, damit jedes Sprite seine eigene Adresse anlegen kann
//    genvar g;
//    generate
//        for (g = 0; g < 4; g++) begin : sprite_roms
//            m7 m7_inst (
//                .clk(clk_12M),
//                .addr(sprites_rom_addr[g]),
//                .data(sprites_rom_data[g])
//            );
//        end
//    endgenerate
//
//    // Scaling-Register (Akkumulatoren)
//    logic [11:0] v_accumulator [3:0]; 
//    logic [11:0] h_accumulator [3:0]; 
//    logic [7:0]  scale_factor [3:0];
//
//    logic [4:0] v_calc [3:0];
//    logic       in_v_window [3:0];
//    logic       sprite_enabled [3:0];
//    logic       active [3:0];
//    logic [4:0] sprite_x [3:0];
//    logic [1:0] pixel_color_layer [3:0];
//
//    logic [4:0] sprite_x_delayed [3:0];
//    logic       active_delayed [3:0];
//    logic [7:0] last_h_cnt;
//
//    always_comb begin
//        for (int i = 0; i < 4; i++) begin
//            // Hole den Skalierungsfaktor aus dem RAM (Laut Atari-Hardware oft im Flag- oder Objekt-RAM)
//            scale_factor[i] = m_obj_ram[8 + 2*i + 1]; 
//
//            // Standard-Fensterprüfung
//            in_v_window[i] = (v_cnt >= (m_pos_ram[8 + 2*i] - 8'd31)) && 
//                             (v_cnt <  (m_pos_ram[8 + 2*i] + 8'd1));
//                             
//            sprite_enabled[i] = m_obj_ram[8 + 2*i + 1][0];            
//            
//            // Adressierung (Exakt wie in deinem Original, nur getrennt pro ROM-Kanal)
//            // Nutzt v_calc aus dem Akkumulator
//            sprites_rom_addr[i] = 11'({ (m_obj_ram[8 + 2*i][2:0] ^ 3'h7), v_calc[i], sprite_x[i][4:2] });
//        end
//    end
//
//    always_ff @(posedge clk_12M or negedge rst_n) begin
//        if (!rst_n) begin
//            last_h_cnt <= '0;
//            for (int i = 0; i < 4; i++) begin
//                active[i]            <= 1'b0;
//                sprite_x[i]          <= '0;
//                active_delayed[i]    <= 1'b0;
//                sprite_x_delayed[i]  <= '0;
//                pixel_color_layer[i] <= '0;
//                v_accumulator[i]     <= '0;
//                h_accumulator[i]     <= '0;
//                v_calc[i]            <= '0;
//            end
//        end else begin
//            last_h_cnt <= h_cnt;
//
//            for (int i = 0; i < 4; i++) begin
//                active_delayed[i]    <= active[i];
//                sprite_x_delayed[i]  <= sprite_x[i];
//
//                // --- VERTIKALES SCALING (Y-Achse) ---
//                if (v_cnt == (m_pos_ram[8 + 2*i] - 8'd31)) begin
//                    v_accumulator[i] <= '0;
//                    v_calc[i]        <= '0;
//                end 
//                // Am Ende jeder Zeile (H-Blank / Zeilensprung) addieren wir den Skalierungsfaktor
//                else if (in_v_window[i] && (h_cnt == 0 && last_h_cnt != 0)) begin
//                    automatic logic [11:0] next_v_acc = v_accumulator[i] + scale_factor[i];
//                    v_accumulator[i] <= next_v_acc;
//                    v_calc[i]        <= next_v_acc[11:7]; // Obere Bits bestimmen die aktuelle ROM-Zeile
//                end
//
//                // --- HORIZONTALES SCALING (X-Achse) ---
//                if (in_v_window[i] && sprite_enabled[i]) begin
//                    // Start-Bedingung
//                    if (h_cnt == (({1'b0, m_pos_ram[8 + 2*i + 1]} >= 9'd31) ? ((m_pos_ram[8 + 2*i + 1] - 8'd31) >> 1) : 8'd0)) begin
//                        active[i]        <= 1'b1;
//                        h_accumulator[i] <= '0;
//                        sprite_x[i]      <= '0;
//                    end
//                    // Wenn aktiv, erhöhen wir sprite_x basierend auf dem Skalierungs-Akkumulator
//                    else if (active[i] && (h_cnt != last_h_cnt)) begin
//                        automatic logic [11:0] next_h_acc = h_accumulator[i] + scale_factor[i];
//                        h_accumulator[i] <= next_h_acc;
//                        sprite_x[i]      <= next_h_acc[11:7]; // Obere Bits bestimmen den Pixelvorschub
//
//                        if (next_h_acc[11:7] >= 5'd31) begin
//                            active[i] <= 1'b0;
//                        end
//                    end
//                end else begin
//                    active[i] <= 1'b0;
//                end
//
//                // Pixel-Muxer (Exakt dein funktionierender Original-Code)
//                if (active_delayed[i]) begin
//                    case (sprite_x_delayed[i][1:0])
//                        2'd0: pixel_color_layer[i] <= sprites_rom_data[i][7:6];
//                        2'd1: pixel_color_layer[i] <= sprites_rom_data[i][5:4];
//                        2'd2: pixel_color_layer[i] <= sprites_rom_data[i][3:2];
//                        2'd3: pixel_color_layer[i] <= sprites_rom_data[i][1:0];
//                    endcase
//                end else begin
//                    pixel_color_layer[i] <= '0;
//                end
//            end
//        end
//    end
//
//    // Ausgabe-Priorität (Exakt dein Original-Code)
//    always_comb begin
//        sprite_pixel = 1'b0;
//        sprite_color = 2'b00;
//        for (int i = 3; i >= 0; i--) begin
//            if (pixel_color_layer[i] != 2'b10 && pixel_color_layer[i] != 2'b00) begin 
//                sprite_pixel = 1'b1;
//                sprite_color = pixel_color_layer[i];
//            end
//        end
//    end
//
//endmodule
`timescale 1ns / 1ps

module draw_sprites (
    input  logic        clk_12M,
    input  logic        rst_n,
    input  logic [7:0]  h_cnt,
    input  logic [8:0]  v_cnt,
    input  logic [7:0]  m_pos_ram [15:0], 
    input  logic [7:0]  m_obj_ram [15:0], 
    output logic        sprite_pixel,
    output logic [1:0]  sprite_color
);

    logic [10:0] sprites_rom_addr;
    logic [7:0]  sprites_rom_data;

    m7 m7_inst (
        .clk(clk_12M),
        .addr(sprites_rom_addr),
        .data(sprites_rom_data)
    );

    // DDA-Akkumulatoren für stufenloses Zoomen
    logic [15:0] v_accumulator [3:0];
    logic [15:0] h_accumulator [3:0];
    logic [7:0]  dynamic_scale [3:0];

    logic [4:0] v_calc [3:0];
    logic       in_v_window [3:0];
    logic       sprite_enabled [3:0];
    logic       active [3:0];
    logic [4:0] sprite_x [3:0];
    logic [1:0] pixel_color_layer [3:0];

    logic [4:0] sprite_x_delayed [3:0];
    logic       active_delayed [3:0];
    logic [7:0] last_h_cnt;

    always_comb begin
        sprites_rom_addr = '0;
        for (int i = 0; i < 4; i++) begin
            // Mathematisch stufenloser Zoom basierend auf der vertikalen Position (v_cnt)
            // Horizont (oben) -> Kleiner Wert (Dehnung). Unten -> Großer Wert (1:1)
            dynamic_scale[i] = 8'd40 + 8'(((10'd215 * v_cnt) >> 8));

            // Originale Fensterprüfung aus deinem Startcode
            in_v_window[i] = (v_cnt >= (m_pos_ram[8 + 2*i] - 8'd31)) && 
                             (v_cnt <  (m_pos_ram[8 + 2*i] + 8'd1));
                             
            // Fix für die Truncation-Warnung mittels expliziter Bit-Selektion [0]
            sprite_enabled[i] = m_obj_ram[8 + 2*i + 1][0];            
            
            // Deine ORIGINALE, funktionierende ROM-Adressierung (Kein Kopfstand mehr!)
            if (active[i]) begin
                sprites_rom_addr = { (m_obj_ram[8 + 2*i][2:0] ^ 3'h7), v_calc[i], sprite_x[i][4:2] };
            end
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            last_h_cnt <= '0;
            for (int i = 0; i < 4; i++) begin
                active[i]            <= 1'b0;
                sprite_x[i]          <= '0;
                active_delayed[i]    <= 1'b0;
                sprite_x_delayed[i]  <= '0;
                pixel_color_layer[i] <= '0;
                v_accumulator[i]     <= '0;
                h_accumulator[i]     <= '0;
                v_calc[i]            <= '0;
            end
        end else begin
            last_h_cnt <= h_cnt;

            for (int i = 0; i < 4; i++) begin
                active_delayed[i]    <= active[i];
                sprite_x_delayed[i]  <= sprite_x[i];

                // --- VERTIKALES SCALING (Y-Achse) ---
                if (v_cnt == (m_pos_ram[8 + 2*i] - 8'd31)) begin
                    v_accumulator[i] <= '0;
                    v_calc[i]        <= '0;
                end 
                // Einmal pro Zeilensprung aufaddieren
                else if (in_v_window[i] && (h_cnt == 0 && last_h_cnt != 0)) begin
                    automatic logic [15:0] next_v_acc = v_accumulator[i] + {8'b0, dynamic_scale[i]};
                    v_accumulator[i] <= next_v_acc;
                    v_calc[i]        <= next_v_acc[11:7]; 
                end

                // --- HORIZONTALES SCALING (X-Achse) ---
                if (in_v_window[i] && sprite_enabled[i]) begin
                    // Start-Trigger aus deinem funktionierenden Originalcode
                    if (h_cnt == (({1'b0, m_pos_ram[8 + 2*i + 1]} >= 9'd31) ? ((m_pos_ram[8 + 2*i + 1] - 8'd31) >> 1) : 8'd0)) begin
                        active[i]        <= 1'b1;
                        h_accumulator[i] <= '0;
                        sprite_x[i]      <= '0;
                    end
                    // KORREKTUR: Der Akkumulator läuft jetzt frei mit clk_12M durch, 
                    // anstatt an last_h_cnt zu kleben. Das aktiviert das echte Hardware-Scaling.
                    else if (active[i]) begin
                        automatic logic [15:0] next_h_acc = h_accumulator[i] + {8'b0, dynamic_scale[i]};
                        h_accumulator[i] <= next_h_acc;
                        sprite_x[i]      <= next_h_acc[11:7]; // Schaltet den Pixelpointer skaliert weiter

                        if (next_h_acc[11:7] >= 5'd31) begin
                            active[i] <= 1'b0;
                        end
                    end
                end else begin
                    active[i] <= 1'b0;
                end

                // Deine originale Pixel-Auswahl (Absolut unverändert)
                if (active_delayed[i]) begin
                    case (sprite_x_delayed[i][1:0])
                        2'd0: pixel_color_layer[i] <= sprites_rom_data[7:6];
                        2'd1: pixel_color_layer[i] <= sprites_rom_data[5:4];
                        2'd2: pixel_color_layer[i] <= sprites_rom_data[3:2];
                        2'd3: pixel_color_layer[i] <= sprites_rom_data[1:0];
                    endcase
                end else begin
                    pixel_color_layer[i] <= '0;
                end
            end
        end
    end

    // Ausgangs-Muxer aus deinem Originalcode
    always_comb begin
        sprite_pixel = 1'b0;
        sprite_color = 2'b00;
        for (int i = 3; i >= 0; i--) begin
            if (pixel_color_layer[i] != 2'b10 && pixel_color_layer[i] != 2'b00) begin 
                sprite_pixel = 1'b1;
                sprite_color = pixel_color_layer[i];
            end
        end
    end

endmodule
