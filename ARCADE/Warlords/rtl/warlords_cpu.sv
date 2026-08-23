
module warlords_cpu (
    input  logic         Clk12,
    input  logic [11:0]  Hcnt,
    input  logic [7:0]   Vcnt,
    input  logic         Vblank,
    input  logic         Reset,
    input  logic [15:0]  Pfout,
    input  logic [7:0]   In0,
    input  logic [7:0]   In1,
    input  logic [7:0]   SwitchOut,
    input  logic [7:0]   Pokey1Dout,
    output logic [23:0]  Ab,
    output logic [7:0]   Dbout,
    output logic         Phi0en,
    output logic         Write_n,
    output logic         Write2_n,
    output logic         Brw_n,
    output logic         Mpu_Resetn,
    output logic [4:1]   Led,
    output logic         Rom_n,
    output logic         Ram0_n,
    output logic         Pf_n,
    output logic         Pokey1_CSn,
    output logic         Swrd_n,
    output logic         Steerclr_n,
    output logic         Out0_n,
    output logic         Pframrd_n
);

    logic [7:0] DbIn;
    logic       Rw_n;
    logic       Phi0;
    logic       Phi2;
    logic       Phi0a;
    logic       Irq_n;
    logic       Irqres_n;
    logic [7:0] RamOut;
    logic [7:0] MpuResetCntr;
    logic       MpuReset;
    logic [7:0] RomOut;   
    logic       In0_n;
    logic       In1_n;
    logic [9:0] Adecode_n;
    logic [7:0] CcLatch;

    spram #(10,8) u_main_ram (
        .address ( Ab[9:0] ),
        .clock   ( Clk12 ),
        .enable  ( !Ram0_n ),
        .wren    ( !Write_n ),
        .data    ( Dbout[7:0] ),
        .q       ( RamOut[7:0] )
    );
     
    PROG u_program_rom (
        .clk  ( Clk12 ),
        .addr ( Ab[14:0] ),
        .data ( RomOut )
    );

    always_ff @(posedge Vcnt[4] or negedge Irqres_n) begin
        if (!Irqres_n) Irq_n <= 1'b1;
        else           Irq_n <= ~Vcnt[5];
    end

    always_ff @(posedge Hcnt[1] or posedge Reset) begin
        if (Reset) Phi0a <= 1'b0;
        else       Phi0a <= ~Phi0a;
    end

    assign Phi0   = ~Phi0a;
    assign Phi0en = Phi0a;
    assign Phi2   = ~Phi0;

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            MpuReset     <= 1'b1;
            MpuResetCntr <= 8'd0;
        end else begin
            if (MpuResetCntr != 8'h10) begin
                MpuResetCntr <= MpuResetCntr + 8'd1;
            end else begin
                MpuReset <= 1'b0;
            end
        end
    end

    assign Mpu_Resetn = ~MpuReset;

    T65 T65_core (
        .Res_n   ( Mpu_Resetn ),
        .Enable  ( 1'b1 ),
        .Clk     ( Phi0 ),
        .Rdy     ( 1'b1 ),
        .Abort_n ( 1'b1 ),
        .IRQ_n   ( Irq_n ),
        .NMI_n   ( 1'b1 ),
        .SO_n    ( 1'b1 ),
        .R_W_n   ( Rw_n ),
        .A       ( Ab ),
        .DI      ( DbIn[7:0] ),
        .DO      ( Dbout[7:0] )
    );

    assign Write_n = ~(Phi2 & !Rw_n);
    assign Brw_n   = ~Rw_n;

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) Write2_n <= 1'b0;
        else       Write2_n <= Write_n;
    end

    assign Adecode_n = (!Ab[14] && (Ab[13:10] < 4'd10)) ? ~(10'b1 << Ab[13:10]) : 10'b11_1111_1111;

    assign Ram0_n      = Adecode_n[0];
    assign Pf_n        = Adecode_n[1];
    assign Swrd_n      = Adecode_n[2];
    assign In0_n       = Adecode_n[3] | Ab[0];  
    assign In1_n       = Adecode_n[3] | ~Ab[0]; 
    assign Pokey1_CSn  = Adecode_n[4];
    assign Irqres_n    = (Adecode_n[6] | Write2_n) & Mpu_Resetn; 
    assign Out0_n      = Adecode_n[7] | Write2_n;
    assign Steerclr_n  = Adecode_n[9] | Write2_n;
    assign Pframrd_n   = Pf_n | Brw_n;
    assign Rom_n       = !Ab[14];

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            CcLatch <= 8'd0;
        end else if (!Out0_n) begin
            CcLatch[Ab[2:0]] <= Dbout[7];
        end
    end

    assign Led[1] = CcLatch[3];
    assign Led[2] = CcLatch[4];
    assign Led[3] = CcLatch[5];
    assign Led[4] = CcLatch[6];

		always_comb begin
        if      (!Rom_n)      DbIn = RomOut;
        else if (!Ram0_n)     DbIn = RamOut;
        else if (!Pframrd_n)  DbIn = (Ab[0] ? Pfout[15:8] : Pfout[7:0]);
//        else if (!In0_n)      DbIn = Ab[0] ? In1 : {In0[7], Vblank, In0[5:0]};
		  else if (!In0_n)      DbIn = {In0[7], Vblank, In0[5:0]};
		  else if (!In1_n)      DbIn = In1; 
        else if (!Swrd_n)     DbIn = SwitchOut;
        else if (!Pokey1_CSn) DbIn = Pokey1Dout;
        else                  DbIn = 8'hFF;
    end

endmodule
