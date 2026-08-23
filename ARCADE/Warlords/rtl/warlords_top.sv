module warlords_top (
    input  logic         Clk12,
    input  logic         Reset,
    input  logic [3:0]   JoyLeft,
    input  logic [3:0]   JoyRight,
    input  logic [7:0]   In0,
    input  logic [7:0]   In1,
    input  logic [7:0]   Sw1,
    input  logic [7:0]   Sw2,
    output logic [2:0]   R,
    output logic [2:0]   G,
    output logic [2:0]   B,
    output logic [3:0]   Led,
    output logic         Hsync,
    output logic         Vsync,
    output logic         Hblank,
    output logic         Vblank,
    output logic [5:0]   Audio
);

    logic [11:0] Hcnt;
    logic [7:0]  Vcnt;
    logic [23:0] Ab;
    logic [7:0]  Dbout;
    logic [15:0] PfOut;
    logic [7:0]  Pokey1Dout;
    logic        Phi0;
    logic        Write_n;
    logic        Write2_n;
    logic        Brw_n;
    logic        Mpu_Resetn;
    logic        Rom_n;
    logic        Ram0_n;
    logic        Pf_n;
    logic        Pokey1_CSn;
    logic        In0_n;
    logic        In1_n;
    logic        Swrd_n;
    logic        Steerclr_n;
    logic        Out0_n;
    logic        Pframrd_n;
    logic [7:0]  SwitchOut;

    assign SwitchOut = Ab[0] ? Sw2 : Sw1;

    warlords_cpu cpu (
        .Clk12        ( Clk12 ),
        .Hcnt         ( Hcnt ),
        .Vcnt         ( Vcnt ),
        .Vblank       ( Vblank ),
        .Reset        ( Reset ),
        .Pfout        ( PfOut ),
        .In0          ( In0 ), 
        .In1          ( In1 ),
        .SwitchOut    ( SwitchOut ),
        .Pokey1Dout   ( Pokey1Dout ),
        .Ab           ( Ab ),
        .Dbout        ( Dbout ),
        .Phi0en       ( Phi0 ),
        .Write_n      ( Write_n ),
        .Write2_n     ( Write2_n ),
        .Brw_n        ( Brw_n ),
        .Mpu_Resetn   ( Mpu_Resetn ),
        .Led          ( Led ),
        .Rom_n        ( Rom_n ),
        .Ram0_n       ( Ram0_n ),
        .Pf_n         ( Pf_n ),
        .Pokey1_CSn   ( Pokey1_CSn ),
        .Swrd_n       ( Swrd_n ),
        .Steerclr_n   ( Steerclr_n ),
        .Out0_n       ( Out0_n ),
        .Pframrd_n    ( Pframrd_n )
    );

    warlords_video video (
        .Clk12     ( Clk12 ),
        .Reset        ( Reset ),
        .Hcnt         ( Hcnt ),
        .Vcnt         ( Vcnt ),
        .Ab           ( Ab ),
        .DbOut        ( Dbout ),
        .PfOut        ( PfOut ),
        .Pf_n         ( Pf_n ),
        .Write_n      ( Write_n ),
        .R            ( R ),
        .G            ( G ),
        .B            ( B ),
        .Hsync        ( Hsync ),
        .Vsync        ( Vsync ),
        .Hblank       ( Hblank ),
        .Vblank       ( Vblank )
    );

    warlords_sound audio (
        .Clk12        ( Clk12 ),
        .Phi0         ( Phi0 ),
        .Reset        ( Reset ),
        .Addr         ( Ab[3:0] ),
        .Din          ( Dbout ),
        .Pokey_WRn    ( Write_n ),
        .Pokey_CSn    ( Pokey1_CSn ),
        .PokeyDout    ( Pokey1Dout ),
        .JoyLeft      ( JoyLeft ),
        .JoyRight     ( JoyRight ),
        .Audio        ( Audio )
    );

endmodule
