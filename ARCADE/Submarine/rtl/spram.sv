module spram # (
	parameter 	address_width = 8,
	parameter 	data_width = 8
)
(
	input			clk,
	input			enable,
	input 		[(address_width-1):0]		addr,
	input 		[(data_width-1):0]		din,
	output reg 	[(data_width-1):0]	dout,
	input			we
);

    reg [data_width-1:0] ram [0:(2**address_width)-1];

	always @(posedge clk) begin
		if (enable) begin
			if (we) begin
                ram[addr] <= din;
            end
			dout <= ram[addr];
		end
   end
	 
endmodule
