//Gehstock 2026
`timescale 1 ps / 1 ps
`default_nettype none

module bcs3_Hack_top (
    input  logic        clk_in_5mhz,    
    input  logic        reset_n,        
    input  logic        ps2_kbd_clk,    
    input  logic        ps2_kbd_data,   
    input  logic        cassette_in,    
    output logic        cassette_out,   
    input  logic [7:0]  pio_port_a_in,  
    output logic [7:0]  pio_port_a_out,
    input  logic [7:0]  pio_port_b_in,  
    output logic [7:0]  pio_port_b_out,
    input  logic [3:0]  ctc_clk_trg,   
    output logic        hsync,     
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic        video_out
);

    logic clk_div_reg;
    logic cpu_clken;

    always_ff @(posedge clk_in_5mhz or negedge reset_n) begin
        if (!reset_n) begin
            clk_div_reg <= 1'b0;
            cpu_clken   <= 1'b0;
        end else begin
            clk_div_reg <= ~clk_div_reg;
            cpu_clken   <= clk_div_reg; 
        end
    end

    logic        z80_m1_n, z80_mreq_n, z80_iorq_n, z80_rd_n, z80_wr_n, z80_rfsh_n, z80_int_n;
    logic [15:0] z80_addr; 
    logic [7:0]  z80_data_to_cpu, z80_data_from_cpu;
    
    logic        w_video_wait_n; 
    logic        z80_wait_n, NMI_n;

    assign z80_wait_n = w_video_wait_n;

    logic ctc_ieo;
    logic raw_ctc_int_n;
    logic raw_pio_int_n;
    logic daisy_ctc_int_n;
    logic daisy_pio_int_n;
    
    assign z80_int_n = daisy_ctc_int_n & daisy_pio_int_n;

    logic rom_ce, rom2_ce, kbd_ce, video_ce, zx_r_ce, vram_ce, sys_ram_ce, pio_ce_n, ctc_ce_n;
    logic [15:0] masked_addr;
    logic [11:0] rom_addr;

    assign masked_addr = (z80_addr < 16'h2000) ? z80_addr : 
                         (z80_addr >= 16'h2000 && z80_addr <= 16'h3BFF) ? {z80_addr[15:14], 1'b0, z80_addr[12:0]} : 
                         z80_addr;

    always_comb begin
        rom_ce     = 1'b0; 
        rom2_ce    = 1'b0;
        kbd_ce     = 1'b0; 
        video_ce   = 1'b0; 
        zx_r_ce    = 1'b0; 
        vram_ce    = 1'b0;
        sys_ram_ce = 1'b0;
        
        if (!z80_mreq_n && z80_rfsh_n) begin
            if (masked_addr <= 16'h0FFF)                                 rom_ce     = 1'b1; 
            else if (masked_addr >= 16'h1000 && masked_addr <= 16'h13FF) kbd_ce     = 1'b1; 
            else if (masked_addr >= 16'h1400 && masked_addr <= 16'h17FF) video_ce   = 1'b1; 
            else if (masked_addr >= 16'h1800 && masked_addr <= 16'h1BFF) zx_r_ce    = 1'b1; 
            else if (z80_addr >= 16'h3C00 && z80_addr <= 16'h3FFF)       vram_ce    = 1'b1; // 1 KB Video-RAM Fenster
            else if (z80_addr >= 16'h4000 && z80_addr <= 16'h7FFF)       sys_ram_ce = 1'b1; // 16 KB Haupt-RAM Fenster
            else if (z80_addr >= 16'hF000 && z80_addr <= 16'hF3FF)       rom2_ce    = 1'b1;
        end
    end

    assign rom_addr = rom2_ce ? {2'b01, z80_addr[9:0]} : masked_addr[11:0];

    always_comb begin
        pio_ce_n = 1'b1; 
        ctc_ce_n = 1'b1; 
        if (!z80_iorq_n && z80_m1_n) begin
            if (z80_addr[7:2] == 6'b000000)      pio_ce_n = 1'b0; 
            else if (z80_addr[7:2] == 6'b000001) ctc_ce_n = 1'b0; 
        end
    end

    logic [7:0] rom_q, kbd_q, vram_q, sys_ram_q, ctc_dout, pio_dout;
    logic       ctc_dout_en, pio_dout_en;

    logic [7:0] zx_r_data;
    assign zx_r_data = 8'hF7; 

    logic [9:0]  vga_vram_addr; 
    logic [7:0]  vram_char_code;

    dpram #(
        .address_width(10), .data_width(8)
    ) u_video_ram (
        .clock     (clk_in_5mhz),
        .enable_a  (vram_ce),
        .wren_a    (!z80_wr_n),
        .address_a (z80_addr[9:0]), 
        .data_a    (z80_data_from_cpu),
        .q_a       (vram_q),
        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (vga_vram_addr),
        .data_b    (8'h00),
        .q_b       (vram_char_code)
    );

    spram #(
        .address_width(14), .data_width(8)
    ) u_system_ram (
        .clock   (clk_in_5mhz),
        .enable  (sys_ram_ce),
        .wren    (!z80_wr_n),
        .address (z80_addr[13:0]),
        .data    (z80_data_from_cpu),
        .q       (sys_ram_q)
    );

    always_comb begin
        z80_data_to_cpu = 8'hFF;
        
        if (!z80_rd_n && !z80_mreq_n) begin
            if (rom_ce || rom2_ce)  z80_data_to_cpu = rom_q;
            else if (kbd_ce)        z80_data_to_cpu = kbd_q;
            else if (video_ce)      z80_data_to_cpu = 8'hFF; 
            else if (zx_r_ce)       z80_data_to_cpu = zx_r_data;
            else if (vram_ce)       z80_data_to_cpu = vram_q;
            else if (sys_ram_ce)    z80_data_to_cpu = sys_ram_q;
        end else if (!z80_iorq_n) begin
            if (ctc_dout_en)        z80_data_to_cpu = ctc_dout;
            else if (pio_dout_en)   z80_data_to_cpu = pio_dout;
        end
    end

    logic [2:0] ctc_zc_to;
    logic       cass_bit;

    always_ff @(posedge clk_in_5mhz or negedge reset_n) begin
        if (!reset_n) begin
            cass_bit     <= 1'b0;
            cassette_out <= 1'b0;
        end else begin
            if (ctc_zc_to) begin 
                cass_bit     <= ~cass_bit;
                cassette_out <= cass_bit; 
            end
        end
    end

    z80_daisy u_daisy_ctc (
        .clk        (clk_in_5mhz),
        .rst_n      (reset_n),
        .m1_n       (z80_m1_n),
        .iorq_n     (z80_iorq_n),
        .data_in    (z80_data_from_cpu), 
        .iei        (1'b1),              
        .ieo        (ctc_ieo),           
        .irq_req    (!raw_ctc_int_n),    
        .irq_active (),
        .int_n      (daisy_ctc_int_n)    
    );

    z80_daisy u_daisy_pio (
        .clk        (clk_in_5mhz),
        .rst_n      (reset_n),
        .m1_n       (z80_m1_n),
        .iorq_n     (z80_iorq_n),
        .data_in    (z80_data_from_cpu),
        .iei        (ctc_ieo),           
        .ieo        (),                  
        .irq_req    (!raw_pio_int_n),    
        .irq_active (),
        .int_n      (daisy_pio_int_n)    
    );

    T80se u_cpu (
        .RESET_n (reset_n), 
        .CLK_n   (clk_in_5mhz), 
        .CLKEN   (cpu_clken), 
        .WAIT_n  (z80_wait_n),
        .INT_n   (z80_int_n), 
        .NMI_n   (NMI_n), 
        .BUSRQ_n (1'b1), 
        .M1_n    (z80_m1_n), 
        .MREQ_n  (z80_mreq_n),
        .IORQ_n  (z80_iorq_n), 
        .RD_n    (z80_rd_n), 
        .WR_n    (z80_wr_n), 
        .RFSH_n  (z80_rfsh_n),
        .HALT_n  (),
        .BUSAK_n (),
        .A       (z80_addr), 
        .DI      (z80_data_to_cpu), 
        .DO      (z80_data_from_cpu)
    );
	 
    SE33_rom u_SE33_rom (
        .clk  (clk_in_5mhz),
        .addr (rom_addr), 
        .data (rom_q)
    );

    bcs3_keyboard_sys u_keyboard (
        .clk          (clk_in_5mhz),
        .rst_n        (reset_n),
        .addr_offset  (masked_addr[9:0]),
        .rd_n         (z80_rd_n || !kbd_ce),
        .data_out     (kbd_q),
        .cassette_in  (cassette_in),
        .ps2_kbd_clk  (ps2_kbd_clk),    
        .ps2_kbd_data (ps2_kbd_data),
        .NMI_n			 (NMI_n)		  
    );

    bcs3_Hack_video u_video (
        .clk_sys       (clk_in_5mhz), 
        .reset_n       (reset_n), 
        .video_ce      (video_ce), 
        .video_wr      (!z80_wr_n && video_ce),
        .video_addr    (z80_addr[11:0]), 
        .video_data_in (z80_data_from_cpu), 
        .video_data_out(), 
        .video_wait_n  (w_video_wait_n), 
        .vram_char_code(vram_char_code),    
        .vga_vram_addr (vga_vram_addr),   
        .hsync         (hsync), 
        .vsync         (vsync), 
        .hblank        (hblank),
        .vblank        (vblank),
        .video_out     (video_out)
    );

    z80_ctc u_ctc (
        .clk     (clk_in_5mhz), 
        .reset_n (reset_n), 
        .cs      (z80_addr[1:0]), 
        .ce_n    (ctc_ce_n), 
        .iorq_n  (z80_iorq_n),
        .rd_n    (z80_rd_n), 
        .din     (z80_data_from_cpu), 
        .dout    (ctc_dout), 
        .dout_en (ctc_dout_en),
        .clk_trg (ctc_clk_trg), 
        .zc_to   (ctc_zc_to),
        .iei     (ctc_ieo), 
        .ieo     (), 
        .int_n   (raw_ctc_int_n) 
    );

    z80_pio u_pio (
        .clk        (clk_in_5mhz), 
        .m1_n       (z80_m1_n), 
        .ba_sel     (z80_addr), 
        .cd_sel     (z80_addr), 
        .ce_n       (pio_ce_n),
        .iorq_n     (z80_iorq_n), 
        .rd_n       (z80_rd_n), 
        .din        (z80_data_from_cpu), 
        .dout       (pio_dout), 
        .dout_en    (pio_dout_en),
        .port_a_in  (pio_port_a_in), 
        .port_a_out (pio_port_a_out), 
        .port_b_in  (pio_port_b_in), 
        .port_b_out (pio_port_b_out),
        .iei        (1'b1), 
        .ieo        (), 
        .int_n      (raw_pio_int_n) 
    );

endmodule

`default_nettype wire
