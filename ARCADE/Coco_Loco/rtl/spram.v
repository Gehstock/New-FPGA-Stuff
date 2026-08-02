module spram # (
    parameter address_width = 8,
    parameter data_width = 8
)
(
    input                           clock,
    input                           enable,
    input [(address_width-1):0]    address,
    input [(data_width-1):0]       data,
    output reg [(data_width-1):0]  q,
    input                           wren
);
	(* ramstyle = "no_rw_check" *) 
    reg [data_width-1:0] ram [0:(2**address_width)-1];

    always @(posedge clock) begin
        if (enable) begin
            if (wren) begin
                ram[address] <= data;
            end
            q <= ram[address];
        end
    end

endmodule

