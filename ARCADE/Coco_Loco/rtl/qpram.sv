// ==========================================================================
// Modul: qpram (VERSION 3: VOLLSTÄNDIGE HARDWARE-ENTKOPPLUNG)
// Beschreibung: Nutzt 3 physische RAM-Instanzen. Port A schreibt parallel 
//               in alle drei. Die Ports B, C und D lesen komplett autark
//               ohne jegliche Logikgatter oder Multiplexer dazwischen.
// ==========================================================================

module qpram #(
    parameter address_width = 13,   // 8192 Wörter tief
    parameter data_width    = 8     // 8-Bit Breite
) (
    input   wire                        clock,
    
    // Port A: CPU Schreib- und Lesepfad (Spiegelt parallel in ALLE drei RAMs)
    input   wire                        enable_a,
    input   wire                        wren_a,
    input   wire    [address_width-1:0] address_a,
    input   wire    [data_width-1:0]    data_a,
    output  wire    [data_width-1:0]    q_a,
    
    // Port B: Video Renderer Plane 0 (Direkter M9K Hardware-Pfad)
    input   wire                        enable_b,
    input   wire    [address_width-1:0] address_b,
    output  wire    [data_width-1:0]    q_b,
    
    // Port C: Video Renderer Plane 1 (Direkter M9K Hardware-Pfad)
    input   wire                        enable_c,
    input   wire    [address_width-1:0] address_c,
    output  wire    [data_width-1:0]    q_c,
    
    // Port D: Video Renderer Plane 2 (Direkter M9K Hardware-Pfad)
    input   wire                        enable_d,
    input   wire    [address_width-1:0] address_d,
    output  wire    [data_width-1:0]    q_d
);

    // ----------------------------------------------------------------------
    // RAM 1: Bedient CPU (Port A) und Video Plane 0 (Port B)
    // ----------------------------------------------------------------------
    dpram_backend #(
        .address_width(address_width),
        .data_width(data_width)
    ) ram_inst_1 (
        .clock     (clock),
        .enable_1  (enable_a),
        .wren_1    (wren_a),
        .address_1 (address_a),
        .data_1    (data_a),
        .q_1       (q_a),       // CPU liest hieraus
        
        .enable_2  (enable_b),
        .wren_2    (1'b0),      
        .address_2 (address_b),
        .data_2    ({data_width{1'b0}}),
        .q_2       (q_b)        // Plane 0
    );

    // ----------------------------------------------------------------------
    // RAM 2: Bedient CPU-Schreiben und Video Plane 1 (Port C)
    // Keine geteilte Logik! Reines paralleles Mitschreiben der CPU.
    // ----------------------------------------------------------------------
    dpram_backend #(
        .address_width(address_width),
        .data_width(data_width)
    ) ram_inst_2 (
        .clock     (clock),
        .enable_1  (enable_a && wren_a), // Aktiv nur wenn CPU tatsächlich schreibt
        .wren_1    (wren_a), 
        .address_1 (address_a),
        .data_1    (data_a),
        .q_1       (),          // Unbenutzt, CPU liest nur aus RAM 1
        
        .enable_2  (enable_c),
        .wren_2    (1'b0),      
        .address_2 (address_c),
        .data_2    ({data_width{1'b0}}),
        .q_2       (q_c)        // Plane 1
    );

    // ----------------------------------------------------------------------
    // RAM 3: Bedient CPU-Schreiben und Video Plane 2 (Port D)
    // ----------------------------------------------------------------------
    dpram_backend #(
        .address_width(address_width),
        .data_width(data_width)
    ) ram_inst_3 (
        .clock     (clock),
        .enable_1  (enable_a && wren_a), 
        .wren_1    (wren_a), 
        .address_1 (address_a),
        .data_1    (data_a),
        .q_1       (),          // Unbenutzt
        
        .enable_2  (enable_d),
        .wren_2    (1'b0),      
        .address_2 (address_d),
        .data_2    ({data_width{1'b0}}),
        .q_2       (q_d)        // Plane 2
    );

endmodule

// ==========================================================================
// Hilfsmodul: dpram_backend (Natives True Dual-Port RAM für Altera M9K)
// ==========================================================================
module dpram_backend #(
    parameter address_width = 13,
    parameter data_width    = 8
) (
    input   wire                        clock,
    input   wire                        enable_1,
    input   wire                        wren_1,
    input   wire    [address_width-1:0] address_1,
    input   wire    [data_width-1:0]    data_1,
    output  reg     [data_width-1:0]    q_1,
    
    input   wire                        enable_2,
    input   wire                        wren_2,
    input   wire    [address_width-1:0] address_2,
    input   wire    [data_width-1:0]    data_2,
    output  reg     [data_width-1:0]    q_2
);

    (* ramstyle = "no_rw_check" *) 
    reg [data_width-1:0] mem [0:(2**address_width)-1];

    always_ff @(posedge clock) begin
        if (enable_1) begin
            if (wren_1) begin
                mem[address_1] <= data_1;
            end
            q_1 <= mem[address_1];
        end
    end

    always_ff @(posedge clock) begin
        if (enable_2) begin
            if (wren_2) begin
                mem[address_2] <= data_2;
            end
            q_2 <= mem[address_2];
        end
    end

endmodule
