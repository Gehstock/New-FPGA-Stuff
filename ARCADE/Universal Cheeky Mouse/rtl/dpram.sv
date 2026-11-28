`timescale 1ns / 1ps

module dpram #(
    parameter address_width = 10,
    parameter data_width = 8
) (
    input  logic                        clock_a,
    input  logic                        clock_b,
    input  logic                        enable_a,
    input  logic                        wren_a,
    input  logic [address_width-1:0]    address_a,
    input  logic [data_width-1:0]       data_a,
    output logic [data_width-1:0]       q_a,

    input  logic                        enable_b,
    input  logic                        wren_b,
    input  logic [address_width-1:0]    address_b,
    input  logic [data_width-1:0]       data_b,
    output logic [data_width-1:0]       q_b
);

    localparam ramLength = (2**address_width);

    logic [data_width-1:0] mem [ramLength-1:0];

    always_ff @(posedge clock_a) begin
        if (enable_a && wren_a) begin
            mem[address_a] <= data_a;
        end
    end

    always_ff @(posedge clock_a) begin
        if (enable_a) begin
            q_a <= mem[address_a];
        end
    end
    
    always_ff @(posedge clock_b) begin
        if (enable_b && wren_b) begin
            mem[address_b] <= data_b;
        end
    end

    always_ff @(posedge clock_b) begin
        if (enable_b) begin
            q_b <= mem[address_b];
        end
    end

endmodule
