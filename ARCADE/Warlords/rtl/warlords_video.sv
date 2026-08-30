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
    logic [1:0]  Gry;   
    logic [7:0]  Colorom_addr;
    logic [3:0]  Colorom_do;
    logic        Mirror;
    logic [8:0]  RgbO;

    logic [7:0]  Pf;
    logic [31:0] Pfd;
    logic        PfAddrStamp;
    logic [3:0]  Pfa_M5, Pfa_M3;
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
    logic [1:0]  Y;
    logic [1:0]  Mr;
    logic [7:0]  Line_ram_addr;
    logic [1:0]  Line_ram[0:255];
    logic [7:0]  Line_ram_ctr;
    logic        Line_ram_ctr_load;
    logic        Line_ram_ctr_clr;

    logic [7:0]  mob_x[0:15];
    logic [7:0]  mob_y[0:15];
    logic [7:0]  mob_pic[0:15];
    logic [7:0]  mob_attr[0:15];
    logic        mob_pixel;
    logic [1:0]  mob_color;
    logic [2:0]  sprite_x_offset;
    logic [2:0]  sprite_y_offset;
    logic [7:0]  sprite_bit_select;
    logic        sprite_bit_rom0;
    logic        sprite_bit_rom1;
    logic        mob_active_zone;
    logic [3:0]  active_mob_idx;

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

    assign PfSel = PfAddrStamp ? 2'b00 : { Vcnt[3], Hcnt[8] };
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
    assign Pfa_M5 = Hcnt[3] ? Ab[9:6] : (!(Hcnt[3] || Hcnt[9]) ? 4'b1111 : Vcnt[7:4]);
    assign Pfa_M3 = Hcnt[3] ? Ab[3:0] : Hcnt[7:4];
    assign Pfa         = { Pfa_M5, Pfa_M3 };
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
   
    assign Gry = Line_ram[Line_ram_addr];

    always_ff @(posedge Hcnt[0] or posedge Reset) begin
        if (Reset)         Pic <= 8'd0;
        else if (!Hcnt[3]) Pic <= Pf[7:0];
    end

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            for (int i=0; i<16; i++) begin
                mob_x[i]    <= 8'd0;
                mob_y[i]    <= 8'd0;
                mob_pic[i]  <= 8'd0;
                mob_attr[i] <= 8'd0;
            end
        end else if (!Write_n && !Pf_n && (Ab[9:6] == 4'hF)) begin
            case(Ab[5:4])
                2'b00: mob_pic[Ab[3:0]]  <= DbOut;
                2'b01: mob_y[Ab[3:0]]    <= DbOut;
                2'b10: mob_x[Ab[3:0]]    <= DbOut;
                2'b11: mob_attr[Ab[3:0]] <= DbOut;
            endcase
        end
    end

    always_comb begin
        mob_active_zone = 1'b0;
        active_mob_idx = 4'd0;
        sprite_x_offset = 3'd0;
        sprite_y_offset = 3'd0;
        for (int i = 0; i < 16; i++) begin
            if ((Hcnt[8:1] >= mob_x[i]) && (Hcnt[8:1] < mob_x[i] + 8) &&
                (Vcnt >= mob_y[i]) && (Vcnt < mob_y[i] + 8)) begin
                mob_active_zone = 1'b1;
                active_mob_idx = i[3:0];
                sprite_x_offset = Hcnt[8:1] - mob_x[i];
                sprite_y_offset = Vcnt - mob_y[i];
                break;
            end
        end
    end

    always_comb begin
        sprite_bit_select = 8'h80 >> sprite_x_offset;
        sprite_bit_rom0 = |(Pf_rom0_out & sprite_bit_select);
        sprite_bit_rom1 = |(Pf_rom1_out & sprite_bit_select);
        
        if (mob_active_zone && (sprite_bit_rom0 || sprite_bit_rom1)) begin
            mob_pixel = 1'b1;
            mob_color = mob_attr[active_mob_idx][1:0];
        end else begin
            mob_pixel = 1'b0;
            mob_color = 2'b00;
        end
    end

    assign Pf_rom0_addr = ~mob_active_zone ?
                          { 1'b0, H256n, Pic[5:0], Mga[2:0] } :
                          { 1'b0, H256n, mob_pic[active_mob_idx][5:0], (3'd7 - sprite_y_offset) };

    assign Pf_rom1_addr = ~mob_active_zone ?
                          { 1'b1, H256n, Pic[5:0], Mga[2:0] } :
                          { 1'b1, H256n, mob_pic[active_mob_idx][5:0], (3'd7 - sprite_y_offset) };

    E6 E6_rom ( 
        .clk(Clk12), 
        .addr(Pf_rom0_addr), 
        .data(Pf_rom0_out) 
    );
	
    E6 FH6_rom ( 
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
   
    assign Area[0] = Pf_shift0[7];
    assign Area[1] = Pf_shift1[7];

    assign Mirror = 1'b0;

    assign Colorom_addr = mob_pixel ?
                          {1'b1, Mirror, Vcnt[7], Hcnt[8], mob_color[1:0], Area[1:0]} :
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
