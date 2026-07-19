module spram # (
	parameter address_width = 8,
	parameter data_width = 8
)
(
	input 							clock,
	input [(address_width-1):0]		address,
	input [(data_width-1):0]		data,
	output reg [(data_width-1):0]	q,
	input							wren
);

    reg [data_width-1:0] ram [0:(2**address_width)-1];
    always @(posedge clock) begin
        if (wren)
            ram[address] <= data;
        q <= ram[address];
    end
endmodule
