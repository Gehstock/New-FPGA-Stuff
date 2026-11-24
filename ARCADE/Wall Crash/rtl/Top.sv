module Top (
    input  logic        clk_sys,
    input  logic        reset,

    output logic [16:1] cpu1_addr,
    input  logic [15:0] cpu1_q,

    output logic [16:1] cpu3_addr,
    input  logic [15:0] cpu3_q,

    input  logic [7:0]  dial,
    input  logic [7:0]  system_in,
    input  logic [7:0]  dsw1,
    input  logic [7:0]  dsw2,

    output logic [3:0]  red,
    output logic [3:0]  green,
    output logic [3:0]  blue,
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic [9:0]  audio
);

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;
    logic        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
    logic        int_n;
	 
    logic [4:0] clk_div;
    always_ff @(posedge clk_sys) begin
        if (reset) clk_div <= 5'd0;
        else       clk_div <= clk_div + 5'd1;
    end

    wire ce_pix  = (clk_div[2:0] == 3'b111);
    wire ce_main = (clk_div[3:0] == 4'b1111);
    wire ce_ay   = (clk_div[4:0] == 5'b11111);

    T80s #(
        .Mode(0),
        .T2Write(1),
        .IOWait(1)
    ) maincpu (
        .RESET_n (~reset),
        .CLK     (clk_sys),
        .CEN     (ce_main),
        .WAIT_n  (1'b1),
        .INT_n   (int_n),
        .NMI_n   (1'b1),
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

    assign cpu1_addr = {3'b000, cpu_addr[13:1]};

    logic [7:0] raw_rom_byte;
    logic [7:0] xor_byte;
    logic [7:0] main_rom_dout;

    assign raw_rom_byte = cpu_addr[0] ? cpu1_q[15:8] : cpu1_q[7:0];
    assign xor_byte     = raw_rom_byte ^ 8'hAA;
    assign main_rom_dout = {
        xor_byte[4], xor_byte[2], xor_byte[6], xor_byte[0],
        xor_byte[7], xor_byte[1], xor_byte[3], xor_byte[5]
    };

    wire cs_rom     = !mreq_n && (cpu_addr[15] == 1'b0);
    wire cs_vram    = !mreq_n && (cpu_addr[15:12] == 4'h8);
    wire cs_wram    = !mreq_n && (cpu_addr[15:10] == 6'b101000);
    wire cs_io_mem  = !mreq_n && (cpu_addr[15:12] == 4'hB);

    logic [7:0] wram_dout;
    spram #(10,8) work_ram (
        .clk    (clk_sys),
        .enable (cs_wram),
        .addr   (cpu_addr[9:0]),
        .din    (cpu_dout),
        .dout   (wram_dout),
        .we     (cs_wram && !wr_n)
    );

    logic vblank_d;
    always_ff @(posedge clk_sys) begin
        if (reset) begin
            int_n <= 1'b1;
        end else begin
            vblank_d <= vblank;
            if (vblank && !vblank_d)
                int_n <= 1'b0;
            else if (!iorq_n && !m1_n)
                int_n <= 1'b1;
        end
    end

    logic [7:0] ay_dout;
    Audio audio_inst (
        .clk_sys   (clk_sys),
        .reset     (reset),
        .ce_ay     (ce_ay),
        .ay_cs     (cs_io_mem),
        .ay_addr_w (!wr_n && (cpu_addr[11:8] == 4'h5)),
        .ay_data_w (!wr_n && (cpu_addr[11:8] == 4'h6)),
        .ay_data_r (!rd_n && (cpu_addr[11:8] == 4'h6)),
        .din       (cpu_dout),
        .dout      (ay_dout),
        .dsw2      (dsw2),
        .audio   	 (audio)
    );

    logic [7:0] vram_dout;
    always_comb begin
        cpu_din = 8'hFF;
        if (cs_rom) begin
            cpu_din = main_rom_dout;
        end else if (cs_vram) begin
            cpu_din = vram_dout;
        end else if (cs_wram) begin
            cpu_din = wram_dout;
        end else if (cs_io_mem && !rd_n) begin
            unique case (cpu_addr[11:8])
                4'h0:    cpu_din = dsw1;
                4'h2:    cpu_din = system_in;
                4'h4:    cpu_din = dial;
                4'h6:    cpu_din = ay_dout;
                default: cpu_din = 8'hFF;
            endcase
        end
    end

    Video video_inst (
        .clk_sys   (clk_sys),
        .reset     (reset),
        .ce_pix    (ce_pix),
        .vram_addr (cpu_addr[9:0]),
        .vram_din  (cpu_dout),
        .vram_we   (cs_vram && !wr_n),
        .vram_dout (vram_dout),
        .cpu3_addr (cpu3_addr),
        .cpu3_q    (cpu3_q),
        .red       (red),
        .green     (green),
        .blue      (blue),
        .hsync     (hsync),
        .vsync     (vsync),
        .hblank    (hblank),
        .vblank    (vblank)
    );

endmodule
