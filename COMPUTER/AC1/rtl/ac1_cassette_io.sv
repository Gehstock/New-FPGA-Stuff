//Gehstock 2026
`default_nettype none

module ac1_cassette_io (
    input  logic clk,
    input  logic rst_n,
    input  logic tape_in_p,
    output logic tape_out_p,
    input  logic pio_tape_out,
    output logic pio_tape_in
);

    logic [3:0] filter_reg;
    logic       stable_tape_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filter_reg     <= 4'b1111;
            stable_tape_in <= 1'b1;
        end else begin
            filter_reg <= {filter_reg[2:0], tape_in_p};
            if (filter_reg == 4'b1111) 
                stable_tape_in <= 1'b1;
            else if (filter_reg == 4'b0000) 
                stable_tape_in <= 1'b0;
        end
    end

    assign pio_tape_in = stable_tape_in;
    assign tape_out_p = pio_tape_out;

endmodule
`default_nettype wire
