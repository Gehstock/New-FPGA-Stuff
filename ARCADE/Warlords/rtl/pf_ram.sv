module pf_ram (
    input  logic        clk_a,
    input  logic        clk_b,
    input  logic        reset,
    input  logic [7:0]  addr_a,
    input  logic [7:0]  din_a,
    output logic [7:0]  dout_a,
    input  logic [3:0]  ce_a,
    input  logic [3:0]  we_a,
    input  logic [7:0]  addr_b,
    output logic [31:0] dout_b,
    input  logic [3:0]  ce_b
);

    logic [7:0] d_a0, d_a1, d_a2, d_a3;		
    logic [7:0] d_b0, d_b1, d_b2, d_b3;

    always_comb begin
        if      (!ce_a[3]) dout_a = d_a3;
        else if (!ce_a[2]) dout_a = d_a2;
        else if (!ce_a[1]) dout_a = d_a1;
        else if (!ce_a[0]) dout_a = d_a0;
        else               dout_a = 8'b0;
    end

    assign dout_b = { d_b3, d_b2, d_b1, d_b0 };	

    // Bank 0
    dpram #(8,8) ram0 (
        .clock_a  ( clk_a ),
		  .enable_a		(!ce_a[0]),
        .wren_a     ( !we_a[0] ),
        .address_a ( addr_a ),	
        .data_a ( din_a ),
        .q_a ( d_a0 ),
        
        .clock_b  ( clk_b ),
		  .enable_b		(1'b1),
        .address_b ( addr_b ),
        .q_b ( d_b0 )
    );
	
    // Bank 1
    dpram #(8,8) ram1 (
        .clock_a  ( clk_a ),
		  .enable_a		(!ce_a[1]),
        .wren_a     ( !we_a[1] ),
        .address_a ( addr_a ),	
        .data_a ( din_a ),
        .q_a ( d_a1 ),
        
        .clock_b  ( clk_b ),
		  .enable_b		(1'b1),
        .address_b ( addr_b ),
        .q_b ( d_b1 )
    );

    // Bank 2
    dpram #(8,8) ram2 (
        .clock_a  ( clk_a ),
		  .enable_a		(!ce_a[2]),
        .wren_a     ( !we_a[2] ),
        .address_a ( addr_a ),	
        .data_a ( din_a ),
        .q_a ( d_a2 ),
        
        .clock_b  ( clk_b ),
		  .enable_b		(1'b1),
        .address_b ( addr_b ),
        .q_b ( d_b2 )
    );

    // Bank 3
    dpram #(8,8) ram3 (
        .clock_a  ( clk_a ),
		  .enable_a		(!ce_a[3]),
        .wren_a     ( !we_a[3] ),
        .address_a ( addr_a ),	
        .data_a ( din_a ),
        .q_a ( d_a3 ),
        
        .clock_b  ( clk_b ),
		  .enable_b		(1'b1),
        .address_b ( addr_b ),
        .q_b ( d_b3 )
    );	

endmodule 