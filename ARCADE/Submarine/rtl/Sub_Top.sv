module Sub_Top (
    input  logic        clk_sys,
    input  logic        reset,
    input  logic [7:0]  in0_pins,
    input  logic [7:0]  in1_pins,
    input  logic [7:0]  dsw0_pins,
    input  logic [7:0]  dsw1_pins,
    output logic [15:0] mrom_addr,
    input  logic [7:0]  mrom_data,
    output logic [12:0] srom_addr,
    input  logic [7:0]  srom_data,
    output logic [14:0] tile_rom_addr,
    input  logic [15:0] tile_rom_data,
    output logic [13:0] spr_rom_addr,
    input  logic [23:0] spr_rom_data,
    output logic [3:0]  video_r,
    output logic [3:0]  video_g,
    output logic [3:0]  video_b,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic        video_hblank,
    output logic        video_vblank,
    output logic [9:0]  audio_out
);

    logic [2:0]  master_div;
    logic        sound_div;
    logic        ce_pix;
    logic        ce_cpu;
    logic        ce_sound;

    logic        int_en;
    logic        flip_screen;
    logic        main_latch_we;
    logic [2:0]  latch_bit;

    logic        main_rst_n;
    logic [15:0] m_addr;
    logic [7:0]  m_data_out;
    logic [7:0]  m_data_in;
    logic        m_m1_n;
    logic        m_mreq_n;
    logic        m_iorq_n;
    logic        m_rd_n;
    logic        m_wr_n;
    logic        m_int_n;

    logic        vblank_irq;
    logic        irq_pending;
    logic        main_ram_we;
    logic [7:0]  m_wram_data;
    logic [7:0]  video_data_in;
    logic [7:0]  soundboard_to_main;

    always_comb begin
        ce_pix        = (master_div == 3'd0 || master_div == 3'd3);
        ce_cpu        = (master_div == 3'd0);
        ce_sound      = (master_div == 3'd0) && sound_div;

        main_latch_we = (~m_mreq_n && ~m_wr_n && (m_addr >= 16'hE800 && m_addr <= 16'hE807));
        latch_bit     = m_addr[2:0];

        m_int_n       = ~irq_pending;
        mrom_addr     = m_addr;
        main_ram_we   = ~m_mreq_n && ~m_wr_n && (m_addr >= 16'hB000 && m_addr <= 16'hBFFF);

        if (~m_rd_n && ~m_mreq_n) begin
            if (m_addr <= 16'hAFFF)
                m_data_in = mrom_data;
            else if (m_addr >= 16'hB000 && m_addr <= 16'hBFFF)
                m_data_in = m_wram_data;
            else if (m_addr >= 16'hC000 && m_addr <= 16'hD85F)
                m_data_in = video_data_in;
            else if (m_addr == 16'hF000)
                m_data_in = dsw0_pins;
            else if (m_addr == 16'hF020)
                m_data_in = dsw1_pins;
            else if (m_addr == 16'hF040)
                m_data_in = in0_pins;
            else if (m_addr == 16'hF060)
                m_data_in = in1_pins;
            else
                m_data_in = 8'hFF;
        end else if (~m_rd_n && ~m_iorq_n && (m_addr[7:0] == 8'h00)) begin
            m_data_in = soundboard_to_main;
        end else begin
            m_data_in = 8'hFF;
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            master_div <= 3'd0;
            sound_div  <= 1'b0;
        end else begin
            if (master_div == 3'd5) begin
                master_div <= 3'd0;
                sound_div  <= ~sound_div;
            end else begin
                master_div <= master_div + 3'd1;
            end
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            int_en      <= 1'b0;
            flip_screen <= 1'b1;
        end else if (ce_cpu && main_latch_we) begin
            case (latch_bit)
                3'd0: int_en      <= m_data_out[0];
                3'd1: flip_screen <= ~m_data_out[0];
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            irq_pending <= 1'b0;
        end else begin
            if (!int_en) begin
                irq_pending <= 1'b0;
            end else if (ce_pix && vblank_irq) begin
                irq_pending <= 1'b1;
            end else if (ce_cpu && !m_m1_n && !m_iorq_n) begin
                irq_pending <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_sys) begin
        main_rst_n <= ~reset;
    end

    T80se main_cpu_inst (
        .RESET_n(main_rst_n),
        .CLK_n  (clk_sys),
        .CLKEN  (ce_cpu),
        .WAIT_n (1'b1),
        .INT_n  (m_int_n),
        .NMI_n  (1'b1),
        .BUSRQ_n(1'b1),
        .M1_n   (m_m1_n),
        .MREQ_n (m_mreq_n),
        .IORQ_n (m_iorq_n),
        .RD_n   (m_rd_n),
        .WR_n   (m_wr_n),
        .A      (m_addr),
        .DI     (m_data_in),
        .DO     (m_data_out)
    );

    spram #(12) main_ram_inst (
        .clk   (clk_sys),
        .enable(1'b1),
        .we    (main_ram_we),
        .addr  (m_addr[11:0]),
        .din   (m_data_out),
        .dout  (m_wram_data)
    );

    Sub_Audio sound (
        .clk_sys   (clk_sys),
        .ce_cpu    (ce_cpu),
        .ce_sound  (ce_sound),
        .reset     (reset),
        .srom_addr (srom_addr),
        .srom_data (srom_data),
        .m_iorq_n  (m_iorq_n),
        .m_wr_n    (m_wr_n),
        .m_rd_n    (m_rd_n),
        .m_addr    (m_addr[7:0]),
        .m_data_out(m_data_out),
        .m_data_in (soundboard_to_main),
        .audio     (audio_out)
    );

    Sub_Video video (
        .clk_sys      (clk_sys),
        .reset        (reset),
        .ce_pix       (ce_pix),
        .m_mreq_n     (m_mreq_n),
        .m_wr_n       (m_wr_n),
        .m_addr       (m_addr),
        .m_data_out   (m_data_out),
        .m_data_in    (video_data_in),
        .flip_screen  (flip_screen),
        .vblank_irq   (vblank_irq),
        .tile_rom_addr(tile_rom_addr),
        .tile_rom_data(tile_rom_data),
        .spr_rom_addr (spr_rom_addr),
        .spr_rom_data (spr_rom_data),
        .rgb_r        (video_r),
        .rgb_g        (video_g),
        .rgb_b        (video_b),
        .hsync        (video_hsync),
        .vsync        (video_vsync),
        .hblank       (video_hblank),
        .vblank       (video_vblank)
    );

endmodule
