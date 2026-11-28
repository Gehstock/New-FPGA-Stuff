module spram # (
    parameter address_width = 8,
    parameter data_width = 8
)
(
    input  logic                        clock,
    input  logic                        enable,
    input  logic [(address_width-1):0]  address,
    input  logic [(data_width-1):0]     data,
    output logic [(data_width-1):0]     q,
    input  logic                        wren
);

    (* ramstyle = "no_rw_check" *) logic [data_width-1:0] ram [0:(2**address_width)-1];

    always_ff @(posedge clock) begin
        if (enable && wren) begin
            ram[address] <= data;
        end
    end

    always_ff @(posedge clock) begin
        if (enable) begin
            q <= ram[address];
        end
    end
     
endmodule
