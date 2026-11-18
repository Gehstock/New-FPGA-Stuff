module Route16_Top (
    input  wire        clk,
    input  wire        reset,
    input  wire [2:0]  core_mod,
    input  wire [7:0]  dsw,
    input  wire [7:0]  p1_input,
    input  wire [7:0]  p2_input,
    input  wire        ioctl_download,
    input  wire [7:0]  ioctl_index,
    input  wire        ioctl_wr,
    input  wire [24:0] ioctl_addr,
    input  wire [7:0]  ioctl_dout,
    output wire [2:0]  video_r,
    output wire [2:0]  video_g,
    output wire [2:0]  video_b,
    output wire        video_hs,
    output wire        video_vs,
    output wire        video_hb,
    output wire        video_vb,
    output wire [9:0]  audio
);

    reg [5:0] reset_cnt;
    wire      cpu_reset_n = (reset_cnt == 6'd63);

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            reset_cnt <= 6'd0;
        else if (reset_cnt != 6'd63)
            reset_cnt <= reset_cnt + 6'd1;
    end

    reg [2:0] clk_div;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            clk_div <= 3'd0;
        else
            clk_div <= clk_div + 3'd1;
    end

    wire pix_en  = ((clk_div & 3'b001) == 3'b001);
    wire cpu1_en = ((clk_div & 3'b011) == 3'b001);
    wire cpu2_en = ((clk_div & 3'b011) == 3'b011);
    wire ay_en   = (clk_div == 3'b111);

    wire [15:0] cpu1_a;
    wire [7:0]  cpu1_di;
    wire [7:0]  cpu1_do;
    wire        cpu1_mreq_n;
    wire        cpu1_iorq_n;
    wire        cpu1_rd_n;
    wire        cpu1_wr_n;

    wire [7:0]  rom1_raw_q;
    wire [7:0]  shared_ram_q_a;
    wire [7:0]  shared_ram_q_b;
    wire        shared_ram_we_a = ~cpu1_mreq_n && ~cpu1_wr_n && (cpu1_a[15:11] == 5'b01000);
    wire        shared_ram_we_b;

    wire [15:0] cpu2_addr_out;
    wire [7:0]  cpu2_data_out;
    wire [7:0]  cpu2_data_in = shared_ram_q_b;
    wire        cpu2_mreq_n_out;
    wire        cpu2_wr_n_out;

    wire [7:0]  vram1_q_a;
    wire        vram1_we_a = ~cpu1_mreq_n && ~cpu1_wr_n && (cpu1_a[15:14] == 2'b10);

    reg [4:0]   palreg0;
    reg [4:0]   palreg1;
    reg         flipscreen;

    wire ay_write = ~cpu1_iorq_n && ~cpu1_wr_n;
    wire ay_bdir  = ay_write;
    wire ay_bc1   = ay_write && cpu1_a[8:8];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            palreg0      <= 5'd0;
        end else if (~cpu1_mreq_n && ~cpu1_wr_n && (cpu1_a == 16'h4800)) begin
            palreg0      <= cpu1_do[4:0];
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            palreg1    <= 5'd0;
            flipscreen <= 1'b0;
        end else if (~cpu1_mreq_n && ~cpu1_wr_n && (cpu1_a == 16'h5000)) begin
            palreg1    <= cpu1_do[4:0];
            flipscreen <= cpu1_do[5:5];
        end
    end

    reg [7:0] cpu1_in_mux;
    always_comb begin
        if ((core_mod[2:0] == 3'd1) && (cpu1_a == 16'h6400))      cpu1_in_mux = 8'hFB;
        else if ((core_mod[2:0] == 3'd3) && (cpu1_a == 16'h6000)) cpu1_in_mux = 8'h00;
        else if (cpu1_a[15:11] == 5'b01001)                       cpu1_in_mux = dsw;
        else if (cpu1_a[15:11] == 5'b01010)                       cpu1_in_mux = p1_input;
        else if (cpu1_a[15:11] == 5'b01011)                       cpu1_in_mux = p2_input;
        else                                                      cpu1_in_mux = 8'hFF;
    end

    always_comb begin
        if (~cpu1_mreq_n && ~cpu1_rd_n) begin
            if (cpu1_a[15:14] == 2'b00)          cpu1_di = rom1_raw_q;
            else if (cpu1_a[15:11] == 5'b01000)  cpu1_di = shared_ram_q_a;
            else if (cpu1_a[15:14] == 2'b10)     cpu1_di = vram1_q_a;
            else                                 cpu1_di = cpu1_in_mux;
        end else begin
            cpu1_di = 8'hFF;
        end
    end

    reg        vblank_trig_n;
    wire [8:0] v_count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            vblank_trig_n <= 1'b1;
        end else begin
            if (v_count == 9'd240)
                vblank_trig_n <= 1'b0;
            else if (v_count == 9'd255)
                vblank_trig_n <= 1'b1;
        end
    end

    T80se u_cpu1 (
        .RESET_n(cpu_reset_n),
        .CLK_n(clk),
        .CLKEN(cpu1_en),
        .WAIT_n(1'b1),
        .INT_n(vblank_trig_n),
        .NMI_n(1'b1),
        .BUSRQ_n(1'b1),
        .MREQ_n(cpu1_mreq_n),
        .IORQ_n(cpu1_iorq_n),
        .RD_n(cpu1_rd_n),
        .WR_n(cpu1_wr_n),
        .A(cpu1_a),
        .DI(cpu1_di),
        .DO(cpu1_do)
    );

    wire rom1_we = ioctl_download && (ioctl_index == 8'd0) && ioctl_wr && (ioctl_addr[16:14] == 3'b000);

    dpram #(14, 8) u_rom1 (
        .clock_a(clk),
        .enable_a(1'b1),
        .wren_a(rom1_we),
        .address_a(ioctl_addr[13:0]),
        .data_a(ioctl_dout),
        .q_a(),
        .clock_b(clk),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(cpu1_a[13:0]),
        .data_b(8'h00),
        .q_b(rom1_raw_q)
    );

    dpram #(11, 8) u_shared_ram (
        .clock_a(clk),
        .clock_b(clk),
        .enable_a(1'b1),
        .wren_a(shared_ram_we_a),
        .address_a(cpu1_a[10:0]),
        .data_a(cpu1_do),
        .q_a(shared_ram_q_a),
        .enable_b(1'b1),
        .wren_b(shared_ram_we_b),
        .address_b(cpu2_addr_out[10:0]),
        .data_b(cpu2_data_out),
        .q_b(shared_ram_q_b)
    );

    Route16_Video u_video (
        .clk(clk),
        .pix_en(pix_en),
        .cpu_en(cpu2_en),
        .reset(reset),
        .cpu_reset_n(cpu_reset_n),
        .core_mod(core_mod),
        .ioctl_download(ioctl_download),
        .ioctl_index(ioctl_index),
        .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout),
        .palreg0(palreg0),
        .palreg1(palreg1),
        .flipscreen(flipscreen),
        .cpu1_vram_addr(cpu1_a[13:0]),
        .cpu1_vram_data(cpu1_do),
        .cpu1_vram_we(vram1_we_a),
        .cpu1_vram_q(vram1_q_a),
        .cpu2_int_n(vblank_trig_n),
        .cpu2_addr_out(cpu2_addr_out),
        .cpu2_data_out(cpu2_data_out),
        .cpu2_data_in(cpu2_data_in),
        .cpu2_mreq_n_out(cpu2_mreq_n_out),
        .cpu2_wr_n_out(cpu2_wr_n_out),
        .shared_ram_we_b(shared_ram_we_b),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_hs(video_hs),
        .video_vs(video_vs),
        .video_hb(video_hb),
        .video_vb(video_vb),
        .v_count_out(v_count)
    );

    wire dac_we = (core_mod[2:0] >= 3'd2) && ~cpu2_mreq_n_out && ~cpu2_wr_n_out && (cpu2_addr_out == 16'h2800);

    Route16_Audio u_audio (
        .clk(clk),
        .ay_en(ay_en),
        .reset(reset),
        .core_mod(core_mod),
        .bdir(ay_bdir),
        .bc1(ay_bc1),
        .data_in(cpu1_do),
        .dac_data(cpu2_data_out),
        .dac_we(dac_we),
        .audio(audio)
    );

endmodule
