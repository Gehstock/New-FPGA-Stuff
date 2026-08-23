module warlords_video (
    input  logic         Clk12,
    input  logic         Reset,
    output logic [11:0]  Hcnt,
    output logic [7:0]   Vcnt,
    input  logic [23:0]  Ab,
    input  logic [7:0]   DbOut,
    output logic [15:0]  PfOut,
    input  logic         Pf_n,
    input  logic         Write_n,
    output logic [2:0]   R,
    output logic [2:0]   G,
    output logic [2:0]   B,
    output logic         Hsync,
    output logic         Vsync,
    output logic         Hblank,
    output logic         Vblank
);

    logic        Vcnt_reset;
    wire         H256n = ~Hcnt[9];
    logic        S_256hd;
    logic        S_256h2d;
    logic        Vblankd;
    logic        S_256hd_n;
    logic        S_256h2d_n;
    logic        Vblankd_n;
    logic        Pload_n;
    logic        Blank_clk;
    logic [7:0]  Vprom_addr;
    logic [3:0]  Vprom_out;
    logic [3:0]  Vprom_reg;
    logic        Vreset;
    logic        Hs_set;
    logic        Hs;
    logic        Hsync_reset;
    logic        Coloren;
    logic        Xxx1;
    logic [1:0]  Area;
    logic [1:0]  Gry;   
    logic [7:0]  Colorom_addr;
    logic [3:0]  Colorom_do;
    logic        Mirror;
    logic [8:0]  RgbO;

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) Hcnt <= 12'd0;
        else if (Hcnt == 12'hfff) Hcnt <= 12'b110100000000;
        else Hcnt <= Hcnt + 12'd1;
    end

    assign Pload_n  = (Hcnt[3:1] != 3'b111);
	 wire Mob_n     = ~H256n;
    
    assign Vcnt_reset = Reset || (Vreset == 1'b0);

    always_ff @(posedge H256n or posedge Reset) begin
        if (Reset) Vcnt <= 8'd0;
        else if (Vreset == 1'b1) Vcnt <= 8'd0;
        else Vcnt <= Vcnt + 8'd1;
    end

    assign Vprom_addr = {Vblank, Vcnt[7:5], Vcnt[3:0]};

    M6 M6_timing_prom (
        .clk  ( Hcnt[0] ),
        .addr ( Vprom_addr ),
        .data ( Vprom_out )
    );

    always_ff @(posedge H256n or posedge Reset) begin
        if (Reset) Vprom_reg <= 4'd0;
        else       Vprom_reg <= Vprom_out;
    end
		
    assign Vsync  = Vprom_reg[0];
    assign Vreset = Vprom_reg[2];
    assign Vblank = Vprom_reg[3];
    assign Hs_set = Reset || !H256n;
   
    always_ff @(posedge Hcnt[6] or posedge Hs_set) begin
        if (Hs_set) Hs <= 1'b1;
        else        Hs <= Hcnt[7];
    end

    assign Hsync_reset = Reset || Hs;
   
    always_ff @(posedge Hcnt[4] or posedge Hsync_reset) begin
        if (Hsync_reset) Hsync <= 1'b0;
        else             Hsync <= Hcnt[6];
    end

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset) Coloren <= 1'b0;
        else       Coloren <= S_256hd;
    end

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset) Xxx1 <= 1'b0;
        else       Xxx1 <= Coloren;
    end

    assign Hblank = (~Xxx1 && ~Coloren);
    assign Blank_clk = ~Clk12 && (Hcnt[3:0] == 4'b1111);

    always_ff @(posedge Blank_clk or posedge Reset) begin
        if (Reset) begin
            S_256h2d <= 1'b0; S_256hd  <= 1'b0; Vblankd  <= 1'b0;
        end else begin
            S_256h2d <= S_256hd; 
            S_256hd  <= Hcnt[9]; 
            Vblankd  <= Vblank;
        end
    end

    assign S_256h2d_n = ~S_256h2d; 
    assign S_256hd_n  = ~S_256hd; 
    assign Vblankd_n  = ~Vblankd;

    warlords_playfield playfield (
        .Clk12        ( Clk12 ),
        .Reset        ( Reset ),
        .Hcnt         ( Hcnt ),
        .Vcnt         ( Vcnt ),
        .Ab           ( Ab ),
        .DbOut        ( DbOut ),
        .PfOut        ( PfOut ),
        .Pf_n         ( Pf_n ),
        .Write_n      ( Write_n ),
        .Hblank       ( Hblank ),
        .H256n        ( H256n ),
        .S_256hd      ( S_256hd ),
        .S_256hd_n    ( S_256hd_n ),
        .Pload_n      ( Pload_n ),
        .Area         ( Area ),
        .Gry          ( Gry )
    );

    assign Mirror = 1'b0;
    assign Colorom_addr = {1'b0, Mirror, Vcnt[7], Hcnt[8], Gry[1:0], Area[1:0]};

    N7 N7_palette (
        .clk  ( Clk12 ),
        .addr ( Colorom_addr ),
        .data ( Colorom_do )
    );

    assign RgbO = 
        (Colorom_do[3:0] == 4'b0000) ? 9'b000_000_000 : 
        (Colorom_do[3:0] == 4'b0001) ? 9'b000_000_111 : 
        (Colorom_do[3:0] == 4'b0010) ? 9'b000_111_000 : 
        (Colorom_do[3:0] == 4'b0011) ? 9'b000_111_111 : 
        (Colorom_do[3:0] == 4'b0100) ? 9'b111_000_000 : 
        (Colorom_do[3:0] == 4'b0101) ? 9'b111_000_111 : 
        (Colorom_do[3:0] == 4'b0110) ? 9'b111_111_000 : 
        (Colorom_do[3:0] == 4'b0111) ? 9'b111_111_111 : 
        (Colorom_do[3:0] == 4'b1000) ? 9'b000_000_000 : 
        (Colorom_do[3:0] == 4'b1001) ? 9'b000_000_111 : 
        (Colorom_do[3:0] == 4'b1010) ? 9'b000_111_000 : 
        (Colorom_do[3:0] == 4'b1011) ? 9'b000_111_111 : 
        (Colorom_do[3:0] == 4'b1100) ? 9'b111_000_000 : 
        (Colorom_do[3:0] == 4'b1101) ? 9'b111_000_111 : 
        (Colorom_do[3:0] == 4'b1110) ? 9'b111_111_000 : 
        (Colorom_do[3:0] == 4'b1111) ? 9'b111_111_111 : 
        9'b000_000_000;

    assign R = RgbO[8:6];
    assign G = RgbO[5:3];
    assign B = RgbO[2:0];

endmodule

