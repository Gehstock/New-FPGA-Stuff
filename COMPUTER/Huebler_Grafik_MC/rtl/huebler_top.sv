`timescale 1ns / 1ps
`default_nettype none

module huebler_grafik_top (
    input  logic        clk_10mhz,
    input  logic        clk_9mhz,
    input  logic        rst_n,
    
    input  logic        ps2_kbd_clk,
    input  logic        ps2_kbd_data,
    
    output logic        video_hsync,   
    output logic        video_vsync,   
    output logic        video_hblank,  
    output logic        video_vblank,  
    output logic        video_out,     
    
    input  logic        cassette_in,   
    output logic        cassette_out,  
    
    output logic        audio_out
);

    logic [1:0] clk_divide;
    logic       clk_2_5mhz;

    always_ff @(posedge clk_10mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_divide <= '0;
            clk_2_5mhz <= 1'b0;
        end else begin
            clk_divide <= clk_divide + 1'b1;
            clk_2_5mhz <= clk_divide[1];
        end
    end

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;
    
    logic cpu_m1_n;
    logic cpu_mreq_n;
    logic cpu_iorq_n;
    logic cpu_rd_n;
    logic cpu_wr_n;
    logic cpu_rfsh_n;
    logic cpu_int_n;

    logic [7:0]  pio1_dout;  logic pio1_dout_en;
    logic [7:0]  pio2_dout;  logic pio2_dout_en;
    logic [7:0]  ctc_dout;   logic ctc_dout_en;
    logic [7:0]  sio_dout;   logic sio_dout_en;
    logic [7:0]  vram_dout;
    logic [7:0]  kb_rom_dout;
    logic [7:0]  kombi_rom_dout;
    
    logic [7:0]  ram_32k_dout;
    logic [7:0]  ram_16k_dout;
    logic [7:0]  ram_8k_dout;
    logic [7:0]  ram_2k_dout;

    T80se #(
        .Mode    (0), 
        .T2Write (0),
        .IOWait  (1)
    ) cpu_inst (
        .RESET_n (rst_n),
        .CLK_n   (clk_2_5mhz), 
        .CLKEN   (1'b1),
        .WAIT_n  (1'b1),
        .INT_n   (cpu_int_n),
        .NMI_n   (1'b1),
        .BUSRQ_n (1'b1),
        .M1_n    (cpu_m1_n),
        .MREQ_n  (cpu_mreq_n),
        .IORQ_n  (cpu_iorq_n),
        .RD_n    (cpu_rd_n),
        .WR_n    (cpu_wr_n),
        .RFSH_n  (cpu_rfsh_n),
        .HALT_n  (),
        .BUSAK_n (),
        .A       (cpu_addr),
        .DI      (cpu_din),
        .DO      (cpu_dout)
    );

    wire is_mem = (cpu_mreq_n == 1'b0) && (cpu_rfsh_n == 1'b1);
    wire is_io  = (cpu_iorq_n == 1'b0) && (cpu_m1_n == 1'b1);
    wire [7:0] io_addr = cpu_addr[7:0];

    wire ram_32k_cs   = is_mem && (cpu_addr >= 16'h0000 && cpu_addr <= 16'h7FFF);
    wire ram_16k_cs   = is_mem && (cpu_addr >= 16'h8000 && cpu_addr <= 16'hBFFF);
    wire vram_cs      = is_mem && (cpu_addr >= 16'hE000 && cpu_addr <= 16'hFFFF);
    
    logic        rom_bank_active; 
    wire sys_rom_cs   = is_mem && rom_bank_active && (cpu_addr >= 16'hF000);

    logic       hbasic_active;
    wire        hbasic_cs = is_mem && hbasic_active && (cpu_addr < 16'h4800);

    wire kb_rom_cs = is_io && ((io_addr == 8'h08) || (io_addr == 8'h09) || (io_addr == 8'h0A) || (io_addr == 8'h0B));
    wire pio2_ce_n = !(is_io && (io_addr >= 8'h0C && io_addr <= 8'h0F));
    wire pio1_ce_n = !(is_io && (io_addr >= 8'h10 && io_addr <= 8'h13));
    wire ctc_ce_n  = !(is_io && (io_addr >= 8'h14 && io_addr <= 8'h17));
    wire sio_ce_n  = !(is_io && (io_addr >= 8'h18 && io_addr <= 8'h1B));

    logic [14:0] kombi_rom_addr;

    always_comb begin
        if (sys_rom_cs) begin
            kombi_rom_addr = {3'b000, cpu_addr[11:0]};
        end else begin
            kombi_rom_addr = 15'(cpu_addr[14:0] + 15'h1000);
        end
    end

    always_comb begin
        if (is_mem) begin
            if (hbasic_cs && hbasic_active) cpu_din = kombi_rom_dout;
            else if (ram_32k_cs)             cpu_din = ram_32k_dout;
            else if (ram_16k_cs)             cpu_din = ram_16k_dout;
            else if (sys_rom_cs)             cpu_din = kombi_rom_dout;
            else if (vram_cs)                cpu_din = vram_dout;
            else                             cpu_din = 8'hFF;
        end else if (is_io) begin
            if (kb_rom_cs)       cpu_din = kb_rom_dout;
            else if (pio1_dout_en) cpu_din = pio1_dout;
            else if (pio2_dout_en) cpu_din = pio2_dout;
            else if (ctc_dout_en)  cpu_din = ctc_dout;
            else if (sio_dout_en)  cpu_din = sio_dout;
            else                  cpu_din = 8'hFF;
        end else begin
            cpu_din = 8'hFF;
        end
    end

    spram #(
        .address_width(15)
    ) ram_32k_inst (
        .clock(clk_2_5mhz),
        .enable(ram_32k_cs),
        .address(cpu_addr[14:0]),
        .data(cpu_dout),
        .wren(ram_32k_cs && !cpu_wr_n),
        .q(ram_32k_dout)
    );

    spram #(
        .address_width(14)
    ) ram_16k_inst (
        .clock(clk_2_5mhz),
        .enable(ram_16k_cs),
        .address(cpu_addr[13:0]),
        .data(cpu_dout),
        .wren(ram_16k_cs && !cpu_wr_n),
        .q(ram_16k_dout)
    );

//    spram #(
//        .address_width(13)
//    ) ram_8k_inst (
//        .clock(clk_2_5mhz),
//        .enable(ram_8k_cs),
//        .address(cpu_addr[12:0]),
//        .data(cpu_dout),
//        .wren(ram_8k_cs && !cpu_wr_n),
//        .q(ram_8k_dout)
//    );

//    spram #(
//        .address_width(11)
//    ) ram_2k_inst (
//        .clock(clk_2_5mhz),
//        .enable(ram_2k_cs),
//        .address(cpu_addr[10:0]),
//        .data(cpu_dout),
//        .wren(ram_2k_cs && !cpu_wr_n),
//        .q(ram_2k_dout)
//    );

    spram #(
        .address_width(15)
    ) kombi_rom_inst (
        .clock(clk_2_5mhz),
        .enable(sys_rom_cs || (hbasic_cs && hbasic_active)),
        .address(kombi_rom_addr),
        .data(8'h00),
        .wren(1'b0),
        .q(kombi_rom_dout)
    );
    logic [2:0] ctc_z2_div;
    logic       sio_txca, sio_rxca, sio_rxa;
    logic       sio_txcb_rxcb; 
    logic       sio_txda;      
    
    wire [2:0]  ctc_zc_out;   

    logic ctc_zc2_q;
    always_ff @(posedge clk_2_5mhz) ctc_zc2_q <= ctc_zc_out[2];
    wire ctc_zc2_pulse = (ctc_zc_out[2] && !ctc_zc2_q);

    logic ctc_zc1_q;
    always_ff @(posedge clk_2_5mhz) ctc_zc1_q <= ctc_zc_out[1];
    wire ctc_zc1_pulse = (ctc_zc_out[1] && !ctc_zc1_q);

    always_ff @(posedge clk_2_5mhz or negedge rst_n) begin
        if (!rst_n) sio_txcb_rxcb <= 1'b0;
        else        sio_txcb_rxcb <= ctc_zc1_pulse ? !sio_txcb_rxcb : sio_txcb_rxcb;
    end

    always_ff @(posedge clk_2_5mhz or negedge rst_n) begin
        if (!rst_n) begin
            ctc_z2_div   <= '0;
            cassette_out <= 1'b0;
            sio_txca     <= 1'b0;
            sio_rxca     <= 1'b0;
            sio_rxa      <= 1'b0;
        end else if (ctc_zc2_pulse) begin
            ctc_z2_div <= ctc_z2_div + 1'b1;
            
            case (ctc_z2_div)
                3'd0: cassette_out <= sio_txda;                     
                3'd2: begin sio_txca <= 1'b0; sio_rxca <= 1'b0; end 
                3'd4: begin sio_txca <= 1'b1; sio_rxca <= 1'b1; end 
                3'd6: sio_rxa  <= cassette_in;                      
                default: ;
            endcase
        end
    end

    logic iei_ctc, ieo_ctc, int_ctc;
    logic iei_sio, ieo_sio, int_sio;
    logic iei_pio1, ieo_pio1, int_pio1;
    logic iei_pio2, ieo_pio2, int_pio2;

    assign iei_ctc  = 1'b1; 
    assign iei_sio  = ieo_ctc;
    assign iei_pio1 = ieo_sio;
    assign iei_pio2 = ieo_pio1;

    assign cpu_int_n = int_ctc && int_sio && int_pio1 && int_pio2;

    logic [11:0] scan_counter; logic scan_tick;
    always_ff @(posedge clk_2_5mhz or negedge rst_n) begin
        if (!rst_n) begin scan_counter <= '0; scan_tick <= 1'b0; end
        else begin
            if (scan_counter == 12'd1667) begin scan_counter <= '0; scan_tick <= 1'b1; end 
            else begin scan_counter <= scan_counter + 1'b1; scan_tick <= 1'b0; end
        end
    end

    huebler_keyboard keyboard_inst (
        .clk(clk_2_5mhz),
        .rst_n(rst_n),
        .ps2_kbd_clk(ps2_kbd_clk),
        .ps2_kbd_data(ps2_kbd_data),
        .kb_rom_cs(kb_rom_cs),
        .cpu_a0(cpu_addr[0]),
        .kb_rom_dout(kb_rom_dout),
        .scan_tick(scan_tick)
    );

    huebler_grafik_video video_inst (
        .clk_10mhz(clk_10mhz),
        .clk_9mhz(clk_9mhz),
        .rst_n(rst_n),
        .vram_enable(vram_cs),
        .vram_we(vram_cs && !cpu_wr_n),
        .vram_addr(cpu_addr[12:0]),
        .vram_din(cpu_dout),
        .vram_dout(vram_dout),
        .hsync(video_hsync),
        .vsync(video_vsync),
        .hblank(video_hblank),
        .vblank(video_vblank),
        .video_out(video_out)
    );
    
    logic speaker_signal;
    logic sio_txdb_unused;

    huebler_audio audio_inst (
        .clk(clk_2_5mhz),
        .rst_n(rst_n),
        .speaker_bit(speaker_signal),
        .audio_signal(audio_out)
    );

    z80_ctc ctc_inst (
        .clk(clk_2_5mhz),
        .reset_n(rst_n),
        .cs(cpu_addr[1:0]),
        .ce_n(ctc_ce_n),
        .iorq_n(cpu_iorq_n),
        .rd_n(cpu_rd_n),
        .din(cpu_dout),
        .dout(ctc_dout),
        .dout_en(ctc_dout_en),
        .clk_trg(4'b0000),
        .zc_to(ctc_zc_out), 
        .iei(iei_ctc),
        .ieo(ieo_ctc),
        .int_n(int_ctc)
    );

    z80_sio s_inst (
        .clk(clk_2_5mhz),
        .rst_n(rst_n),
        .m1_n(cpu_m1_n),
        .ba_sel(cpu_addr[0]),
        .cd_sel(cpu_addr[1]),
        .ce_n(sio_ce_n),
        .iorq_n(cpu_iorq_n),
        .rd_n(cpu_rd_n),
        .din(cpu_dout),
        .dout(sio_dout),
        .dout_en(sio_dout_en),
        .txca(sio_txca),
        .rxca(sio_rxca),
        .rxa(sio_rxa),
        .txda(sio_txda),
        .ctsa_n(1'b0),
        .dcda_n(1'b0),
        .dtra_n(),
        .rtsa_n(),
        .txcb(sio_txcb_rxcb),
        .rxcb(sio_txcb_rxcb),
        .rxb(1'b1),
        .txdb(sio_txdb_unused),
        .ctsb_n(1'b0),
        .dcdb_n(1'b0),
        .dtrb_n(),
        .rtsb_n(),
        .iei(iei_sio),
        .ieo(ieo_sio),
        .int_n(int_sio)
    );

    logic [7:0] pio1_port_b_out;
    assign speaker_signal = pio1_port_b_out[0];
    assign hbasic_active = pio1_port_b_out[1];
    assign rom_bank_active = pio1_port_b_out[2];

    z80_pio pio1_inst (
        .clk(clk_2_5mhz),
        .m1_n(cpu_m1_n),
        .ba_sel(cpu_addr[0]),
        .cd_sel(cpu_addr[1]),
        .ce_n(pio1_ce_n),
        .iorq_n(cpu_iorq_n),
        .rd_n(cpu_rd_n),
        .din(cpu_dout),
        .dout(pio1_dout),
        .dout_en(pio1_dout_en),
        .port_a_in(8'hFF),
        .port_a_out(),
        .port_b_in(8'hFF),
        .port_b_out(pio1_port_b_out),
        .iei(iei_pio1),
        .ieo(ieo_pio1),
        .int_n(int_pio1)
    );

    z80_pio pio2_inst (
        .clk(clk_2_5mhz),
        .m1_n(cpu_m1_n),
        .ba_sel(cpu_addr[0]),
        .cd_sel(cpu_addr[1]),
        .ce_n(pio2_ce_n),
        .iorq_n(cpu_iorq_n),
        .rd_n(cpu_rd_n),
        .din(cpu_dout),
        .dout(pio2_dout),
        .dout_en(pio2_dout_en),
        .port_a_in(8'hFF),
        .port_a_out(),
        .port_b_in(8'hFF),
        .port_b_out(),
        .iei(iei_pio2),
        .ieo(ieo_pio2),
        .int_n(int_pio2)
    );

endmodule
`default_nettype wire
