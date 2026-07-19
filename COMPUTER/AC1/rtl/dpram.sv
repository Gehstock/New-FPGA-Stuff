//Gehstock 2024
`timescale 1 ps / 1 ps
`default_nettype none

module dpram #(
    parameter int address_width = 10,
    parameter int data_width    = 8
) (
    input  logic                     clock,

    input  logic                     enable_a,
    input  logic                     wren_a,
    input  logic [address_width-1:0] address_a,
    input  logic [data_width-1:0]    data_a,
    output logic [data_width-1:0]    q_a,

    input  logic                     enable_b,
    input  logic                     wren_b,
    input  logic [address_width-1:0] address_b,
    input  logic [data_width-1:0]    data_b,
    output logic [data_width-1:0]    q_b
);

    localparam int ramLength = (2**address_width);
    (* ramstyle = "no_rw_check" *) logic [data_width-1:0] mem [ramLength-1:0];

    always_ff @(posedge clock) begin
        if (enable_a) begin
            if (wren_a) begin
                mem[address_a] <= data_a;
            end
            q_a <= mem[address_a];
        end
    end
    
    always_ff @(posedge clock) begin
        if (enable_b) begin
            if (wren_b) begin
                mem[address_b] <= data_b;
            end
            q_b <= mem[address_b];
        end
    end

endmodule
`default_nettype wire
