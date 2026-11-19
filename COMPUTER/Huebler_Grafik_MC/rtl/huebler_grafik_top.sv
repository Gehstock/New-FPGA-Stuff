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
    
    output logic        audio_out,

    output logic [15:0] ram_addr,
    output logic [7:0]  ram_din,
    input  logic [7:0]  ram_dout,
    output logic        ram_we,
    output logic        ram_rd
);


    logic [2:0] clk_cnt;
    logic       clk_1_5mhz_en;

    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt       <= 3'd0;
            clk_1_5mhz_en <= 1'b0;
        end else begin
            if (clk_cnt == 3'd5) begin
                clk_cnt       <= 3'd0;
                clk_1_5mhz_en <= 1'b1;
            end else begin
                clk_cnt       <= clk_cnt + 3'd1;
                clk_1_5mhz_en <= 1'b0;
            end
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

    T80se cpu_inst (
        .RESET_n (rst_n),
        .CLK_n   (clk_9mhz), 
        .CLKEN   (clk_1_5mhz_en),
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
        .A       (cpu_addr),
        .DI      (cpu_din),
        .DO      (cpu_dout)
    );

    wire is_mem = (cpu_mreq_n == 1'b0) && (cpu_rfsh_n == 1'b1);
    wire is_io  = (cpu_iorq_n == 1'b0) && (cpu_m1_n == 1'b1);
    wire [7:0] io_addr = cpu_addr[7:0];

    logic rom_off_ff;

    wire rom_off_cs  = is_io && (io_addr[7:2] == 6'h00);
    wire rom_on_cs   = is_io && (io_addr[7:2] == 6'h01);
    wire kb_rom_cs   = is_io && (io_addr[7:2] == 6'h02);
    wire pio_ce_n    = !(is_io && (io_addr[7:2] == 6'h03));
    wire video_io_cs = is_io && (io_addr[7:2] == 6'h04);
    wire ctc_ce_n    = !(is_io && (io_addr[7:2] == 6'h05));
    wire sio_ce_n    = !(is_io && (io_addr[7:2] == 6'h06));

    logic [7:0] video_control_reg;

    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin
            rom_off_ff        <= 1'b0;
            video_control_reg <= 8'h00;
        end else if (clk_1_5mhz_en && is_io) begin
            if (rom_off_cs) begin
                rom_off_ff <= 1'b1;
            end else if (rom_on_cs) begin
                rom_off_ff <= 1'b0;
            end else if (video_io_cs && !cpu_wr_n) begin
                video_control_reg <= cpu_dout;
            end
        end
    end

    wire sys_rom_active = (cpu_addr <= 16'h47FF) && (rom_off_ff == 1'b0);
    wire vram_cs        = is_mem && (cpu_addr >= 16'hC000 && cpu_addr <= 16'hDFFF);
    wire ram_32k_cs     = is_mem && (cpu_addr <= 16'hFFFF) && !sys_rom_active && !vram_cs;

    logic [7:0] kombi_rom_dout;
    logic [7:0] ram_32k_dout;
    logic [7:0] vram_dout;
    logic [7:0] kb_rom_dout;

    logic [7:0] pio1_dout; logic pio1_dout_en;
    logic [7:0] ctc_dout;  logic ctc_dout_en;
    logic [7:0] sio_dout;  logic sio_dout_en;

    always_comb begin
        cpu_din = 8'hFF;
        if (pio1_dout_en)      cpu_din = pio1_dout;
        else if (ctc_dout_en)  cpu_din = ctc_dout;
        else if (sio_dout_en)  cpu_din = sio_dout;
        else if (is_mem) begin
            if (sys_rom_active)      cpu_din = kombi_rom_dout;
            else if (vram_cs)        cpu_din = vram_dout;
            else if (ram_32k_cs)     cpu_din = ram_dout;
        end else if (is_io) begin
            if (kb_rom_cs)           cpu_din = kb_rom_dout;
        end
    end


    assign ram_addr = cpu_addr;
    assign ram_din  = cpu_dout;
    assign ram_we   = ram_32k_cs && !cpu_wr_n;
    assign ram_rd   = ram_32k_cs && !cpu_rd_n && !sys_rom_active && !vram_cs;


    sys_rom kombi_rom_inst (
        .clk  (clk_9mhz),
        .addr (cpu_addr[14:0]),
        .data (kombi_rom_dout)
    );

    logic iei_pio, ieo_pio, int_pio;
    logic iei_ctc, ieo_ctc, int_ctc;
    logic iei_sio, ieo_sio, int_sio;

    assign iei_pio   = 1'b1;
    assign iei_ctc   = ieo_pio;
    assign iei_sio   = ieo_ctc;
    assign cpu_int_n = int_pio & int_ctc & int_sio;

    logic [9:0] scan_counter;
    logic       scan_tick;

    always_ff @(posedge clk_9mhz or negedge rst_n) begin
        if (!rst_n) begin 
            scan_counter <= 10'd0; 
            scan_tick    <= 1'b0; 
        end else if (clk_1_5mhz_en) begin
            if (scan_counter == 10'd999) begin 
                scan_counter <= 10'd0; 
                scan_tick    <= 1'b1; 
            end else begin 
                scan_counter <= scan_counter + 10'd1; 
                scan_tick    <= 1'b0; 
            end
        end else begin
            scan_tick <= 1'b0;
        end
    end

    logic ctc_zc0_out;
    logic ctc_zc1_out;
    logic ctc_zc2_out;
    logic sio_txda_out;
    wire  sio_txca = ctc_zc0_out;
    wire  sio_rxca = ctc_zc0_out;

    assign cassette_out = sio_txda_out;
    wire   sio_rxa      = cassette_in;

    huebler_keyboard keyboard_inst (
        .clk           (clk_9mhz),
        .clk_2_5mhz_en (clk_1_5mhz_en),
        .rst_n         (rst_n),
        .ps2_kbd_clk   (ps2_kbd_clk),
        .ps2_kbd_data  (ps2_kbd_data),
        .kb_rom_cs     (kb_rom_cs),
        .cpu_a0        (cpu_addr[0]),
        .kb_rom_dout   (kb_rom_dout),
        .scan_tick     (scan_tick)
    );

    huebler_grafik_video video_inst (
        .clk_10mhz    (clk_10mhz),
        .rst_n        (rst_n),
        .video_ctrl   (video_control_reg),
        .vram_enable  (vram_cs),
        .vram_we      (vram_cs && !cpu_wr_n),
        .vram_addr    (cpu_addr[12:0]),
        .vram_din     (cpu_dout),
        .vram_dout    (vram_dout),
        .hsync        (video_hsync),
        .vsync        (video_vsync),
        .hblank       (video_hblank),
        .vblank       (video_vblank),
        .video_out    (video_out)
    );
    
    huebler_audio audio_inst (
        .clk          (clk_9mhz),
        .rst_n        (rst_n),
        .tone_on      (video_control_reg[1]),
        .audio_signal (audio_out)
    );

    z80_pio pio_inst (
        .clk        (clk_9mhz),
        .clken      (clk_1_5mhz_en),
        .rst_n      (rst_n),
        .m1_n       (cpu_m1_n),
        .ba_sel     (cpu_addr[1]),
        .cd_sel     (cpu_addr[0]),
        .ce_n       (pio_ce_n),
        .iorq_n     (cpu_iorq_n),
        .rd_n       (cpu_rd_n),
        .din        (cpu_dout),
        .dout       (pio1_dout),
        .dout_en    (pio1_dout_en),
        .port_a_in  (8'hFF),
        .port_a_out (),
        .port_b_in  (8'hFF),
        .port_b_out (),
        .iei        (iei_pio),
        .ieo        (ieo_pio),
        .int_n      (int_pio)
    );

    z80_ctc ctc_inst (
        .clk     (clk_9mhz),
        .clken   (clk_1_5mhz_en),
        .reset_n (rst_n),
        .cs      (cpu_addr[1:0]),
        .ce_n    (ctc_ce_n),
        .m1_n    (cpu_m1_n),
        .iorq_n  (cpu_iorq_n),
        .rd_n    (cpu_rd_n),
        .din     (cpu_dout),
        .dout    (ctc_dout),
        .dout_en (ctc_dout_en),
        .clk_trg ({1'b0, cassette_in, 2'b00}),
        .zc_to   ({ctc_zc2_out, ctc_zc1_out, ctc_zc0_out}), 
        .iei     (iei_ctc),
        .ieo     (ieo_ctc),
        .int_n   (int_ctc)
    );

    z80_sio s_inst (
        .clk     (clk_9mhz),
        .rst_n   (rst_n),
        .m1_n    (cpu_m1_n),
        .ba_sel  (cpu_addr[1]),
        .cd_sel  (cpu_addr[0]),
        .ce_n    (sio_ce_n),
        .iorq_n  (cpu_iorq_n),
        .rd_n    (cpu_rd_n),
        .din     (cpu_dout),
        .dout    (sio_dout),
        .dout_en (sio_dout_en),
        .txca    (sio_txca),
        .rxca    (sio_rxca),
        .rxa     (sio_rxa),
        .txda    (sio_txda_out),
        .ctsa_n  (1'b0),
        .dcda_n  (1'b0),
        .dtra_n  (),
        .rtsa_n  (),
        .txcb    (1'b0),
        .rxcb    (1'b0),
        .rxb     (1'b1),
        .txdb    (),
        .ctsb_n  (1'b0),
        .dcdb_n  (1'b0),
        .dtrb_n  (),
        .rtsb_n  (),
        .iei     (iei_sio),
        .ieo     (ieo_sio),
        .int_n   (int_sio)
    );

endmodule
