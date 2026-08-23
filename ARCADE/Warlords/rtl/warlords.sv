module warlords (
    input  logic         clk_12mhz,
    input  logic         reset,
	 input  logic signed [7:0] PADDLE0, // Spieler 1
    input  logic signed [7:0] PADDLE1, // Spieler 2
    input  logic signed [7:0] PADDLE2, // Spieler 3
    input  logic signed [7:0] PADDLE3, // Spieler 4
    input  logic [7:0]   IN0,   // Fertiges Datenbyte für CPU-Adresse $1800 (Münzen/Start)
    input  logic [7:0]   IN1,   // Fertiges Datenbyte für CPU-Adresse $1801 (Richtungen/Buttons)
    input  logic [7:0]   sw1_i,     // Fertiges Datenbyte für die DIP-Switches
	 input  logic [7:0]   sw2_i,     // Fertiges Datenbyte für die DIP-Switches
    output logic         R,
    output logic         G,
    output logic         B,
    output logic         sync_o,
    output logic         hsync_o,
    output logic         vsync_o,
    output logic         hblank_o,
    output logic         vblank_o,
    output logic [5:0]   audio_o
);

    logic [23:0] ab;
    logic [7:0]  db_out;
    logic [7:0]  rom_out;
    logic [15:0]  pf_out;
    logic [7:0]  pokey1_dout;
    logic        s_6mhz;
    logic        s_6mhz_n;
    logic        s_6mhz_n_en;
    logic        s_1h;
	 logic			s_4h;
    logic        s_16v;
    logic        s_32v;
    logic        phi0_en;
    logic        vblank;
    logic        rw_n;
    logic        write_n;
    logic        write2_n;
    logic        brw_n;
    logic        mpu_reset_n;
    logic        rom_n;
    logic        ram0_n;
    logic        pf_n;
    logic        pokey1_cs_n;
    logic        in0_n;
    logic        in1_n;
    logic        swrd_n;
    logic        steerclr_n;
    logic        out0_n;
    logic        pframrd_n;
    wire [7:0]  switch_out = ab[0] ? sw2_i : sw1_i;
    assign rw_n = !brw_n;
	 
    warlords_cpu_sys u_cpu_system (
        .clk_12mhz    ( clk_12mhz ),
        .s_6mhz       ( s_6mhz ),
        .s_1h         ( s_1h ),
		  .s_4h			(s_4h),
        .s_16v        ( s_16v ),
        .s_32v        ( s_32v ),
        .vblank       ( vblank ),
        .reset        ( reset ),
        .pf_out       ( pf_out ),
        .IN0 ( IN0 ), 
        .IN1 ( IN1 ),
        .switch_out   ( switch_out ),
        .pokey1_dout  ( pokey1_dout ),
        .ab           ( ab ),
        .db_out       ( db_out ),
        .phi0_en      ( phi0_en ),
        .write_n      ( write_n ),
        .write2_n     ( write2_n ),
        .brw_n        ( brw_n ),
        .mpu_reset_n  ( mpu_reset_n ),
        .rom_n        ( rom_n ),
        .ram0_n       ( ram0_n ),
        .pf_n         ( pf_n ),
        .pokey1_cs_n  ( pokey1_cs_n ),
        .swrd_n       ( swrd_n ),
        .steerclr_n   ( steerclr_n ),
        .out0_n       ( out0_n ),
        .pframrd_n    ( pframrd_n )
    );

    warlords_video u_video_system (
        .clk_12mhz   ( clk_12mhz ),
        .reset       ( reset ),
        .ab          ( ab ),
        .db_out      ( db_out ),
        .pf_out      ( pf_out ),
		  .pf_n         ( pf_n ),
        .write_n     ( write_n ),
        .s_6mhz      ( s_6mhz ),
        .s_6mhz_n    ( s_6mhz_n ),
        .s_6mhz_n_en ( s_6mhz_n_en ),
        .s_1h        ( s_1h ),
        .s_16v       ( s_16v ),
        .s_32v       ( s_32v ),
        .vblank      ( vblank ),
        .R           ( R ),
        .G           ( G ),
        .B           ( B ),
        .sync_o      ( sync_o ),
        .hsync_o     ( hsync_o ),
        .vsync_o     ( vsync_o ),
        .hblank_o    ( hblank_o ),
        .vblank_o    ( vblank_o )
    );

    WARLORDS_SOUND SOUNDBOARD (
        .CLK_12MHZ   ( clk_12mhz ),
        .PHI0_EN     ( phi0_en ),
        .RESET       ( reset ),
        .ADDR        ( ab[3:0] ),
        .DIN         ( db_out ),
        .RW_N        ( rw_n ), 
        .WRITE_N     ( write_n ),
        .POKEY1_CS_N ( pokey1_cs_n ),
        .POKEY1_DOUT ( pokey1_dout ),
        .PADDLE0     ( PADDLE0 ),
        .PADDLE1     ( PADDLE1 ),
        .PADDLE2     ( PADDLE2 ),
        .PADDLE3     ( PADDLE3 ),
        .AUDIO_O     ( audio_o )
    );

endmodule
