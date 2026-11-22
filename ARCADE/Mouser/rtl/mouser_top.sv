module mouser_top (
    input  logic        clk_sys,
    input  logic        rst_n,
    
    input  logic [7:0]  P1,
    input  logic [7:0]  System,
    input  logic [7:0]  DSW,
    input  logic [7:0]  P2,
    
    output logic        video_hs,
    output logic        video_vs,
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b,
    output logic        video_hb,
    output logic        video_vb,
    output logic [9:0]  audio
);

    logic        cpu_clken;
    logic [1:0]  clk_div_3;
    logic        video_clken;
    logic        clk_div_2;
    
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;
    
    logic        cpu_m1_n;
    logic        cpu_mreq_n;
    logic        cpu_iorq_n;
    logic        cpu_rd_n;
    logic        cpu_wr_n;
    logic        cpu_nmi_n;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_3 <= 2'd0;
            cpu_clken <= 1'b0;
        end else begin
            if (clk_div_3 == 2'd2) begin
                clk_div_3 <= 2'd0;
                cpu_clken <= 1'b1;
            end else begin
                clk_div_3 <= clk_div_3 + 2'd1;
                cpu_clken <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_2   <= 1'b0;
            video_clken <= 1'b0;
        end else begin
            clk_div_2   <= !clk_div_2;
            video_clken <= !clk_div_2;
        end
    end

    T80se main_cpu (
        .RESET_n(rst_n),
        .CLK_n(~clk_sys),
        .CLKEN(cpu_clken),
        .WAIT_n(1'b1),
        .INT_n(1'b1),
        .NMI_n(cpu_nmi_n),
        .BUSRQ_n(1'b1),
        .M1_n(cpu_m1_n),
        .MREQ_n(cpu_mreq_n),
        .IORQ_n(cpu_iorq_n),
        .RD_n(cpu_rd_n),
        .WR_n(cpu_wr_n),
        .A(cpu_addr),
        .DI(cpu_din),
        .DO(cpu_dout)
    );

    logic [7:0] rom1_dout, rom2_dout, rom3_dout;
    logic [7:0] current_rom_dout,  decrypted_opc;
    logic [7:0] ram_dout, vram_dout, cram_dout, spram_dout;
    logic is_mreq, is_rom, is_ram, is_vram, is_spram, is_cram;
    logic is_p1, is_latch_write, is_system, is_dsw, is_p2_sound;
    logic ram_wren, vram_wren, cram_wren, spram_wren, latch_wren, sound_latch_wren;
    assign is_mreq       = !cpu_mreq_n;
    assign is_rom        = is_mreq && (cpu_addr <= 16'h5FFF);
    assign is_ram        = is_mreq && (cpu_addr >= 16'h6000 && cpu_addr <= 16'h6BFF);
    assign is_vram       = is_mreq && (cpu_addr >= 16'h9000 && cpu_addr <= 16'h93FF);
    assign is_spram      = is_mreq && (cpu_addr >= 16'h9800 && cpu_addr <= 16'h9BFF);
    assign is_cram       = is_mreq && (cpu_addr >= 16'h9C00 && cpu_addr <= 16'h9FFF);
    
    assign is_p1          = is_mreq && (cpu_addr == 16'hA000) && !cpu_rd_n;
    assign is_latch_write = is_mreq && (cpu_addr >= 16'hA000 && cpu_addr <= 16'hA007) && !cpu_wr_n;
    assign is_system      = is_mreq && (cpu_addr == 16'hA800) && !cpu_rd_n;
    assign is_dsw         = is_mreq && (cpu_addr == 16'hB000) && !cpu_rd_n;
    assign is_p2_sound    = is_mreq && (cpu_addr == 16'hB800);

    assign ram_wren         = is_ram         && !cpu_wr_n;
    assign vram_wren        = is_vram        && !cpu_wr_n;
    assign spram_wren       = is_spram       && !cpu_wr_n;
    assign cram_wren        = is_cram        && !cpu_wr_n;
    assign latch_wren       = is_latch_write;
    assign sound_latch_wren = is_p2_sound    && !cpu_wr_n;

    always_comb begin
        case (cpu_addr[14:13])
            2'b00:   current_rom_dout = rom1_dout;
            2'b01:   current_rom_dout = rom2_dout;
            2'b10:   current_rom_dout = rom3_dout;
            default: current_rom_dout = 8'hFF;
        endcase
    end

    always_comb begin
        if (!cpu_rd_n) begin
            if (is_rom) begin
                cpu_din = !cpu_m1_n ? decrypted_opc : current_rom_dout;
            end else if (is_ram) begin
                cpu_din = ram_dout;
            end else if (is_vram) begin
                cpu_din = vram_dout;
            end else if (is_spram) begin
                cpu_din = spram_dout;
            end else if (is_cram) begin
                cpu_din = cram_dout;
            end else if (is_p1) begin
                cpu_din = P1;
            end else if (is_system) begin
                cpu_din = System;
            end else if (is_dsw) begin
                cpu_din = DSW;
            end else if (is_p2_sound) begin
                cpu_din = P2;
            end else begin
                cpu_din = 8'hFF;
            end
        end else begin
            cpu_din = 8'hFF;
        end
    end

    spram #(12,8) main_work_ram (
        .clock(clk_sys),
        .enable(cpu_clken && is_ram),
        .address(cpu_addr[11:0]),
        .data(cpu_dout),
        .wren(ram_wren),
        .q(ram_dout)
    );

    logic [9:0] video_ram_addr;
    logic [7:0] gen_vram_data;

    dpram #(10,8) video_ram (
        .clock_a(clk_sys),
        .clock_b(clk_sys),
        .enable_a(cpu_clken && is_vram),
        .wren_a(vram_wren),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .q_a(vram_dout),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(video_ram_addr),
        .data_b(8'h00),
        .q_b(gen_vram_data)
    );

    logic [7:0] video_spram_addr;
    logic [7:0] gen_spram_data;

    dpram #(8,8) sprite_ram (
        .clock_a(clk_sys),
        .clock_b(clk_sys),
        .enable_a(cpu_clken && is_spram),
        .wren_a(spram_wren),
        .address_a(cpu_addr[7:0]),
        .data_a(cpu_dout),
        .q_a(spram_dout),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(video_spram_addr),
        .data_b(8'h00),
        .q_b(gen_spram_data)
    );

    logic [9:0] video_cram_addr;
    logic [7:0] gen_cram_data;

    dpram #(10,8) color_ram (
        .clock_a(clk_sys),
        .clock_b(clk_sys),
        .enable_a(cpu_clken && is_cram),
        .wren_a(cram_wren),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .q_a(cram_dout),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(video_cram_addr),
        .data_b(8'h00),
        .q_b(gen_cram_data)
    );

    logic [7:0] sound_cmd;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sound_cmd <= 8'h00;
        end else if (sound_latch_wren) begin
            sound_cmd <= cpu_dout;
        end
    end

    logic nmi_enable;
    logic flip_screen_x;
    logic flip_screen_y;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            nmi_enable    <= 1'b0;
            flip_screen_x <= 1'b0;
            flip_screen_y <= 1'b0;
        end else if (latch_wren && cpu_clken) begin
            case (cpu_addr[2:0])
                3'd0: nmi_enable    <= cpu_dout[0];
                3'd1: flip_screen_x <= ~cpu_dout[0];
                3'd2: flip_screen_y <= ~cpu_dout[0];
                default: ;
            endcase
        end
    end

    logic video_vb_reg;
    logic vblank_set;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            video_vb_reg <= 1'b0;
        end else begin
            video_vb_reg <= video_vb;
        end
    end

    assign vblank_set = video_vb && !video_vb_reg;

    logic nmi_pending;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            nmi_pending <= 1'b0;
        end else begin
            if (!nmi_enable) begin
                nmi_pending <= 1'b0;
            end else if (vblank_set) begin
                nmi_pending <= 1'b1;
            end else if (cpu_clken && !cpu_m1_n && !cpu_mreq_n && cpu_addr == 16'h0066) begin
                nmi_pending <= 1'b0;
            end
        end
    end
    assign cpu_nmi_n = ~nmi_pending;

    logic [15:0] audio_tempo_counter;
    logic        audio_nmi_pulse;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            audio_tempo_counter <= 16'd0;
            audio_nmi_pulse     <= 1'b0;
        end else begin
            if (audio_tempo_counter == 16'd49999) begin 
                audio_tempo_counter <= 16'd0;
                audio_nmi_pulse     <= nmi_enable;
            end else begin
                audio_tempo_counter <= audio_tempo_counter + 16'd1;
                audio_nmi_pulse     <= 1'b0;
            end
        end
    end

    mouser_audio audio_subsystem (
        .clk_sys(clk_sys),
        .rst_n(rst_n),
        .cpu_en(cpu_clken),
        .sound_cmd(sound_cmd),
        .sound_latch_wren(sound_latch_wren),
        .sound_nmi_trigger(audio_nmi_pulse),
        .audio(audio)
    );

    mouser_video video_subsystem (
        .clk_sys(clk_sys),
        .rst_n(rst_n),
        .video_clken(video_clken),
        .flip_x(flip_screen_x),
        .flip_y(flip_screen_y),
        .vram_data(gen_vram_data),
        .cram_data(gen_cram_data),
        .spriteram_data(gen_spram_data),
        .video_ram_addr(video_ram_addr),
        .video_cram_addr(video_cram_addr),
        .video_spram_addr(video_spram_addr),
        .video_hs(video_hs),
        .video_vs(video_vs),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_hb(video_hb),
        .video_vb(video_vb)
    );

    mcpu_rom1 inst_mcpu_rom1 (.clk(clk_sys), .addr(cpu_addr[12:0]), .data(rom1_dout));
    mcpu_rom2 inst_mcpu_rom2 (.clk(clk_sys), .addr(cpu_addr[12:0]), .data(rom2_dout));
    mcpu_rom3 inst_mcpu_rom3 (.clk(clk_sys), .addr(cpu_addr[12:0]), .data(rom3_dout));

    logic [7:0] crypto_h, crypto_l;

    dec_prom_h inst_dec_h (.clk(clk_sys), .addr(current_rom_dout), .data(crypto_h));
    dec_prom_l inst_dec_l (.clk(clk_sys), .addr(current_rom_dout), .data(crypto_l));

    assign decrypted_opc = {crypto_h[3:0], crypto_l[3:0]};

endmodule
