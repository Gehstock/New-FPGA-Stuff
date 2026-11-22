module mouser_audio (
    input  logic        clk_sys,
    input  logic        rst_n,
    input  logic        cpu_en,
    
    input  logic [7:0]  sound_cmd,
    input  logic        sound_latch_wren,
    input  logic        sound_nmi_trigger,
    
    output logic [9:0]  audio
);

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_di;
    logic [7:0]  cpu_do;
    logic        cpu_mreq_n;
    logic        cpu_iorq_n;
    logic        cpu_rd_n;
    logic        cpu_wr_n;
    logic        cpu_m1_n;
    logic        cpu_nmi_n;
    logic        cpu_int_n;

    T80se Z80 (
        .RESET_n(rst_n),
        .CLK_n(clk_sys),
        .CLKEN(cpu_en),
        .WAIT_n(1'b1),
        .INT_n(cpu_int_n),
        .NMI_n(cpu_nmi_n),
        .BUSRQ_n(1'b1),
        .M1_n(cpu_m1_n),
        .MREQ_n(cpu_mreq_n),
        .IORQ_n(cpu_iorq_n),
        .RD_n(cpu_rd_n),
        .WR_n(cpu_wr_n),
        .A(cpu_addr),
        .DI(cpu_di),
        .DO(cpu_do)
    );

    logic [7:0] rom_do;
    logic [7:0] ram_do;
    logic [7:0] ym_2149_1_data;
    logic [7:0] ym_2149_2_data;
    logic [7:0] sound_latch;

    logic rom_cs, ram_cs, snd_cs, nmi_cs, ay1_cs, ay2_cs;

    assign rom_cs = (cpu_mreq_n == 1'b0 && cpu_addr[15:12] == 4'h0);
    assign ram_cs = (cpu_mreq_n == 1'b0 && cpu_addr[15:10] == 6'b001000);
    assign snd_cs = (cpu_mreq_n == 1'b0 && cpu_addr == 16'h3000);
    assign nmi_cs = (cpu_mreq_n == 1'b0 && cpu_addr == 16'h4000);
    
    assign ay1_cs = (cpu_iorq_n == 1'b0 && cpu_addr[7:1] == 7'b0000000);
    assign ay2_cs = (cpu_iorq_n == 1'b0 && cpu_addr[7:1] == 7'b1000000);

    always_comb begin
        if (!cpu_rd_n) begin
            if (rom_cs)       cpu_di = rom_do;
            else if (ram_cs)  cpu_di = ram_do;
            else if (snd_cs)  cpu_di = sound_latch;
            else              cpu_di = 8'hFF;
        end else begin
            cpu_di = 8'hFF;
        end
    end

    logic ram_we;
    assign ram_we = ram_cs && !cpu_wr_n && !cpu_mreq_n && cpu_en;

    spram #(10,8) wram (
        .clock(clk_sys),
        .enable(ram_cs),
        .address(cpu_addr[9:0]),
        .data(cpu_do),
        .wren(ram_we),
        .q(ram_do)
    );

    scpu_rom1 inst_scpu_rom1 (
        .clk(clk_sys),
        .addr(cpu_addr[11:0]),
        .data(rom_do)
    );

    logic irq_active;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            irq_active  <= 1'b0;
            sound_latch <= 8'h00;
        end else begin
            if (sound_latch_wren) begin
                sound_latch <= sound_cmd;
                irq_active  <= 1'b1;
            end else if (snd_cs && !cpu_rd_n && cpu_en) begin
                irq_active  <= 1'b0;
            end
        end
    end
    assign cpu_int_n = ~irq_active;

    logic sound_nmi_reg;
    wire  s_nmi_pulse_set = sound_nmi_trigger && !sound_nmi_reg;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sound_nmi_reg <= 1'b0;
            cpu_nmi_n     <= 1'b1;
        end else begin
            sound_nmi_reg <= sound_nmi_trigger;
            if (s_nmi_pulse_set) begin
                cpu_nmi_n <= 1'b0;
            end else if (nmi_cs && !cpu_wr_n && cpu_en) begin
                cpu_nmi_n <= 1'b1;
            end
        end
    end

    logic ay1_bdir, ay1_bc1, ay2_bdir, ay2_bc1;
    
    always_comb begin
        ay1_bdir = 1'b0;
        ay1_bc1  = 1'b0;
        if (ay1_cs && !cpu_wr_n) begin
            ay1_bdir = 1'b1;
            ay1_bc1  = cpu_addr[0];
        end
    end

    always_comb begin
        ay2_bdir = 1'b0;
        ay2_bc1  = 1'b0;
        if (ay2_cs && !cpu_wr_n) begin
            ay2_bdir = 1'b1;
            ay2_bc1  = cpu_addr[0];
        end
    end

    logic [9:0] ym_2149_1_audio;
    logic [9:0] ym_2149_2_audio;

    ym2149 ym2149_1 (
        .I_DA(cpu_do),
        .O_DA(ym_2149_1_data),
        .O_DA_OE_L(),
        .I_A9_L(1'b0),
        .I_A8(1'b1),
        .I_BDIR(ay1_bdir),
        .I_BC2(1'b1), 
        .I_BC1(ay1_bc1),
        .I_SEL_L(1'b0),
        .O_AUDIO_L(ym_2149_1_audio),
        .ENA(cpu_en),
        .RESET_L(rst_n),
        .CLK(clk_sys)
    );

    ym2149 ym2149_2 (
        .I_DA(cpu_do),
        .O_DA(ym_2149_2_data),
        .O_DA_OE_L(),
        .I_A9_L(1'b0),
        .I_A8(1'b1),
        .I_BDIR(ay2_bdir),
        .I_BC2(1'b1), 
        .I_BC1(ay2_bc1),
        .I_SEL_L(1'b0),
        .O_AUDIO_L(ym_2149_2_audio),
        .ENA(cpu_en),
        .RESET_L(rst_n),
        .CLK(clk_sys)
    );

    logic [10:0] mixed_audio;
    assign mixed_audio = {1'b0, ym_2149_1_audio} + {1'b0, ym_2149_2_audio};
    assign audio       = mixed_audio[10:1];

endmodule
