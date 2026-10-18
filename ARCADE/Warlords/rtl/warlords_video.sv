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
    output logic         Vblank,
    output logic         DBG
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
    logic [1:0]  Y;
    logic [1:0]  Mr;
    logic [7:0]  Line_ram_addr;
    logic [7:0]  Line_ram_ctr;
    logic        Line_ram_ctr_load;
    logic        Line_ram_ctr_clr;

    logic [7:0]  Pf;
    logic [31:0] Pfd;
    logic        PfAddrStamp;
    logic [7:0]  Pfa;
    logic        PfCe;
    logic        PfCeD;
    logic [3:0]  PfCe4_n;
    logic [1:0]  PfSel;
    logic        Pfrd0_n, Pfrd1_n, Pfrd2_n, Pfrd3_n;
    logic        Pfwr0_n, Pfwr1_n, Pfwr2_n, Pfwr3_n;
    logic [7:0]  Match_line;
    logic [7:0]  Match_sum;
    logic        Match_sum_top;
    logic [5:0]  Match_sum_hold;
    logic [3:0]  Match_mux;
    logic        Match_n;
    logic [3:0]  Mga;
    logic [29:16] Pfd_hold, Pfd_hold2;
    logic [7:0]  Pic;  
    logic [10:0] Pf_rom0_addr;
    logic [10:0] Pf_rom1_addr;
    logic [7:0]  Pf_rom0_out, Pf_rom1_out;
    logic [7:0]  Pf_rom0_out_rev, Pf_rom1_out_rev;
    logic [7:0]  Pf_mux0, Pf_mux1;
    logic [7:0]  Pf_shift0, Pf_shift1;   
    logic [1:0]  Gry;

    logic        mob_pixel;
    logic [1:0]  mob_color;
    logic [7:0]  Colorom_addr;
    logic [3:0]  Colorom_do;
    logic        Mirror;
    logic [8:0]  RgbO;

    assign DBG = Y[0];

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

    warlords_tiles tiles_inst (
        .Clk12(Clk12),
        .Reset(Reset),
        .Hcnt(Hcnt),
        .Vcnt(Vcnt),
        .Ab(Ab),
        .DbOut(DbOut),
        .PfOut(PfOut),
        .Pf_n(Pf_n),
        .Write_n(Write_n),
        .H256n(H256n),
        .Pload_n(Pload_n),
        .S_256hd(S_256hd),
        .S_256hd_n(S_256hd_n),
        .Hblank(Hblank),
        .Pf(Pf),
        .Pfd(Pfd),
        .PfAddrStamp(PfAddrStamp),
        .Pfa(Pfa),
        .PfCe(PfCe),
        .PfCeD(PfCeD),
        .PfCe4_n(PfCe4_n),
        .PfSel(PfSel),
        .Pfrd0_n(Pfrd0_n), .Pfrd1_n(Pfrd1_n), .Pfrd2_n(Pfrd2_n), .Pfrd3_n(Pfrd3_n),
        .Pfwr0_n(Pfwr0_n), .Pfwr1_n(Pfwr1_n), .Pfwr2_n(Pfwr2_n), .Pfwr3_n(Pfwr3_n),
        .Match_line(Match_line),
        .Match_sum(Match_sum),
        .Match_sum_top(Match_sum_top),
        .Match_sum_hold(Match_sum_hold),
        .Match_mux(Match_mux),
        .Match_n(Match_n),
        .Mga(Mga),
        .Pfd_hold(Pfd_hold), .Pfd_hold2(Pfd_hold2),
        .Pic(Pic),
        .Pf_rom0_addr(Pf_rom0_addr),
        .Pf_rom1_addr(Pf_rom1_addr),
        .Pf_rom0_out(Pf_rom0_out), .Pf_rom1_out(Pf_rom1_out),
        .Pf_rom0_out_rev(Pf_rom0_out_rev), .Pf_rom1_out_rev(Pf_rom1_out_rev),
        .Pf_mux0(Pf_mux0), .Pf_mux1(Pf_mux1),
        .Pf_shift0(Pf_shift0), .Pf_shift1(Pf_shift1),
        .Area(Area),
        .Y(Y),
        .Mr(Mr),
        .Line_ram_addr(Line_ram_addr),
        .Line_ram_ctr(Line_ram_ctr),
        .Line_ram_ctr_load(Line_ram_ctr_load),
        .Line_ram_ctr_clr(Line_ram_ctr_clr),
        .Gry(Gry)
    );

    warlords_sprites sprites_inst (
        .Clk12(Clk12),
        .Reset(Reset),
        .Hcnt(Hcnt),
        .Vcnt(Vcnt),
        .Ab(Ab),
        .DbOut(DbOut),
        .Pf_n(Pf_n),
        .Write_n(Write_n),
        .H256n(H256n),
        .Pf_rom0_out(Pf_rom0_out),
        .Pf_rom1_out(Pf_rom1_out),
        .mob_pixel(mob_pixel),
        .mob_color(mob_color)
    );

    assign Mirror = 1'b0;

    assign Colorom_addr = mob_pixel ?
                          {1'b1, Mirror, Vcnt[7], Hcnt[8], mob_color[1:0], mob_color[1:0]} :
                          {1'b0, Mirror, Vcnt[7], Hcnt[8], Gry[1:0], Area[1:0]};

    N7 N7_palette (
        .clk  ( Clk12 ),
        .addr ( Colorom_addr ),
        .data ( Colorom_do )
    );

    assign RgbO = 
        (Colorom_do[2:0] == 3'b000) ? 9'b000_000_000 : 
        (Colorom_do[2:0] == 3'b001) ? 9'b000_000_111 : 
        (Colorom_do[2:0] == 3'b010) ? 9'b000_111_000 : 
        (Colorom_do[2:0] == 3'b011) ? 9'b000_111_111 : 
        (Colorom_do[2:0] == 3'b100) ? 9'b111_000_000 : 
        (Colorom_do[2:0] == 3'b101) ? 9'b111_000_111 : 
        (Colorom_do[2:0] == 3'b110) ? 9'b111_111_000 : 
        (Colorom_do[2:0] == 3'b111) ? 9'b111_111_111 : 
        9'b000_000_000;

    assign R = RgbO[8:6];
    assign G = RgbO[5:3];
    assign B = RgbO[2:0];

endmodule
