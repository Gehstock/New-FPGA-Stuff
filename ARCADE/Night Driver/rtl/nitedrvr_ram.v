module nitedrvr_ram (
    input  wire        clk,
    input  wire  [8:0] addr,
    input  wire  [7:0] din,
    output reg   [7:0] dout,
    input  wire        we
);

    reg [7:0] mem [0:511];

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout <= mem[addr];
    end

endmodule
