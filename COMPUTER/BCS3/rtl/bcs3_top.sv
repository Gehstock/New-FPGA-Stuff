//Gehstock 2026
`timescale 1 ps / 1 ps
`default_nettype none

module bcs3_top (
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
    output logic        video_out,
    output logic        DBG
);

    assign DBG = z80_rd_n;

    logic clk_div_reg;
    logic cpu_clken;

    always_ff @(posedge clk_in_5mhz or negedge reset_n) begin
        if (!reset_n) begin
            clk_div_reg <= 1'b0;
            cpu_clken   <= 1'b0;
        end else begin
            clk_div_reg <= ~clk_div_reg;
            cpu_clken   <= !clk_div_reg; 
        end
    end

    logic        z80_m1_n, z80_mreq_n, z80_iorq_n, z80_rd_n, z80_wr_n, z80_rfsh_n;
    logic        z80_int_n; 
    logic [15:0] z80_addr; 
    logic [7:0]  z80_data_to_cpu, z80_data_from_cpu;   
    logic        w_video_wait_n; 
    logic        z80_wait_n, NMI_n;
    assign z80_wait_n = 1'b1; 

    logic ctc_ieo;
    logic raw_ctc_int_n; 
    logic raw_pio_int_n;   
    logic daisy_ctc_int_n; 
    logic daisy_pio_int_n; 
    assign z80_int_n = daisy_ctc_int_n & daisy_pio_int_n;

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

    logic rom_ce, kbd_ce, video_r_ce, video_ram_ce;
    logic internal_bram_ce;
    logic pio_ce_n, ctc_ce_n;
    
    logic ram_size_mode;
    assign ram_size_mode = 1'b0; 

    logic [15:0] effective_addr;
    assign effective_addr = {z80_addr[15:14], 1'b0, z80_addr[12:0]};

    always_comb begin
        rom_ce           = 1'b0; 
        kbd_ce           = 1'b0; 
        video_r_ce       = 1'b0; 
        video_ram_ce     = 1'b0;
        internal_bram_ce = 1'b0;
        
        if (!z80_mreq_n && z80_rfsh_n) begin 
            if (effective_addr <= 16'h0FFF) begin
                rom_ce = 1'b1; 
            end else if (effective_addr >= 16'h1000 && effective_addr <= 16'h13FF) begin
                kbd_ce = 1'b1; 
            end else if (effective_addr >= 16'h1800 && effective_addr <= 16'h1BFF) begin
                video_r_ce = 1'b1; 
            end else if (effective_addr >= 16'h1C00 && effective_addr <= 16'h1FFF) begin
                video_ram_ce = 1'b1; 
            end else begin
                if (ram_size_mode == 1'b0) begin
                    internal_bram_ce = 1'b1;
                end
            end
        end
    end

    always_comb begin
        pio_ce_n = 1'b1; 
        ctc_ce_n = 1'b1; 
        if (!z80_iorq_n && z80_m1_n) begin
            if (z80_addr[7:2] == 6'b000000)      pio_ce_n = 1'b0; 
            else if (z80_addr[7:2] == 6'b000001) ctc_ce_n = 1'b0; 
        end
    end

    logic [7:0] rom_q, kbd_q, video_ram_q, video_data, ctc_dout, pio_dout, bram_q;
    logic       ctc_dout_en, pio_dout_en;

    always_comb begin
        z80_data_to_cpu = 8'hFF; 
        
        if (!z80_rd_n) begin
            if (!z80_mreq_n) begin
                if (rom_ce)                z80_data_to_cpu = rom_q;
                else if (kbd_ce)           z80_data_to_cpu = kbd_q;     
                else if (video_ram_ce)     z80_data_to_cpu = video_ram_q;
                else if (video_r_ce)       z80_data_to_cpu = video_data; 
                else if (internal_bram_ce) z80_data_to_cpu = bram_q;
            end else if (!z80_iorq_n && z80_m1_n) begin
                if (!ctc_ce_n && ctc_dout_en) z80_data_to_cpu = ctc_dout;
                if (!pio_ce_n && pio_dout_en) z80_data_to_cpu = pio_dout;
            end
        end
    end

    spram #(
        .address_width(12), .data_width(8)
    ) u_internal_bram (
        .clock     (clk_in_5mhz),
        .enable  (internal_bram_ce),
        .wren    (!z80_wr_n),
        .address (z80_addr[11:0]),
        .data    (z80_data_from_cpu),
        .q       (bram_q)
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
     
    SE24_rom u_SE24_rom (
        .clk  (clk_in_5mhz),
        .addr (z80_addr[10:0]), 
        .data (rom_q)
    );

    bcs3_keyboard_sys u_keyboard (
        .clk          (clk_in_5mhz),
        .rst_n        (reset_n),
        .addr_offset  (z80_addr[9:0]),
        .rd_n         (z80_rd_n || !kbd_ce),
        .data_out     (kbd_q),
        .cassette_in  (cassette_in),
        .ps2_kbd_clk  (ps2_kbd_clk),    
        .ps2_kbd_data (ps2_kbd_data),
        .NMI_n			 (NMI_n)		  
    );

    bcs3_video u_video (
        .clk_sys        (clk_in_5mhz), 
        .reset_n        (reset_n), 
        .video_ce       (video_ram_ce), 
        .video_wr       (!z80_wr_n),
        .video_addr     (z80_addr[11:0]), 
        .video_data_in  (z80_data_from_cpu), 
        .video_data_out (video_ram_q),
        .video_wait_n   (w_video_wait_n), 
        .video_r_ce     (video_r_ce),    
        .zx_n_ce        (1'b0),          
        .hack_bus_data  (video_data),
        .hsync          (hsync), 
        .vsync          (vsync), 
        .hblank         (hblank),
        .vblank         (vblank),
        .video_out      (video_out)
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
        .iei     (1'b1),               
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

endmodule
`default_nettype wire

