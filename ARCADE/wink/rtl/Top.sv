module Top (
    input  logic        clk_sys,
    input  logic        reset,
    output logic [16:1] cpu1_addr,
    input  logic [15:0] cpu1_q,
    output logic [16:1] cpu2_addr,
    input  logic [15:0] cpu2_q,
    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,
    input  logic [7:0]  dial1,
    input  logic [7:0]  inputs1,
    input  logic [7:0]  dsw1,
    input  logic [7:0]  dsw2,
    input  logic [7:0]  dsw3,
    output logic [3:0]  red,
    output logic [3:0]  green,
    output logic [3:0]  blue,
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic [9:0]  audio_l,
    output logic [9:0]  audio_r
);

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;
    logic        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
    logic        nmi_n;
	 
    logic [4:0] clk_div;
    always_ff @(posedge clk_sys) begin
        if (reset) clk_div <= 5'd0;
        else       clk_div <= clk_div + 5'd1;
    end

    wire ce_pix   = (clk_div[2:0] == 3'b111);
    wire ce_main  = (clk_div[3:0] == 4'b1111);
    wire ce_audio = (clk_div[4:0] == 5'b11111);

    logic [11:0] nvram_init_cnt;
    wire         nvram_initializing = !nvram_init_cnt[11];

    always_ff @(posedge clk_sys) begin
        if (reset)
            nvram_init_cnt <= 12'd0;
        else if (nvram_initializing)
            nvram_init_cnt <= nvram_init_cnt + 12'd1;
    end

    T80s #(
        .Mode(0),
        .T2Write(1),
        .IOWait(1)
    ) maincpu (
        .RESET_n (~reset && !nvram_initializing),
        .CLK     (clk_sys),
        .CEN     (ce_main),
        .WAIT_n  (1'b1),
        .INT_n   (1'b1),
        .NMI_n   (nmi_n),
        .BUSRQ_n (1'b1),
        .M1_n    (m1_n),
        .MREQ_n  (mreq_n),
        .IORQ_n  (iorq_n),
        .RD_n    (rd_n),
        .WR_n    (wr_n),
        .RFSH_n  (rfsh_n),
        .HALT_n  (),
        .BUSAK_n (),
        .A       (cpu_addr),
        .DI      (cpu_din),
        .DO      (cpu_dout)
    );

    logic [14:0] dec_addr;
    always_comb begin
        unique case (cpu_addr[14:13])
            2'b00:   dec_addr = {cpu_addr[14:13], cpu_addr[11], cpu_addr[12], cpu_addr[7], cpu_addr[9:8], cpu_addr[10], cpu_addr[6], cpu_addr[4], cpu_addr[5], cpu_addr[1], cpu_addr[2], cpu_addr[3], cpu_addr[0]};
            2'b01:   dec_addr = {cpu_addr[14:13], cpu_addr[10], cpu_addr[7], cpu_addr[12], cpu_addr[9:8], cpu_addr[11], cpu_addr[6], cpu_addr[3], cpu_addr[1], cpu_addr[5], cpu_addr[2], cpu_addr[4], cpu_addr[0]};
            2'b10:   dec_addr = {cpu_addr[14:13], cpu_addr[7], cpu_addr[10], cpu_addr[11], cpu_addr[9:8], cpu_addr[12], cpu_addr[6], cpu_addr[1], cpu_addr[3], cpu_addr[4], cpu_addr[2], cpu_addr[5], cpu_addr[0]};
            default: dec_addr = {cpu_addr[14:13], cpu_addr[11], cpu_addr[12], cpu_addr[7], cpu_addr[9:8], cpu_addr[10], cpu_addr[6], cpu_addr[4], cpu_addr[5], cpu_addr[1], cpu_addr[2], cpu_addr[3], cpu_addr[0]};
        endcase
    end


    logic [7:0] raw_rom_byte;
    logic [7:0] addr_xor_add;
    logic [7:0] main_rom_dout;

    assign cpu1_addr     = {2'b00, dec_addr[14:1]};
    assign raw_rom_byte  = dec_addr[0] ? cpu1_q[15:8] : cpu1_q[7:0];
    assign addr_xor_add  = {cpu_addr[7:7], cpu_addr[5], cpu_addr[3], cpu_addr[1], cpu_addr[6], cpu_addr[4], cpu_addr[2], cpu_addr[0]};
    assign main_rom_dout = raw_rom_byte + addr_xor_add;

    logic cs_rom, cs_nvram, cs_vram;
    assign cs_rom   = !mreq_n && (cpu_addr[15:15] == 1'b0);
    assign cs_nvram = !mreq_n && (cpu_addr[15:13] == 3'b100);
    assign cs_vram  = !mreq_n && (cpu_addr[15:10] == 6'b101000);

    logic [7:0] nvram_dout;
    spram #(11,8) work_ram (
        .clk    (clk_sys),
        .enable (nvram_initializing || cs_nvram),
        .addr   (nvram_initializing ? nvram_init_cnt[10:0] : cpu_addr[10:0]),
        .din    (nvram_initializing ? 8'hFF : cpu_dout),
        .dout   (nvram_dout),
        .we     (nvram_initializing || (cs_nvram && !wr_n))
    );

    logic [7:0] main_latch;
    logic [7:0] prot_key;
    logic [7:0] sound_latch;
    logic       sound_irq_trig;
    logic       line_irq_15k;

    wire io_wr = !iorq_n && !wr_n;
    wire io_rd = !iorq_n && !rd_n;

    logic io_prot_access, io_prot_access_d;
    assign io_prot_access = (io_wr || io_rd) && (cpu_addr[7:5] == 3'b110);

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            main_latch       <= 8'h00;
            prot_key         <= 8'h00;
            sound_latch      <= 8'h00;
            sound_irq_trig   <= 1'b0;
            io_prot_access_d <= 1'b0;
        end else begin
            sound_irq_trig   <= 1'b0;
            io_prot_access_d <= io_prot_access;

            if (io_wr && (cpu_addr[7:3] == 5'b00100)) begin
                main_latch[cpu_addr[2:0]] <= cpu_dout[0:0];
            end

            if (io_wr && (cpu_addr[7:0] == 8'h40)) begin
                sound_latch <= cpu_dout;
            end
            if (io_wr && (cpu_addr[7:0] == 8'h60)) begin
                sound_irq_trig <= 1'b1;
            end

            if (io_prot_access && !io_prot_access_d) begin
                prot_key <= cpu_addr[15:8];
            end
        end
    end

    logic vblank_d;
    always_ff @(posedge clk_sys) begin
        if (reset || !main_latch[0]) begin
            nmi_n    <= 1'b1;
            vblank_d <= 1'b0;
        end else begin
            vblank_d <= vblank;
            if (vblank && !vblank_d)
                nmi_n <= 1'b0;
        end
    end

    logic [7:0] vram_dout;
    always_comb begin
        cpu_din = 8'hFF;
        if (cs_rom) begin
            cpu_din = main_rom_dout;
        end else if (cs_nvram) begin
            cpu_din = nvram_dout;
        end else if (cs_vram) begin
            cpu_din = vram_dout;
        end else if (io_rd) begin
            unique casez (cpu_addr[7:0])
                8'h80:       cpu_din = dial1;
                8'hA0:       cpu_din = inputs1;
                8'hA4:       cpu_din = dsw2;
                8'hA8:       cpu_din = dsw1;
                8'hB0:       cpu_din = 8'hFF;
                8'hB4:       cpu_din = dsw3;
                8'b110?????: cpu_din = 8'hFF;
                8'b111?????: cpu_din = prot_key;
                default:     cpu_din = 8'hFF;
            endcase
        end
    end

    Video video_inst (
        .clk_sys     (clk_sys),
        .reset       (reset),
        .ce_pix      (ce_pix),
        .vram_addr   (cpu_addr[9:0]),
        .vram_din    (cpu_dout),
        .vram_we     (cs_vram && !wr_n),
        .vram_dout   (vram_dout),
        .pal_addr    (cpu_addr[4:0]),
        .pal_din     (cpu_dout),
        .pal_we      (io_wr && (cpu_addr[7:5] == 3'b000)),
        .tile_bank   (main_latch[2]),
        .cpu3_addr   (cpu3_addr),
        .cpu3_q      (cpu3_q),
        .red         (red),
        .green       (green),
        .blue        (blue),
        .hsync       (hsync),
        .vsync       (vsync),
        .hblank      (hblank),
        .vblank      (vblank),
        .line_irq    (line_irq_15k)
    );

    Audio audio_inst (
        .clk_sys     (clk_sys),
        .reset       (reset),
        .ce_audio    (ce_audio),
        .sound_latch (sound_latch),
        .sound_irq   (sound_irq_trig),
        .line_irq    (line_irq_15k),
        .cpu2_addr   (cpu2_addr),
        .cpu2_q      (cpu2_q),
        .audio_l     (audio_l),
        .audio_r     (audio_r)
    );

endmodule
