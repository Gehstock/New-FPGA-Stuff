//Gehstock 2026
`timescale 1 ps / 1 ps
`default_nettype none

module ac1_top (
    input  logic        clk_sys,        
    input  logic        clk_sdram,    
    input  logic        rst_n,    
    input  logic [1:0]  system_mode, 
    input  logic        ram_size_mode,
    output logic [15:0] wram_addr,      
    output logic [7:0]  wram_din,       
    input  logic [7:0]  wram_dout,      
    output logic        wram_wren,      
    input  logic        ps2_kbd_clk,    
    input  logic        ps2_kbd_data,   
    output logic        tape_out,      
    input  logic        tape_in,    
    output logic        hsync,          
    output logic        vsync,       
    output logic        hblank,
    output logic        vblank,	 
    output logic        video_out,      
    output logic 			audio_out       
);

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_din;
    logic [7:0]  cpu_dout;    
    logic        m1_n, mreq_n, iorq_n, rd_n, wr_n;
    logic        int_n, nmi_n;
    logic        rom_mon_en;
    logic        rom_basic_en;
    logic        vram_en;
    logic        wram_en;
    logic        pio_ce_n;
    logic        pio2_ce_n;
    logic        ctc_ce_n;
    logic [7:0]  rom16_dout, rom32_dout, rom_scch_dout, basic_dout;
    logic [7:0]  vram_dout;
    logic [7:0]  pio_dout;
    logic [7:0]  pio2_dout;
    logic [7:0]  ctc_dout;
    logic [7:0]  kbd_matrix_data; 
    logic        ctc_ieo;
    logic        pio_ieo;
    logic        pio2_ieo;
    logic        pio_int_n;
    logic        pio2_int_n;
    logic        ctc_int_n;
    logic        pio_tape_out_sig;
    logic        pio_tape_in_sig;
    logic [10:0] vram_video_addr;
    logic [7:0]  vram_video_data;
    logic        pio_b3;

    logic [3:0] clken_acc;
    logic       cpu_clken;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clken_acc <= '0;
            cpu_clken <= 1'b0;
        end else begin
            if (clken_acc >= 4'd11) begin 
                clken_acc <= clken_acc - 4'd12 + 4'd5;
                cpu_clken <= 1'b1;
            end else begin
                clken_acc <= clken_acc + 4'd5;
                cpu_clken <= 1'b0;
            end
        end
    end

    T80se cpu_inst (
        .RESET_n ( rst_n ),
        .CLK_n   ( clk_sys ),   
        .CLKEN   ( cpu_clken ), 
        .WAIT_n  ( 1'b1 ),      
        .INT_n   ( int_n ),
        .NMI_n   ( nmi_n ),     
        .BUSRQ_n ( 1'b1 ),
        .M1_n    ( m1_n ),
        .MREQ_n  ( mreq_n ),
        .IORQ_n  ( iorq_n ),
        .RD_n    ( rd_n ),
        .WR_n    ( wr_n ),
        .A       ( cpu_addr ),
        .DI      ( cpu_din ),
        .DO      ( cpu_dout )
    );

    logic cpm_mode_reg;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cpm_mode_reg <= 1'b0; 
        end else begin
            if (!iorq_n && !wr_n && (cpu_addr[7:0] == 8'h1C)) begin
                cpm_mode_reg <= cpu_dout[0]; 
            end
        end
    end

    always_comb begin
        rom_mon_en   = 1'b0;
        rom_basic_en = 1'b0;
        vram_en      = 1'b0;
        wram_en      = 1'b1;        
        if (system_mode == 2'd3) begin
            if (cpu_addr[15:12] == 4'b0000 && !cpm_mode_reg) begin
                rom_mon_en = 1'b1; 
                wram_en    = 1'b0;
            end
            else if (cpu_addr[15:11] == 5'b00010) begin
                vram_en    = 1'b1;
                wram_en    = 1'b0;
            end
        end else begin
            if (cpu_addr[15:11] == 5'b00000 && !cpm_mode_reg) begin
                rom_mon_en = 1'b1;   
                wram_en    = 1'b0;
            end
            else if (cpu_addr[15:11] == 5'b00001) begin
                rom_basic_en = 1'b1; 
                wram_en      = 1'b0;
            end
            else if (cpu_addr[15:11] == 5'b00010) begin
                vram_en      = 1'b1;      
                wram_en      = 1'b0;
            end
            if (ram_size_mode == 1'b0 && cpu_addr[15:13] != 3'b000) begin
                wram_en = 1'b0;
            end
        end
    end

    monitor16_rom monitor16_rom_inst (
        .clk         ( clk_sys ),
        .addr        ( cpu_addr[10:0] ),
        .data        ( rom16_dout )
    );
	 
    monitor32_rom monitor32_rom_inst (
        .clk         ( clk_sys ),
        .addr        ( cpu_addr[10:0] ),
        .data        ( rom32_dout )
    );

    monitor_scch_rom monitor_scch_rom_inst (
        .clk         ( clk_sys ),
        .addr        ( cpu_addr[11:0] ), 
        .data        ( rom_scch_dout ) 
    );
	 
    basic_rom basic_rom_inst (
        .clk         ( clk_sys ),
        .addr        ( cpu_addr[10:0] ),
        .data        ( basic_dout )
    );

    dpram #(
        .address_width(11), 
        .data_width(8)
    ) video_ram_inst (
        .clock(clk_sys), 
        .enable_a(vram_en), 
        .wren_a(!wr_n && !mreq_n && cpu_clken), 
        .address_a(cpu_addr[10:0]), 
        .data_a(cpu_dout), 
        .q_a(vram_dout),
        .enable_b(1'b1), 
        .wren_b(1'b0), 
        .address_b(vram_video_addr), 
        .data_b(8'h00), 
        .q_b(vram_video_data)
    );
    
	     assign wram_addr = cpu_addr;
    assign wram_din  = cpu_dout;
    assign wram_wren = (wram_en && !wr_n && !mreq_n && cpu_clken) ? 1'b1 : 1'b0;

    ac1_keyboard kbd_inst (
        .clk          ( clk_sdram ),
        .rst_n        ( rst_n ),
        .ps2_kbd_clk  ( ps2_kbd_clk ),
        .ps2_kbd_data ( ps2_kbd_data ),
        .ascii_out    ( kbd_matrix_data ),
        .nmi_n        ( nmi_n )
    );

    ac1_video video_inst (
        .clk_pixel     ( clk_sys ),
        .rst_n       ( rst_n ),
        .system_mode ( system_mode ), 
        .vram_addr   ( vram_video_addr ),
        .vram_data   ( vram_video_data ),
        .hsync       ( hsync ),
        .vsync       ( vsync ),
        .hblank      ( hblank ),
        .vblank      ( vblank ),
        .video_out   ( video_out )
    );

    ac1_cassette_io cassette_inst (
        .clk          ( clk_sys ),
        .rst_n        ( rst_n ),
        .tape_in_p    ( tape_in ),
        .tape_out_p   ( tape_out ),
        .pio_tape_out ( pio_tape_out_sig ),
        .pio_tape_in  ( pio_tape_in_sig )
    );

    logic [7:0] pio_port_a_in;
    logic [7:0] pio_port_a_out;
    logic [7:0] pio_port_b_in;
    logic [7:0] pio_port_b_out;
    
    assign pio_port_a_in    = kbd_matrix_data; 
    assign pio_tape_out_sig = pio_port_b_out[6]; 
    assign pio_b3           = pio_port_b_out[3]; 	 
    assign pio_port_b_in    = {pio_tape_in_sig, 7'b0000000}; 

    assign ctc_ce_n  = (!iorq_n && (cpu_addr[7:2] == 6'b000000)) ? 1'b0 : 1'b1;
    assign pio_ce_n  = (!iorq_n && (cpu_addr[7:2] == 6'b000001)) ? 1'b0 : 1'b1;
    assign pio2_ce_n = (!iorq_n && (system_mode == 2'd3) && (cpu_addr[7:2] == 6'b000010)) ? 1'b0 : 1'b1;

    z80_ctc ctc_inst (
        .clk        ( clk_sys ),
        .clken      ( cpu_clken ), 
        .reset_n    ( rst_n ),
        .cs         ( cpu_addr[1:0] ),
        .ce_n       ( ctc_ce_n ),
        .iorq_n     ( iorq_n ),
        .rd_n       ( rd_n ),
        .din        ( cpu_dout ),
        .dout       ( ctc_dout ),
        .dout_en    ( ),
        .clk_trg    ( 4'b0000 ),
        .zc_to      ( ),
        .iei        ( 1'b1 ),
        .ieo        ( ctc_ieo ),
        .int_n      ( ctc_int_n )
    );

    z80_pio pio_inst (
        .clk        ( clk_sys ),
        .clken      ( cpu_clken ), 
        .m1_n       ( m1_n ),
        .ba_sel     ( cpu_addr[0] ),
        .cd_sel     ( cpu_addr[1] ),
        .ce_n       ( pio_ce_n ),
        .iorq_n     ( iorq_n ),
        .rd_n       ( rd_n ),
        .din        ( cpu_dout ),
        .dout       ( pio_dout ),
        .dout_en    ( ),
        .port_a_in  ( pio_port_a_in ),
        .port_a_out ( pio_port_a_out ),
        .port_b_in  ( pio_port_b_in ),
        .port_b_out ( pio_port_b_out ),
        .iei        ( ctc_ieo ),
        .ieo        ( pio_ieo ),
        .int_n      ( pio_int_n )
    );

    z80_pio pio2_inst (
        .clk        ( clk_sys ),
        .clken      ( cpu_clken ), 
        .m1_n       ( m1_n ),
        .ba_sel     ( cpu_addr[0] ),
        .cd_sel     ( cpu_addr[1] ),
        .ce_n       ( pio2_ce_n ),
        .iorq_n     ( iorq_n ),
        .rd_n       ( rd_n ),
        .din        ( cpu_dout ),
        .dout       ( pio2_dout ),
        .dout_en    ( ),
        .port_a_in  ( 8'h00 ), 
        .port_a_out ( ),
        .port_b_in  ( 8'h00 ),
        .port_b_out ( ),
        .iei        ( pio_ieo ),
        .ieo        ( pio2_ieo ),
        .int_n      ( pio2_int_n )
    );
	 
    assign int_n = (ctc_int_n && pio_int_n && pio2_int_n) ? 1'b1 : 1'b0;
    assign audio_out = pio_port_b_out[0] ? 16'h7FFF : 16'h8000;


    always_comb begin
        cpu_din = 8'hFF;
        if (!iorq_n && !m1_n) begin
            if (!ctc_ce_n)       cpu_din = ctc_dout;
            else if (!pio_ce_n)  cpu_din = pio_dout; 
            else if (!pio2_ce_n) cpu_din = pio2_dout;
        end 
        else if (!rd_n) begin
            if (!mreq_n) begin
                if (rom_mon_en) begin
                    case (system_mode)
                        2'd1, 2'd2:    cpu_din = rom32_dout;
                        2'd3:          cpu_din = rom_scch_dout;
                        default:       cpu_din = rom16_dout; 
                    endcase
                end
                else if (rom_basic_en) cpu_din = basic_dout;
                else if (vram_en)      cpu_din = vram_dout;
                else if (wram_en)      cpu_din = wram_dout; 
            end 
            else if (!iorq_n) begin
                if      (!ctc_ce_n)  cpu_din = ctc_dout;
                else if (!pio_ce_n)  cpu_din = pio_dout;
                else if (!pio2_ce_n) cpu_din = pio2_dout;
            end
        end
    end

endmodule
`default_nettype wire
