`timescale 1ns / 1ps

module Ambush_Top (
    input  logic        clk_sys,         
    input  logic        reset,
    
    input  logic [7:0]  BUTTONS,
    input  logic [7:0]  JOYSTICK,
    input  logic [7:0]  SW1,
    
    output logic        hsync,
    output logic        vsync,
    output logic        hblank,
    output logic        vblank,
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b,
    output logic [8:0] audio
);

    logic [1:0] video_clk_div;
    logic       cen_video;

    assign cen_video = (video_clk_div == 2'd2);

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            video_clk_div <= 2'd0;
        end else if (video_clk_div == 2'd2) begin
            video_clk_div <= 2'd0;
        end else begin
            video_clk_div <= video_clk_div + 2'd1;
        end
    end

    logic [2:0] cpu_clk_div;
    logic       cen_cpu;

    assign cen_cpu = (cpu_clk_div == 3'd5);

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            cpu_clk_div <= 3'd0;
        end else if (cpu_clk_div == 3'd5) begin
            cpu_clk_div <= 3'd0;
        end else begin
            cpu_clk_div <= cpu_clk_div + 3'd1;
        end
    end

    logic [15:0] cpu_addr;
    logic [7:0]  cpu_data_out;
    logic [7:0]  cpu_data_in;
    logic        cpu_mreq_n;
    logic        cpu_iorq_n;
	 logic        cpu_rd_n;
    logic        cpu_wr_n;
    logic        cpu_m1_n;
    logic        int_n;

    T80se cpu_core (
        .RESET_n ( ~reset ),
        .CLK_n   ( clk_sys ),
        .CLKEN   ( cen_cpu ),
        .WAIT_n  ( 1'b1 ),
        .INT_n   ( int_n ),
        .NMI_n   ( 1'b1 ),
        .BUSRQ_n ( 1'b1 ),
        .M1_n    ( cpu_m1_n ),
        .MREQ_n  ( cpu_mreq_n ),
        .IORQ_n  ( cpu_iorq_n ),
        .RD_n    ( cpu_rd_n ),
        .WR_n    ( cpu_wr_n ),
        .RFSH_n  (),
        .HALT_n  (),
        .BUSAK_n (),
        .A       ( cpu_addr ),
        .DI      ( cpu_data_in ),
        .DO      ( cpu_data_out )
    );

    logic mem_access;
    logic mem_write;
    logic io_access;
    logic io_write;
    logic io_read;

    assign mem_access = ~cpu_mreq_n;
    assign mem_write  = ~cpu_wr_n && mem_access;
    assign io_access = ~cpu_iorq_n && cpu_m1_n;
    assign io_write  = io_access && ~cpu_wr_n;
    assign io_read   = io_access && ~cpu_rd_n;

    logic rom_en;
    logic wram_en;
    logic scroll_en;
    logic attr_en;
    logic sprite_en;
    logic vram_en;
    logic sw1_en;
    logic latch_en;

    assign rom_en     = mem_access && (cpu_addr >= 16'h0000 && cpu_addr <= 16'h7FFF);
    assign wram_en    = mem_access && (cpu_addr >= 16'h8000 && cpu_addr <= 16'h87FF);
    assign scroll_en  = mem_access && (cpu_addr >= 16'hC080 && cpu_addr <= 16'hC09F);
    assign attr_en    = mem_access && (cpu_addr >= 16'hC100 && cpu_addr <= 16'hC1FF);
    assign sprite_en  = mem_access && (cpu_addr >= 16'hC200 && cpu_addr <= 16'hC3FF);
    assign vram_en    = mem_access && (cpu_addr >= 16'hC400 && cpu_addr <= 16'hC7FF);
    assign sw1_en     = mem_access && (cpu_addr == 16'hC800);
    assign latch_en   = mem_access && (cpu_addr >= 16'hCC00 && cpu_addr <= 16'hCC07);

    logic [7:0] rom_q;
    logic [7:0] wram_q;
    logic [7:0] vram_cpu_q;
    logic [7:0] sprite_cpu_q;
    logic [7:0] attr_cpu_q;
    logic [7:0] scroll_cpu_q;
    logic [7:0] audio_io_q;

    logic watchdog_en;
    assign watchdog_en = mem_access && (cpu_addr == 16'hA000);

    always_comb begin
        cpu_data_in = 8'hFF;
        if (io_access) begin
            cpu_data_in = audio_io_q;
        end else begin
            if (rom_en)         cpu_data_in = rom_q;
            else if (wram_en)   cpu_data_in = wram_q;
            else if (vram_en)   cpu_data_in = vram_cpu_q;
            else if (sprite_en) cpu_data_in = sprite_cpu_q;
            else if (attr_en)   cpu_data_in = attr_cpu_q;
            else if (scroll_en) cpu_data_in = scroll_cpu_q;
            else if (sw1_en)    cpu_data_in = SW1;
            else if (watchdog_en) cpu_data_in = 8'h00;
        end
    end


logic [7:0] rom_cpu1_q;
    logic [7:0] rom_cpu2_q;
    logic [7:0] rom_cpu3_q;
    logic [7:0] rom_cpu4_q;

    rom_cpu1 u_rom_cpu1 (
        .clk  ( clk_sys ),
        .addr ( cpu_addr[12:0] ),
        .data ( rom_cpu1_q )
    );

    rom_cpu2 u_rom_cpu2 (
        .clk  ( clk_sys ),
        .addr ( cpu_addr[12:0] ),
        .data ( rom_cpu2_q )
    );

    rom_cpu3 u_rom_cpu3 (
        .clk  ( clk_sys ),
        .addr ( cpu_addr[12:0] ),
        .data ( rom_cpu3_q )
    );

    rom_cpu4 u_rom_cpu4 (
        .clk  ( clk_sys ),
        .addr ( cpu_addr[12:0] ),
        .data ( rom_cpu4_q )
    );
	 
    always_comb begin
        case (cpu_addr[14:13])
            2'b00:   rom_q = rom_cpu1_q;
            2'b01:   rom_q = rom_cpu2_q;
            2'b10:   rom_q = rom_cpu3_q;
            default: rom_q = rom_cpu4_q;
        endcase
    end	 

    spram #(
        .address_width(11), 
        .data_width(8)
    ) work_ram (
        .clock   ( clk_sys ), 
        .enable  ( wram_en ), 
        .address ( cpu_addr[10:0] ), 
        .data    ( cpu_data_out ), 
        .wren    ( mem_write && wram_en ), 
        .q       ( wram_q )
    );

    logic outlatch_0_bit4;
    logic outlatch_0_bit5;
    logic outlatch_1_bit5;
    logic outlatch_1_bit7;
    logic [2:0] latch_bit;
    
    assign latch_bit = cpu_addr[2:0];

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            outlatch_0_bit4 <= 1'b0;
            outlatch_0_bit5 <= 1'b0;
            outlatch_1_bit5 <= 1'b0;
            outlatch_1_bit7 <= 1'b0;
        end else if (mem_write && latch_en) begin
            if (latch_bit == 3'd4) outlatch_0_bit4 <= cpu_data_out[0];
            if (latch_bit == 3'd5) begin
                outlatch_0_bit5 <= cpu_data_out[0];
                outlatch_1_bit5 <= cpu_data_out[0];
            end
            if (latch_bit == 3'd7) outlatch_1_bit7 <= cpu_data_out[0];
        end
    end

    logic [1:0] color_bank;
    assign color_bank = {outlatch_1_bit5, outlatch_0_bit5};


    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            int_n <= 1'b1;
        end else begin
            if (vblank) begin
                int_n <= 1'b0;
            end else if (mem_write && latch_en) begin
                int_n <= 1'b1;
            end else if (io_access) begin
                int_n <= 1'b1;
            end
        end
    end

    Ambush_Audio audio_system (
        .clk_sys     ( clk_sys ),
        .reset       ( reset ),
        .io_en       ( io_access ),
        .io_write    ( io_write ),
        .io_read     ( io_read ),
        .io_addr     ( cpu_addr[7:0] ),
        .io_data_in  ( cpu_data_out ),
        .io_data_out ( audio_io_q ),
        .I_BUTTONS   ( BUTTONS ),
        .I_JOYSTICK  ( JOYSTICK ),
        .audio  		( audio )
    );

    Ambush_Video video_system (
        .clk_sys             ( clk_sys ),
        .cen_video           ( cen_video ),
        .reset               ( reset ),
        .color_bank          ( color_bank ),
        .vram_cpu_enable     ( vram_en ),
        .vram_cpu_wren       ( mem_write && vram_en ),
        .vram_cpu_addr       ( cpu_addr[9:0] ),
        .vram_cpu_data_in    ( cpu_data_out ),
        .vram_cpu_data_out   ( vram_cpu_q ),
        .sprite_cpu_enable   ( sprite_en ),
        .sprite_cpu_wren     ( mem_write && sprite_en ),
        .sprite_cpu_addr     ( cpu_addr[8:0] ),
        .sprite_cpu_data_in  ( cpu_data_out ),
        .sprite_cpu_data_out ( sprite_cpu_q ),
        .attr_cpu_enable     ( attr_en ),
        .attr_cpu_wren       ( mem_write && attr_en ),
        .attr_cpu_addr       ( cpu_addr[7:0] ),
        .attr_cpu_data_in    ( cpu_data_out ),
        .attr_cpu_data_out   ( attr_cpu_q ),
        .scroll_cpu_enable   ( scroll_en ),
        .scroll_cpu_wren     ( mem_write && scroll_en ),
        .scroll_cpu_addr     ( cpu_addr[4:0] ),
        .scroll_cpu_data_in  ( cpu_data_out ),
        .scroll_cpu_data_out ( scroll_cpu_q ),
        .hsync               ( hsync ),
        .vsync               ( vsync ),
        .hblank              ( hblank ),
        .vblank              ( vblank ),
        .video_r             ( video_r ),
        .video_g             ( video_g ),
        .video_b             ( video_b )
    );

    logic internal_dummy;
    assign internal_dummy = outlatch_0_bit4 & outlatch_1_bit7;

endmodule
