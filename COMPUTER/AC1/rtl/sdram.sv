`timescale 1 ps / 1 ps
`default_nettype none

module sdram #(
    parameter int MHZ = 80 // 80 MHz Standardtakt
) (
    // Schnittstelle zum physischen MT48LC16M16-Chip (Pins am FPGA)
    inout  logic [15:0] SDRAM_DQ,   // 16-Bit bidirektionaler Datenbus
    output logic [12:0] SDRAM_A,    // 13-Bit multiplexierter Adressbus
    output logic        SDRAM_DQML, // Byte-Maske Low
    output logic        SDRAM_DQMH, // Byte-Maske High
    output logic [1:0]  SDRAM_BA,   // Bank-Auswahl (2 Banks)
    output logic        SDRAM_nCS,  // Chip Select (Aktiv Low)
    output logic        SDRAM_nWE,  // Write Enable (Aktiv Low)
    output logic        SDRAM_nRAS, // Row Address Select (Aktiv Low)
    output logic        SDRAM_nCAS, // Column Address Select (Aktiv Low)

    // CPU / Chipset Schnittstelle (FPGA-intern)
    input  logic        init_n,     // Init-Signal nach FPGA-Konfiguration (Aktiv Low)
    input  logic        clk,        // SDRAM-Takt (z. B. 80 MHz)

    input  logic        port1_req,  // Anforderung (Wechselt den Zustand bei Zugriff)
    output logic        port1_ack,  // Bestätigung vom Controller (Gleicht sich req an)
    input  logic        port1_we,   // 1 = Schreiben, 0 = Lesen
    input  logic [24:1] port1_a,    // 24-Bit Wortadresse
    input  logic [1:0]  port1_ds,   // Data Strobe / Byte-Auswahl (Bit 0 = Low Byte, Bit 1 = High Byte)
    input  logic [15:0] port1_d,    // Schreibdaten von der CPU
    output logic [15:0] port1_q     // Lesedaten zur CPU
);

    // Konstanten für die SDRAM-Initialisierung (Mode Register)
    localparam bit [2:0] RASCAS_DELAY   = 3'd1;   // tRCD = 20ns -> 1 Zyklus @ < 50MHz
    localparam bit [2:0] BURST_LENGTH   = 3'b000; // 000 = 1 Word Burst
    localparam bit       ACCESS_TYPE    = 1'b0;   // 0 = Sequential, 1 = Interleaved
    localparam bit [2:0] CAS_LATENCY    = 3'd2;   // CL2
    localparam bit [1:0] OP_MODE        = 2'b00;  // Standard-Betrieb
    localparam bit       NO_WRITE_BURST = 1'b1;   // 1 = Nur Single Access Write

    localparam bit [12:0] MODE = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

    // Aktualisierungsrate: 64ms / 8192 Zeilen = 7.8µs
    localparam int RFRSH_CYCLES = (78 * MHZ) / 10;

    // ==========================================
    // Zustandsmaschine (Cycle State Machine)
    // ==========================================
    localparam bit [2:0] STATE_RAS0  = 3'd0;
    localparam bit [2:0] STATE_CAS0  = STATE_RAS0 + RASCAS_DELAY + 1'b1; // CAS-Phase (3)
    localparam bit [2:0] STATE_READ0 = STATE_CAS0 + CAS_LATENCY + 1'b1; // Daten rückgabe (6)
    localparam bit [2:0] STATE_LAST  = 3'd5;

    logic [2:0] t;

    always_ff @(posedge clk) begin
        t <= t + 3'd1;
        if (t == STATE_LAST) t <= STATE_RAS0;
        if (t == STATE_RAS0 && !init && !port1_active && !need_refresh) t <= STATE_RAS0;
    end

    // ==========================================
    // Startup / Reset-Logik
    // ==========================================
    logic [4:0] reset_reg;
    logic       init;

    always_ff @(posedge clk or negedge init_n) begin
        if (!init_n) begin
            reset_reg <= 5'h1f;
            init      <= 1'b1;
        end else begin
            if ((t == STATE_LAST) && (reset_reg != 5'd0)) begin
                reset_reg <= reset_reg - 5'd1;
            end
            init <= (reset_reg != 5'd0);
        end
    end

    // ==========================================
    // RAM-Steuersignale & Register
    // ==========================================
    localparam bit [3:0] CMD_NOP          = 4'b0111;
    localparam bit [3:0] CMD_ACTIVE       = 4'b0011;
    localparam bit [3:0] CMD_READ         = 4'b0101;
    localparam bit [3:0] CMD_WRITE        = 4'b0100;
    localparam bit [3:0] CMD_PRECHARGE    = 4'b0010;
    localparam bit [3:0] CMD_AUTO_REFRESH = 4'b0001;
    localparam bit [3:0] CMD_LOAD_MODE    = 4'b0000;

    logic [3:0]  sd_cmd; // Aktueller Befehl an den Chip

    assign SDRAM_nCS  = sd_cmd[3];
    assign SDRAM_nRAS = sd_cmd[2];
    assign SDRAM_nCAS = sd_cmd[1];
    assign SDRAM_nWE  = sd_cmd[0];

    logic [24:1] addr_latch;
    logic [15:0] din_latch;
    logic        oe_latch;
    logic        we_latch;
    logic [1:0]  ds;

    logic [10:0] refresh_cnt;
    logic        need_refresh;
    assign need_refresh = (refresh_cnt >= RFRSH_CYCLES);

    logic        refresh; // Für Synthese-Pragmas erhalten
    logic        port1_active;
    assign port1_active = port1_req ^ port1_ack;

    // Hauptsteuerblock
    always_ff @(posedge clk) begin
        SDRAM_DQ    <= 16'bZZZZZZZZZZZZZZZZ;
        {SDRAM_DQMH, SDRAM_DQML} <= 2'b11;
        sd_cmd      <= CMD_NOP; // Standard: Keine Operation
        refresh_cnt <= refresh_cnt + 11'd1;

        if (init) begin
            refresh_cnt <= '0;
            refresh     <= 1'b0;
            if (t == STATE_RAS0) begin
                if (reset_reg == 5'd15) begin
                    sd_cmd <= CMD_PRECHARGE;
                    SDRAM_A[10] <= 1'b1; // Alle Banken vorladen
                end
                if (reset_reg == 5'd10 || reset_reg == 5'd8) begin
                    sd_cmd <= CMD_AUTO_REFRESH;
                end
                if (reset_reg == 5'd2) begin
                    sd_cmd   <= CMD_LOAD_MODE;
                    SDRAM_A  <= MODE;
                    SDRAM_BA <= 2'b00;
                end
            end
        end else begin
            // RAS-Phase
            if (t == STATE_RAS0) begin
                {oe_latch, we_latch} <= 2'b00;
                refresh <= 1'b0;

                if (port1_active) begin
                    sd_cmd      <= CMD_ACTIVE;
                    SDRAM_A     <= port1_a[22:10];
                    SDRAM_BA    <= port1_a[24:23];
                    addr_latch  <= port1_a;
                    {oe_latch, we_latch} <= {~port1_we, port1_we};
                    ds          <= port1_ds;
                    din_latch   <= port1_d;
                end else if (need_refresh) begin
                    sd_cmd      <= CMD_AUTO_REFRESH;
                    refresh_cnt <= '0;
                    refresh     <= 1'b1;
                end
            end

            // CAS-Phase
            if (t == STATE_CAS0 && (we_latch || oe_latch)) begin
                sd_cmd <= we_latch ? CMD_WRITE : CMD_READ;
                {SDRAM_DQMH, SDRAM_DQML} <= ~ds;
                if (we_latch) begin
                    SDRAM_DQ  <= din_latch;
                    port1_ack <= port1_req;
                end
                SDRAM_A  <= {4'b0010, addr_latch[9:1]}; // Auto-Precharge aktivieren
                SDRAM_BA <= addr_latch[24:23];
            end

            // Daten-Rückgabe (Lesen)
            if (t == STATE_READ0 && oe_latch) begin
                port1_q   <= SDRAM_DQ;
                port1_ack <= port1_req;
            end
        end
    end

endmodule
`default_nettype wire

