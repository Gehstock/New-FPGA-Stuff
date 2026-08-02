`timescale 1 ps / 1 ps
`default_nettype none

module dpram #(
    parameter address_width = 10,
    parameter data_width = 8
) (
    input   wire                        clock,

    input   wire                        enable_a,
    input   wire                        wren_a,
    input   wire    [address_width-1:0] address_a,
    input   wire    [data_width-1:0]    data_a,
    output  reg     [data_width-1:0]    q_a,

    input   wire                        enable_b,
    input   wire                        wren_b,
    input   wire    [address_width-1:0] address_b,
    input   wire    [data_width-1:0]    data_b,
    output  reg     [data_width-1:0]    q_b
);

    // Speicher-Array Definition
    localparam ramLength = (2**address_width);
	 (* ramstyle = "no_rw_check" *) 
    reg [data_width-1:0] mem [ramLength-1:0];

    // Port A: Kopiervorgang vom ROM beim Booten
    always @(posedge clock) begin
        if (enable_a) begin
            if (wren_a) begin
                mem[address_a] <= data_a; // Reiner Schreibvorgang in den Speicher
            end
            q_a <= mem[address_a]; // Read-First: Liefert den aktuellen/alten Wert
        end
    end
    
    // Port B: Arbeitsport für die CPU & Grafik-Controller
    always @(posedge clock) begin
        if (enable_b) begin
            if (wren_b) begin
                mem[address_b] <= data_b; // Reiner Schreibvorgang
            end
            q_b <= mem[address_b]; // Read-First: Garantiert fehlerfreies Block-RAM Mapping
        end
    end

endmodule
