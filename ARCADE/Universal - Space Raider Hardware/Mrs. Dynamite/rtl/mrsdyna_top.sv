module mrsdyna_top (
    input  wire        clk_sys,
    input  wire        rst_n,
    output wire        clkref,
    input  wire [7:0]  in0_i,
    input  wire [7:0]  in1_i,
    input  wire [7:0]  dsw0_i,
    input  wire [7:0]  dsw1_i,
    output wire [1:0]  video_r,
    output wire [1:0]  video_g,
    output wire [1:0]  video_b,
    output wire        video_hsync,
    output wire        video_vsync,
    output wire        video_vblank,
    output wire        video_hblank,
    output wire [14:0] cpu1_rom_addr,
    input  wire [7:0]  cpu1_rom_q,
    input  wire        cpu1_rom_valid,
    output wire [14:0] cpu2_rom_addr,
    input  wire [7:0]  cpu2_rom_q,
    input  wire        cpu2_rom_valid,
    output wire [13:0] audio_o
);

    reg [2:0] clk_div;
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) 
            clk_div <= 3'd0;
        else        
            clk_div <= clk_div + 1'b1;
    end

    wire clk_en_10mhz   = (clk_div == 3'b000 || clk_div == 3'b010 || clk_div == 3'b100 || clk_div == 3'b110);
    wire clk_en_10mhz_n = (clk_div == 3'b001 || clk_div == 3'b011 || clk_div == 3'b101 || clk_div == 3'b111);
    wire clk_en_5mhz    = (clk_div[1:0] == 2'b00);
    wire clk_en_5mhz_n  = (clk_div[1:0] == 2'b10);

    reg  [2:0] clk_div5;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            clk_div5 <= 3'd0;
        else
            clk_div5 <= (clk_div5 == 3'd4) ? 3'd0 : clk_div5 + 1'b1;
    end
    wire clk_en_4mhz    = (clk_div5 == 3'd0);

    assign clkref = clk_en_4mhz;

    wire vbl_s;
    reg  vbl_d;
    reg  cpu1_int_n, cpu2_int_n;
    wire cpu1_m1_n, cpu2_m1_n;
    wire cpu1_rfsh_n, cpu2_rfsh_n;

    reg [7:0] soundlatch_low;
    reg [7:0] soundlatch_high;

    wire [15:0] cpu1_addr;
    wire [7:0]  cpu1_data_out, d_from_video;
    reg  [7:0]  cpu1_data_in;
    wire        cpu1_mreq_n, cpu1_iorq_n, cpu1_rd_n, cpu1_wr_n;
    wire        video_wait_n;
    reg  cpu1_rom_wait_n;
    wire cpu1_wait_n = video_wait_n & cpu1_rom_wait_n;

    T80se #(.Mode(0), .T2Write(1), .IOWait(1)) cpu1_main (
        .RESET_n(rst_n), 
        .CLK_n(clk_sys), 
        .CLKEN(clk_en_4mhz),
        .WAIT_n(cpu1_wait_n),
        .INT_n(cpu1_int_n), 
        .NMI_n(1'b1), 
        .BUSRQ_n(1'b1),
        .M1_n(cpu1_m1_n),
        .RFSH_n(cpu1_rfsh_n),
        .A(cpu1_addr), 
        .DI(cpu1_data_in), 
        .DO(cpu1_data_out),
        .MREQ_n(cpu1_mreq_n), 
        .IORQ_n(cpu1_iorq_n), 
        .RD_n(cpu1_rd_n), 
        .WR_n(cpu1_wr_n)
    );
    
    wire cpu1_rom_en = ~cpu1_mreq_n && (cpu1_addr <= 16'h5FFF);
    wire cpu1_ram_en = ~cpu1_mreq_n && (cpu1_addr >= 16'h6000 && cpu1_addr <= 16'h6FFF);
    
    wire cs7_n  = ~(~cpu1_mreq_n && (cpu1_addr >= 16'h7000 && cpu1_addr <= 16'h73FF)); 
    wire cs13_n = ~(~cpu1_mreq_n && (cpu1_addr >= 16'hd000 && cpu1_addr <= 16'hd7ff)); 
    wire cs10_n = ~(~cpu1_mreq_n && (cpu1_addr >= 16'hD800 && cpu1_addr <= 16'hDBFF));

    wire cpu1_io_area = ~cpu1_mreq_n && (cpu1_addr[15:13] == 3'b100); 
    wire is_protection_addr = ~cpu1_mreq_n && (cpu1_addr[15:13] == 3'b100) && (cpu1_addr[2:0] == 3'b101);

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            soundlatch_low  <= 8'h00;
            soundlatch_high <= 8'h00;
        end else if (clk_en_4mhz && cpu1_io_area && ~cpu1_wr_n) begin
            if (cpu1_addr[2:0] == 3'd6) soundlatch_low  <= cpu1_data_out; 
            if (cpu1_addr[2:0] == 3'd7) soundlatch_high <= cpu1_data_out; 
        end
    end

    always @(*) begin
        if (cpu1_rom_en) begin
            cpu1_data_in = cpu1_rom_q;
        end else if (cpu1_ram_en) begin
            cpu1_data_in = cpu1_ram_q;
        end else if (cpu1_io_area) begin
            if (is_protection_addr) begin
                cpu1_data_in = 8'h3E;
            end else begin
                case (cpu1_addr[2:0])
                    3'd0:    cpu1_data_in = in0_i;
                    3'd1:    cpu1_data_in = in1_i;
                    3'd2:    cpu1_data_in = dsw0_i;
                    3'd3:    cpu1_data_in = dsw1_i;
                    default: cpu1_data_in = 8'hFF;
                endcase
            end
        end else if (~cs13_n || ~cs10_n || ~cs7_n) begin 
            cpu1_data_in = d_from_video;
        end else begin
            cpu1_data_in = 8'hFF;
        end
    end

    wire [7:0] cpu1_ram_q;
    wire        cpu1_rom_range = ~cpu1_addr[15] & ~(cpu1_addr[14] & cpu1_addr[13]); // 0000-5FFF
    reg  [14:0] cpu1_rom_addr_r;
    assign cpu1_rom_addr = (cpu1_rfsh_n & cpu1_rom_range) ? cpu1_addr[14:0] : cpu1_rom_addr_r;
    always @(posedge clk_sys) cpu1_rom_addr_r <= cpu1_rom_addr;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) cpu1_rom_wait_n <= 1'b1;
        else        cpu1_rom_wait_n <= ~(cpu1_rom_en & ~cpu1_rd_n) | cpu1_rom_valid;
    end

    spram #(12,8) ram1 (
        .clock  (clk_sys),
        .enable (1'b1),
        .address(cpu1_addr[11:0]),
        .data   (cpu1_data_out),
        .wren   (cpu1_ram_en & ~cpu1_wr_n & clk_en_4mhz),
        .q      (cpu1_ram_q)
    );

	 
    wire [15:0] cpu2_addr;
    wire [7:0]  cpu2_data_out;
    reg  [7:0]  cpu2_data_in;
    wire        cpu2_mreq_n, cpu2_iorq_n, cpu2_rd_n, cpu2_wr_n;
    reg         vblank_reg_prev;

    reg cpu2_rom_wait_n;
    wire snd_ready;

    T80se #(.Mode(0), .T2Write(1), .IOWait(1)) cpu2_sub (
        .RESET_n(rst_n), 
        .CLK_n(clk_sys), 
        .CLKEN(clk_en_4mhz),
        .WAIT_n(cpu2_rom_wait_n & snd_ready),
        .INT_n(cpu2_int_n), 
        .NMI_n(1'b1), 
        .BUSRQ_n(1'b1),
        .M1_n(cpu2_m1_n),
        .RFSH_n(cpu2_rfsh_n),
        .A(cpu2_addr), 
        .DI(cpu2_data_in), 
        .DO(cpu2_data_out),
        .MREQ_n(cpu2_mreq_n), 
        .IORQ_n(cpu2_iorq_n), 
        .RD_n(cpu2_rd_n), 
        .WR_n(cpu2_wr_n)
    );

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            vbl_d      <= 1'b0;
            cpu1_int_n <= 1'b1;
            cpu2_int_n <= 1'b1;
        end else begin
            vbl_d <= vbl_s;
            if (vbl_s & ~vbl_d) begin
                cpu1_int_n <= 1'b0;
                cpu2_int_n <= 1'b0;
            end
            if (~cpu1_m1_n & ~cpu1_iorq_n) cpu1_int_n <= 1'b1;
            if (~cpu2_m1_n & ~cpu2_iorq_n) cpu2_int_n <= 1'b1;
        end
    end

    wire cpu2_rom_en = ~cpu2_mreq_n && (cpu2_addr <= 16'h5FFF);
    wire cpu2_ram_en = ~cpu2_mreq_n && (cpu2_addr >= 16'h6000 && cpu2_addr <= 16'h67FF);
//    wire io_w_reg_we = ~cpu2_mreq_n && ~cpu2_wr_n && (cpu2_addr >= 16'hE800 && cpu2_addr <= 16'hEFFF);
    


    reg [1:0] rnd_counter;
    always @(posedge clk_sys) begin
        if (clk_en_4mhz) rnd_counter <= rnd_counter + 1'b1;
    end

    wire cpu2_latch_low_en  = ~cpu2_mreq_n && (cpu2_addr >= 16'h8000 && cpu2_addr <= 16'h9FFF); 
    wire cpu2_latch_high_en = ~cpu2_mreq_n && (cpu2_addr >= 16'hA000 && cpu2_addr <= 16'hBFFF); 
    wire cpu2_random_en     = ~cpu2_mreq_n && (cpu2_addr >= 16'hC000 && cpu2_addr <= 16'hDFFF); 

    always @(*) begin
        if (cpu2_rom_en) begin
            cpu2_data_in = cpu2_rom_q;
        end else if (cpu2_ram_en) begin
            cpu2_data_in = cpu2_ram_q;
        end else if (cpu2_latch_low_en) begin
            cpu2_data_in = soundlatch_low;
        end else if (cpu2_latch_high_en) begin
            cpu2_data_in = soundlatch_high;
        end else if (cpu2_random_en) begin
            cpu2_data_in = {6'b000000, rnd_counter};
        end else begin
            cpu2_data_in = 8'hFF;
        end
    end

    wire [7:0] cpu2_ram_q;
    wire        cpu2_rom_range = ~cpu2_addr[15] & ~(cpu2_addr[14] & cpu2_addr[13]); // 0000-5FFF
    reg  [14:0] cpu2_rom_addr_r;
    assign cpu2_rom_addr = (cpu2_rfsh_n & cpu2_rom_range) ? cpu2_addr[14:0] : cpu2_rom_addr_r;
    always @(posedge clk_sys) cpu2_rom_addr_r <= cpu2_rom_addr;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) cpu2_rom_wait_n <= 1'b1;
        else        cpu2_rom_wait_n <= ~(cpu2_rom_en & ~cpu2_rd_n) | cpu2_rom_valid;
    end
	 
    spram #(10,8) ram2 (
        .clock  (clk_sys),
        .enable (1'b1),
        .address(cpu2_addr[9:0]),
        .data   (cpu2_data_out),
        .wren   (cpu2_ram_en & ~cpu2_wr_n & clk_en_4mhz),
        .q      (cpu2_ram_q)
    );

    mrsdyna_video video (
        .clk_20mhz_i(clk_sys),
        .por_n_i(rst_n),
        .res_n_i(rst_n),
        .clk_en_10mhz_i(clk_en_10mhz),
        .clk_en_10mhz_n_i(clk_en_10mhz_n),
        .clk_en_5mhz_i(clk_en_5mhz),
        .clk_en_5mhz_n_i(clk_en_5mhz_n),
        .clk_en_4mhz_i(clk_en_4mhz),
        .cs7_n_i(cs7_n),
        .cs10_n_i(cs10_n),
        .cs13_n_i(cs13_n),
        .a_i(cpu1_addr[10:0]),
        .rd_n_i(cpu1_rd_n),
        .wr_n_i(cpu1_wr_n),
        .wait_n_o(video_wait_n),
        .d_from_cpu_i(cpu1_data_out),
        .d_from_video_o(d_from_video),
        .vbl_buf_o(vbl_s),
//        .stars_enable_i(stars_enable),
//        .stars_speed_i(stars_speed),
//        .grid_color_reg_i(grid_color_reg),
//        .grid_ram_we_i(grid_ram_we),
//        .grid_ram_addr_i(cpu2_addr[7:0]),
//        .cpu2_data_i(cpu2_data_out),
        .rgb_r_o(video_r),
        .rgb_g_o(video_g),
        .rgb_b_o(video_b),
        .hsync_n_o(video_hsync),
        .vsync_n_o(video_vsync),
        .vblank_o(video_vblank),
        .hblank_o(video_hblank)
//        .flip_screen_signal(flip_screen_reg)	  
    );

    mrsdyna_audio audio (
        .clk_20mhz_i(clk_sys),
        .clk_en_4mhz_i(clk_en_4mhz),
        .por_n_i(rst_n),
        .cpu2_iorq_i(~cpu2_iorq_n),
        .cpu2_wr_i(~cpu2_wr_n),
        .cpu2_addr_i(cpu2_addr[7:0]),
        .d_from_cpu_i(cpu2_data_out),
        .audio_o(audio_o),
        .ready_o(snd_ready)
    );


endmodule
