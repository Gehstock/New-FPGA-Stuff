module dpram #(
    parameter address_width = 10,
    parameter data_width = 8
) (
    input   wire                        clk_a,
    input   wire                        clk_b,
    input   wire                        enable_a,
    input   wire                        we_a,
    input   wire    [address_width-1:0] addr_a,
    input   wire    [data_width-1:0]    din_a,
    output  reg     [data_width-1:0]    dout_a,

    input   wire                        enable_b,
    input   wire                        we_b,
    input   wire    [address_width-1:0] addr_b,
    input   wire    [data_width-1:0]    din_b,
    output  reg     [data_width-1:0]    dout_b
);


    localparam ramLength = (2**address_width);
    reg [data_width-1:0] mem [ramLength-1:0];

    always @(posedge clk_a) begin
        if (enable_a) begin
            if (we_a) begin
                mem[addr_a] <= din_a;
            end
            dout_a <= mem[addr_a];
        end
    end
    
    always @(posedge clk_b) begin
        if (enable_b) begin
            if (we_b) begin
                mem[addr_b] <= din_b;
            end
            dout_b <= mem[addr_b];
        end
    end

endmodule  