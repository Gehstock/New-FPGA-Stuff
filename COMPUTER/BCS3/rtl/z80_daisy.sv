//Gehstock 2024
`timescale 1 ps / 1 ps
`default_nettype none

interface z80_daisy_bus;
    logic iei;
    logic ieo;
endinterface

module z80_daisy (
    input  logic        clk,
    input  logic        rst_n,
    
    // Z80 CPU Kontrollsignale
    input  logic        m1_n,
    input  logic        iorq_n,
    input  logic [7:0]  data_in,
    
    // Daisy-Chain Signale
    input  logic        iei,
    output logic        ieo,
    
    // Interne Statussignale des Peripheriegeräts
    input  logic        irq_req,     // Gerät möchte Interrupt auslösen
    output logic        irq_active,  // Gerät befindet sich in der Interrupt-Abarbeitung
    output logic        int_n        // Geht an die CPU INT_N Leitung
);

    // Zustandstracking für die RETI-Erkennung
    typedef enum logic { IDLE, ED_FETCHED } state_t;
    state_t state;

    logic irq_pending; // Interrupt angefordert, aber noch nicht quittiert
    logic irq_ius;     // In Service (Interrupt wird gerade abgearbeitet)

    // IEO Logik: Blockiere nachfolgende Geräte, wenn wir einen IRQ erwarten oder bedienen
    assign ieo = iei && !irq_pending && !irq_ius;
    
    // Wenn wir die höchste Priorität haben (iei=1) und einen IRQ wollen, ziehen wir INT_N gegen Masse
    assign int_n = (iei && irq_pending) ? 1'b0 : 1'b1; 
    assign irq_active = irq_ius;

    // RETI Dekodierer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            irq_pending <= 1'b0;
            irq_ius     <= 1'b0; // KORREKTUR: Nach Reset bereit für neue Interrupts
        end else begin
            // 1. Interrupt-Anforderung puffern (auch wenn aktuell ein IRQ abgearbeitet wird)
            if (irq_req) begin
                irq_pending <= 1'b1;
            end

            // 2. Interrupt Acknowledge Zyklus der Z80 CPU (M1 und IORQ gleichzeitig aktiv)
            if (!m1_n && !iorq_n) begin
                if (iei && irq_pending) begin
                    irq_pending <= 1'b0;
                    irq_ius     <= 1'b1; // Gehe in den "In-Service" Zustand
                end
            end

            // 3. RETI Befehlserkennung (0xED gefolgt von 0x4D im M1-Zyklus)
            if (!m1_n && iorq_n) begin // Normaler Opcode Fetch
                case (state)
                    IDLE: begin
                        if (data_in == 8'hED) begin
                            state <= ED_FETCHED;
                        end
                    end
                    
                    ED_FETCHED: begin
                        if (data_in == 8'h4D) begin
                            // RETI erkannt! Wenn wir das aktiv bediente Gerät mit der höchsten Prio sind, IUS freigeben
                            // Hinweis: MAME prüft hier zusätzlich, ob 'iei' aktiv ist, um zu wissen, wer gemeint ist
                            if (iei && irq_ius) begin
                                irq_ius <= 1'b0;
                            end
                            state <= IDLE;
                        end else if (data_in == 8'hED) begin
                            // Falls direkt wieder ein 0xED folgt, bleiben wir im ED_FETCHED Zustand
                            state <= ED_FETCHED;
                        end else begin
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule
`default_nettype wire
