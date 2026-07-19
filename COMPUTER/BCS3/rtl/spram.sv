//Gehstock 2024
`timescale 1 ps / 1 ps
`default_nettype none

module spram #(
    parameter int address_width = 8,
    parameter int data_width    = 8
) (
    input  logic                     clock,
    input  logic                     enable,
    input  logic [address_width-1:0] address,
    input  logic [data_width-1:0]    data,
    output logic [data_width-1:0]    q,
    input  logic                     wren
);

    localparam int ramLength = (2**address_width);
    logic [data_width-1:0] ram [ramLength-1:0];

    always_ff @(posedge clock) begin
        if (enable) begin
            if (wren) begin
                ram[address] <= data;
            end
            q <= ram[address];
        end
    end

endmodule
`default_nettype wire

