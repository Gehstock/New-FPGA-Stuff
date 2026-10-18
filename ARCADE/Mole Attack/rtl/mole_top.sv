module mole_top (
    input  logic        clk_sys,
    input  logic        rst_n,
    
    input  logic [9:1]  p1_buttons,
    input  logic [9:1]  p2_buttons,
    input  logic        cabinet,
    input  logic        coin_input,
    input  logic        start1_button,
    input  logic        start2_button,
    input  logic [7:0]  dip_switches,
    
    output logic        video_hs,
    output logic        video_vs,
    output logic        video_r,
    output logic        video_g,
    output logic        video_b,
    output logic        video_hb,
    output logic        video_vb,
    output logic [9:0]  audio
);

    // Alle internen Deklarationen sauber an den Anfang gesetzt
    logic        tile_bank;    
    logic        video_flip;   
    logic [3:0]  clk_div;
    logic        cpu_en;
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;
    logic        cpu_rw_n;
    logic        cpu_irq_n;
    
    logic        video_vb_reg;
    logic        irq_pending;

    logic [7:0]  ram_dout;
    logic [7:0]  rom1_data;
    logic [7:0]  rom2_data;
    logic [7:0]  rom3_data;
    logic [7:0]  current_rom_data;
    logic [7:0]  tile_ram_dout;
    logic [7:0]  sound_dout;
    logic        sound_ack;
    logic [7:0]  protection_dout;

    logic        is_ram;
    logic        is_protection;
    logic        is_tileram;
    logic        is_tilebank;
    logic        is_dsw;
    logic        is_in0;
    logic        is_in1;
    logic        is_in2;
    logic        is_rom_zone;

    logic        ram_wren;
    logic        tile_ram_we;
    logic        tilebank_we;
    logic        irq_ack_we;
    logic        flipscreen_we;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 4'd0;
            cpu_en   <= 1'b0;
        end else begin
            clk_div  <= clk_div + 4'd1;
            cpu_en   <= (clk_div == 4'd0); // Erzeugt genau alle 16 Zyklen einen Puls (Taktdrosselung)
        end
    end

    T65 cpu_core (
        .Res_n   (rst_n),
        .Enable  (cpu_en),
        .Clk     (clk_sys),
        .Rdy     (1'b1),
        .Abort_n (1'b1),
        .IRQ_n   (cpu_irq_n),
        .NMI_n   (1'b1),
        .SO_n    (1'b1),
        .R_W_n   (cpu_rw_n),
        .A       (cpu_addr),
        .DI      (cpu_din),
        .DO      (cpu_dout)
    );

    assign is_ram        = (cpu_addr <= 16'h03FF);
    assign is_protection = (cpu_addr >= 16'h0800 && cpu_addr <= 16'h08FF);
    assign is_tileram    = (cpu_addr >= 16'h8000 && cpu_addr <= 16'h83FF);
    assign is_tilebank   = (cpu_addr == 16'h8400);
    assign is_dsw        = (cpu_addr == 16'h8D00);
    assign is_in0        = (cpu_addr == 16'h8D40);
    assign is_in1        = (cpu_addr == 16'h8D80);
    assign is_in2        = (cpu_addr == 16'h8DC0);
    assign is_rom_zone   = (cpu_addr >= 16'h5000 && cpu_addr <= 16'h7FFF) || (cpu_addr >= 16'hD000 && cpu_addr <= 16'hFFFF);

    assign ram_wren      = is_ram     && (!cpu_rw_n) && cpu_en;
    assign tile_ram_we   = is_tileram && (!cpu_rw_n) && cpu_en;
    assign tilebank_we   = is_tilebank && (!cpu_rw_n) && cpu_en;
    assign irq_ack_we    = (cpu_addr == 16'h8D00) && (!cpu_rw_n) && cpu_en;
    assign flipscreen_we = is_in2     && (!cpu_rw_n) && cpu_en;

    logic [15:0] prot_offset;
    assign prot_offset = cpu_addr - 16'h0800;

    logic [2:0] prot_history;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            prot_history <= 3'b000;
        end else if (cpu_en) begin
            if (cpu_addr == 16'h0800)      prot_history[0] <= 1'b1;
            else if (cpu_addr == 16'h0802) prot_history[1] <= 1'b1;
            else if (cpu_addr == 16'h0804) prot_history[2] <= 1'b1;
            else if (is_protection && (prot_offset[7:0] == 8'h26)) prot_history <= 3'b000;
        end
    end

    always_comb begin
        if (is_protection) begin
            case (prot_offset[7:0])
                8'h08:   protection_dout = 8'hb0;
                8'h26:   protection_dout = (&prot_history) ? 8'h06 : 8'hc6;
                8'h86:   protection_dout = 8'h91;
                8'hae:   protection_dout = 8'h32;
                default: protection_dout = 8'h00;
            endcase
        end else begin
            protection_dout = 8'h00;
        end
    end

    logic [14:0] rom_addr_rel;
    assign rom_addr_rel = cpu_addr[14:0];

    always_comb begin
        case (rom_addr_rel[14:12])
            3'b101:  current_rom_data = rom3_data;
            3'b110:  current_rom_data = rom2_data;
            3'b111:  current_rom_data = rom1_data;
            default: current_rom_data = 8'hFF;
        endcase
    end

    always_comb begin
        if (is_ram) begin
            cpu_din = ram_dout;
        end else if (is_protection) begin
            cpu_din = protection_dout;
        end else if (is_dsw && cpu_rw_n) begin
            cpu_din = dip_switches;
        end else if (is_in0 && cpu_rw_n) begin
            cpu_din = {p1_buttons[8], p1_buttons[7], p1_buttons[6], p1_buttons[5], 
                       p1_buttons[4], p1_buttons[3], p1_buttons[2], p1_buttons[1]};
        end else if (is_in1 && cpu_rw_n) begin
            cpu_din = {coin_input, start1_button, start2_button, cabinet, 
                       p2_buttons[3], p2_buttons[2], p2_buttons[1], p1_buttons[9]};
        end else if (is_in2 && cpu_rw_n) begin
            cpu_din = {2'b00, p2_buttons[5], p2_buttons[6], p2_buttons[9], 
                       p2_buttons[4], p2_buttons[7], p2_buttons[8]};
        end else if (is_tileram) begin
            cpu_din = tile_ram_dout;
        end else if (sound_ack && cpu_rw_n) begin
            cpu_din = sound_dout;
        end else if (is_rom_zone) begin
            cpu_din = current_rom_data;
        end else begin
            cpu_din = 8'hFF;
        end
    end

    spram #(10,8) main_work_ram (
        .clock  (clk_sys),
        .enable (1'b1),
        .address(cpu_addr[9:0]),
        .data   (cpu_dout),
        .wren   (ram_wren),
        .q      (ram_dout)
    );

    rom_m3a rom_inst_3 (
        .clk (clk_sys),
        .addr(cpu_addr[11:0]),
        .data(rom3_data)
    );

    rom_m2a rom_inst_2 (
        .clk (clk_sys),
        .addr(cpu_addr[11:0]),
        .data(rom2_data)
    );

    rom_m1a rom_inst_1 (
        .clk (clk_sys),
        .addr(cpu_addr[11:0]),
        .data(rom1_data)
    );

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            tile_bank <= 1'b0;
        end else if (tilebank_we) begin
            tile_bank <= cpu_dout[0];
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            video_flip <= 1'b0;
        end else if (flipscreen_we) begin
            video_flip <= cpu_dout[0];
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            irq_pending  <= 1'b0;
            video_vb_reg <= 1'b0;
        end else begin
            video_vb_reg <= video_vb;
            if (video_vb && !video_vb_reg) begin
                irq_pending <= 1'b1;
            end else if (irq_ack_we) begin
                irq_pending <= 1'b0;
            end
        end
    end

    mole_audio audio_sub (
        .clk_sys    (clk_sys),
        .rst_n      (rst_n),
        .cpu_en     (cpu_en),
        .cpu_addr   (cpu_addr),
        .cpu_dout   (cpu_dout),
        .cpu_rw_n   (cpu_rw_n),
        .sound_dout (sound_dout),
        .sound_ack  (sound_ack),
        .audio      (audio)
    );

    mole_video video_sub (
        .clk_sys   (clk_sys),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_addr[9:0]),
        .cpu_din   (cpu_dout),
        .cpu_we    (tile_ram_we),
        .cpu_dout  (tile_ram_dout),
        .tile_bank (tile_bank),
        .video_flip(video_flip),
        .video_hs  (video_hs),
        .video_vs  (video_vs),
        .video_r   (video_r),
        .video_g   (video_g),
        .video_b   (video_b),
        .video_hb  (video_hb),
        .video_vb  (video_vb)
    );

    assign cpu_irq_n = !irq_pending;

endmodule
