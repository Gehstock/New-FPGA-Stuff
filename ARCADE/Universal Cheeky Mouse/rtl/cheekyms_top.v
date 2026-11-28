module cheekyms_top (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire [7:0]  p1_inputs,
    input  wire [7:0]  dip_switches,
    input  wire        coin_pulse,
    output wire [7:0]  audio,
    output wire        ce_pix,
    output wire        video_r,
    output wire        video_g,
    output wire        video_b,
    output wire        video_hs,
    output wire        video_vs,
    output wire        video_hb,
    output wire        video_vb
);

    reg [1:0] clk_div_vid;
    reg [3:0] clk_div_z80;
    reg       clk_vid_en;
    reg       z80_clken;

    assign ce_pix = clk_vid_en;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_vid <= 2'd0;
            clk_div_z80 <= 4'd0;
            clk_vid_en  <= 1'b0;
            z80_clken   <= 1'b0;
        end else begin
            if (clk_div_vid == 2'd3) begin
                clk_div_vid <= 2'd0;
                clk_vid_en  <= 1'b1;
            end else begin
                clk_div_vid <= clk_div_vid + 2'd1;
                clk_vid_en  <= 1'b0;
            end

            if (clk_div_z80 == 4'd8) begin
                clk_div_z80 <= 4'd0;
                z80_clken   <= 1'b1;
            end else begin
                clk_div_z80 <= clk_div_z80 + 4'd1;
                z80_clken   <= 1'b0;
            end
        end
    end

    wire [15:0] z80_addr;
    wire [7:0]  z80_data_out;
    reg  [7:0]  z80_data_in;
    wire        z80_mreq_n;
    wire        z80_iorq_n;
    wire        z80_rd_n;
    wire        z80_wr_n;
    wire        z80_m1_n;
    wire        z80_int_n;
    wire        z80_nmi_n;

    wire cpu_mreq = ~z80_mreq_n;
    wire cpu_iorq = ~z80_iorq_n;
    wire cpu_rd   = ~z80_rd_n;
    wire cpu_wr   = ~z80_wr_n;
    wire cpu_m1   = ~z80_m1_n;

    wire rom_en      = cpu_mreq && (z80_addr <= 16'h1FFF);
    wire ram_en      = cpu_mreq && (z80_addr >= 16'h3000 && z80_addr <= 16'h33FF);
    wire videoram_en = cpu_mreq && (z80_addr >= 16'h3800 && z80_addr <= 16'h3BFF);

    wire [7:0] rom_q;
    wire [7:0] ram_q;
    wire [7:0] cpu_vram_rddata;

    main_rom main_rom (
        .clk  (clk_sys),
        .addr (z80_addr[12:0]),
        .data (rom_q)
    );

    spram #(
        .address_width(10),
        .data_width(8)
    ) work_ram (
        .clock   (clk_sys),
        .enable  (1'b1),
        .address (z80_addr[9:0]),
        .data    (z80_data_out),
        .wren    (cpu_wr && ram_en && z80_clken),
        .q       (ram_q)
    );

    reg  [7:0] port_80_reg;
    reg  [7:0] audio_latch;
    wire       sprite_ram_wr = cpu_iorq && cpu_wr && (z80_addr[7:5] == 3'b001);

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            port_80_reg <= 8'h02;
            audio_latch <= 8'hFF;
        end else if (cpu_iorq && cpu_wr && z80_clken) begin
            case (z80_addr[7:0])
                8'h40: audio_latch <= z80_data_out;
                8'h80: port_80_reg <= z80_data_out;
            endcase
        end
    end

    reg [7:0] vram_rddata_reg;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            vram_rddata_reg <= 8'h00;
        end else if (z80_clken) begin
            vram_rddata_reg <= cpu_vram_rddata;
        end
    end

    always @(*) begin
        z80_data_in = 8'hFF;

        if (cpu_rd) begin
            if (cpu_mreq) begin
                if (rom_en)           z80_data_in = rom_q;
                else if (ram_en)      z80_data_in = ram_q;
                else if (videoram_en) z80_data_in = vram_rddata_reg;
            end

            if (cpu_iorq && !cpu_m1) begin
                case (z80_addr[1:0])
                    2'b00:   z80_data_in = dip_switches;
                    2'b01:   z80_data_in = p1_inputs;
                    default: z80_data_in = 8'hFF;
                endcase
            end
        end
    end

    wire vblank_irq_sig;
    wire irq_enabled = port_80_reg[2:2];
    reg  vblank_irq_pending;
    reg  vblank_prev;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            vblank_prev        <= 1'b0;
            vblank_irq_pending <= 1'b0;
        end else begin
            vblank_prev <= vblank_irq_sig;
            if (!vblank_prev && vblank_irq_sig) begin
                if (irq_enabled) vblank_irq_pending <= 1'b1;
            end

            if (!irq_enabled || (cpu_m1 && cpu_iorq && z80_clken)) begin
                vblank_irq_pending <= 1'b0;
            end
        end
    end
    assign z80_int_n = (vblank_irq_pending && irq_enabled) ? 1'b0 : 1'b1;

    reg coin_pulse_q1, coin_pulse_q2;
    wire coin_edge = (coin_pulse_q1 && !coin_pulse_q2);
    reg [5:0] nmi_cnt;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            coin_pulse_q1 <= 1'b0;
            coin_pulse_q2 <= 1'b0;
            nmi_cnt       <= 6'd0;
        end else begin
            coin_pulse_q1 <= coin_pulse;
            coin_pulse_q2 <= coin_pulse_q1;

            if (coin_edge) begin
                nmi_cnt <= 6'd32;
            end else if (z80_clken && (nmi_cnt != 6'd0)) begin
                nmi_cnt <= nmi_cnt - 6'd1;
            end
        end
    end
    assign z80_nmi_n = (nmi_cnt != 6'd0) ? 1'b0 : 1'b1;

    cheekyms_video video_board (
        .clk_sys         (clk_sys),
        .clk_vid_en      (clk_vid_en),
        .rst_n           (rst_n),
        .cpu_vram_addr   (z80_addr[9:0]),
        .cpu_vram_data   (z80_data_out),
        .cpu_vram_wr     (cpu_wr && videoram_en && z80_clken),
        .cpu_vram_rddata (cpu_vram_rddata),
        .cpu_sram_addr   (z80_addr[4:0]),
        .cpu_sram_data   (z80_data_out),
        .cpu_sram_wr     (sprite_ram_wr && z80_clken),
        .port_80_reg     (port_80_reg),
        .vblank_irq      (vblank_irq_sig),
        .video_r         (video_r),
        .video_g         (video_g),
        .video_b         (video_b),
        .video_hs        (video_hs),
        .video_vs        (video_vs),
        .video_hb        (video_hb),
        .video_vb        (video_vb)
    );

    cheekyms_audio audio_board (
        .clk_sys      (clk_sys),
        .rst_n        (rst_n),
        .i_music      (audio_latch[7]),
        .i_cheese     (audio_latch[6]),
        .i_hammer     (audio_latch[5]),
        .i_mouse_dies (audio_latch[4]),
        .i_pest_dies  (audio_latch[3]),
        .i_mouse      (audio_latch[2]),
        .i_pest       (audio_latch[1]),
        .i_coin_extra (port_80_reg[1]),
        .i_mute       (port_80_reg[0]),
        .i_coin_in    (coin_pulse_q1),
        .audio_out    (audio)
    );

    T80se #(
        .Mode(0),
        .T2Write(0),
        .IOWait(1)
    ) u_z80_cpu (
        .RESET_n (rst_n),
        .CLK_n   (clk_sys),
        .CLKEN   (z80_clken),
        .WAIT_n  (1'b1),
        .INT_n   (z80_int_n),
        .NMI_n   (z80_nmi_n),
        .BUSRQ_n (1'b1),
        .M1_n    (z80_m1_n),
        .MREQ_n  (z80_mreq_n),
        .IORQ_n  (z80_iorq_n),
        .RD_n    (z80_rd_n),
        .WR_n    (z80_wr_n),
        .RFSH_n  (),
        .HALT_n  (),
        .BUSAK_n (),
        .A       (z80_addr),
        .DI      (z80_data_in),
        .DO      (z80_data_out)
    );

endmodule
