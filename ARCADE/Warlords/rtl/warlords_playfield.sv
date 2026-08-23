module warlords_playfield (
    input  logic         Clk12,
    input  logic         Reset,
    input  logic [11:0]  Hcnt,
    input  logic [7:0]   Vcnt,
    input  logic [23:0]  Ab,
    input  logic [7:0]   DbOut,
    output logic [15:0]  PfOut,
    input  logic         Pf_n,
    input  logic         Write_n,
    input  logic         Hblank,
    input  logic         H256n,
    input  logic         S_256hd,
    input  logic         S_256hd_n,
    input  logic         Pload_n,
    output logic [1:0]   Area,
    output logic [1:0]   Gry
);

    logic [7:0]  Pf;
    logic [31:0] Pfd;
    logic        PfAddrStamp;
    logic [3:0]  Pfa7654;
    logic [3:0]  Pfa3210;
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
    logic [29:16] Pfd_hold;
    logic [29:16] Pfd_hold2;
    logic [7:0]  Pic;
    
    logic [10:0] Pf_rom0_addr;
    logic [10:0] Pf_rom1_addr;
    logic [7:0]  Pf_rom0_out;
    logic [7:0]  Pf_rom1_out;
    logic [7:0]  Pf_rom0_out_rev;
    logic [7:0]  Pf_rom1_out_rev;
    logic [7:0]  Pf_mux0;
    logic [7:0]  Pf_mux1;
    logic [7:0]  Pf_shift0;
    logic [7:0]  Pf_shift1;
    
    logic [1:0]  Y;
    logic [1:0]  Mr;
    logic [7:0]  Line_ram_addr;
    logic [1:0]  Line_ram[0:255];
    logic [7:0]  Line_ram_ctr;
    logic        Line_ram_ctr_load;
    logic        Line_ram_ctr_clr;


    assign PfSel = PfAddrStamp ? 2'b00 : { Vcnt[3], Hcnt[8] };
	 
	// assign PfSel = PfAddrStamp ? 2'b00 : { Vcnt[7], Hcnt[8] };
   
    always_comb begin
        case (PfSel)
            2'b00:   Pf = Pfd[7:0];
            2'b01:   Pf = Pfd[15:8];
            2'b10:   Pf = Pfd[23:16];
            2'b11:   Pf = Pfd[31:24];
            default: Pf = 8'b0;
        endcase
    end

    assign PfAddrStamp = Hblank && !Hcnt[9];
    assign Pfa7654     = PfAddrStamp ? 4'b1111 : { Vcnt[7:4] };
    assign Pfa3210     = { Hcnt[7:4] };
    assign Pfa         = { Pfa7654, Pfa3210 };
    assign PfCe        = (Hcnt[3:0] != 4'b1111);

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) PfCeD <= 1'b0;
        else       PfCeD <= PfCe;
    end
   
    assign PfCe4_n = 4'b0000;     
    assign Pfrd0_n = (Ab[5:4] == 2'b00) ? 1'b0 : 1'b1;
    assign Pfrd1_n = (Ab[5:4] == 2'b01) ? 1'b0 : 1'b1;
    assign Pfrd2_n = (Ab[5:4] == 2'b10) ? 1'b0 : 1'b1;
    assign Pfrd3_n = (Ab[5:4] == 2'b11) ? 1'b0 : 1'b1;
    
    assign Pfwr0_n = (!Pf_n && !Write_n && (Ab[5:4] == 2'b00)) ? 1'b0 : 1'b1;
    assign Pfwr1_n = (!Pf_n && !Write_n && (Ab[5:4] == 2'b01)) ? 1'b0 : 1'b1;
    assign Pfwr2_n = (!Pf_n && !Write_n && (Ab[5:4] == 2'b10)) ? 1'b0 : 1'b1;
    assign Pfwr3_n = (!Pf_n && !Write_n && (Ab[5:4] == 2'b11)) ? 1'b0 : 1'b1;
     
    pf_ram PfRamInst (
        .clk_a   ( Hcnt[0]   ),
        .clk_b   ( !Hcnt[0] ),
        .reset   ( Reset    ),
        .addr_a  ( {Ab[9:6], Ab[3:0]} ),
        .din_a   ( DbOut[7:0] ),
        .dout_a  ( PfOut ),
        .ce_a    ( {Pfrd3_n, Pfrd2_n, Pfrd1_n, Pfrd0_n} ),
        .we_a    ( {Pfwr3_n, Pfwr2_n, Pfwr1_n, Pfwr0_n} ),
        .addr_b  ( Pfa ),
        .dout_b  ( Pfd ),
        .ce_b    ( PfCe4_n )
    ); 

    assign Match_line    = { Vcnt };
    assign Match_sum     = Match_line + Pfd[15:8];
    assign Match_sum_top = (Match_sum[7:4] != 4'b1111);

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Match_sum_hold <= 6'd0;
        else if (Hcnt[3])  Match_sum_hold <= { Match_sum_top, 1'b0, Match_sum[3:0] };
    end

    assign Match_mux = Hcnt[9] ? { Pic[0], Vcnt[2:0] } : Match_sum_hold[3:0];
    assign Match_n   = Match_sum_hold[5] && H256n;
    assign Mga       = { Match_mux[3] ^ (Pic[7] && H256n), Match_mux[2] ^ Pic[7], Match_mux[1] ^ Pic[7], Match_mux[0] ^ Pic[7] };

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Pfd_hold <= 14'd0;
        else if (!Hcnt[3]) Pfd_hold <= Pfd[29:16];
    end

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)                              Pfd_hold2 <= 14'd0;
        else if (Hcnt[1] && Hcnt[2] && Hcnt[3]) Pfd_hold2 <= Pfd_hold;
    end
   
    assign Y[1] = (Area == 2'b00) ? (S_256hd ? 1'b0 : Gry[1]) : (S_256hd ? 1'b0 : Pfd_hold2[25]);
    assign Y[0] = (Area == 2'b00) ? (S_256hd ? 1'b0 : Gry[0]) : (S_256hd ? 1'b0 : Pfd_hold2[24]);
    assign Line_ram_ctr_load = !(Pload_n || Hcnt[9]);
    assign Line_ram_ctr_clr  = !(Pload_n || !(Hcnt[9] && S_256hd_n));
   
    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset) begin
            Line_ram_ctr <= 8'd0;
        end else begin
            if (Line_ram_ctr_clr)       Line_ram_ctr <= 8'd0;
            else if (Line_ram_ctr_load) Line_ram_ctr <= Pfd_hold[23:16];
            else                        Line_ram_ctr <= Line_ram_ctr + 8'b1;
        end
    end
   
    assign Line_ram_addr = Line_ram_ctr;

    always_ff @(posedge Hcnt[0]) Line_ram[Line_ram_addr] <= Y;
    
    always_ff @(posedge Clk12) begin
        if (Reset) Mr <= 2'b00;
        else       Mr <= Line_ram[Line_ram_addr];
    end
   
    assign Gry = Mr;

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Pic <= 8'd0;
        else if (!Hcnt[3]) Pic <= Pf[7:0];
    end

    assign Pf_rom0_addr = { 1'b0, H256n, Pic[5:0], Mga[2:0] };
    assign Pf_rom1_addr = { 1'b1, H256n, Pic[5:0], Mga[2:0] };

    E6 E6_rom0 ( 
        .clk(Clk12), 
        .addr(Pf_rom0_addr), 
        .data(Pf_rom0_out) 
    );
	
    E6 FH6_rom1 ( 
        .clk(Clk12), 
        .addr(Pf_rom1_addr), 
        .data(Pf_rom1_out) 
    );
	
    assign Pf_rom0_out_rev = { Pf_rom0_out[0], Pf_rom0_out[1], Pf_rom0_out[2], Pf_rom0_out[3], Pf_rom0_out[4], Pf_rom0_out[5], Pf_rom0_out[6], Pf_rom0_out[7] };
    assign Pf_rom1_out_rev = { Pf_rom1_out[0], Pf_rom1_out[1], Pf_rom1_out[2], Pf_rom1_out[3], Pf_rom1_out[4], Pf_rom1_out[5], Pf_rom1_out[6], Pf_rom1_out[7] };
   
    assign Pf_mux0 = Match_n ? 8'b0 : (Pic[6] ? Pf_rom0_out_rev : Pf_rom0_out);
    assign Pf_mux1 = Match_n ? 8'b0 : (Pic[6] ? Pf_rom1_out_rev : Pf_rom1_out);
	 
	 

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Pf_shift1 <= 8'd0;
        else if (!Pload_n) Pf_shift1 <= Pf_mux1;
        else               Pf_shift1 <= { Pf_shift1[6:0], 1'b0 };
    end
   
    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Pf_shift0 <= 8'd0;
        else if (!Pload_n) Pf_shift0 <= Pf_mux0;
        else               Pf_shift0 <= { Pf_shift0[6:0], 1'b0 };
    end
   
    assign Area = { Pf_shift1[7], Pf_shift0[7] };

endmodule
