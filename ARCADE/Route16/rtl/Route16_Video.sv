module Route16_Video (
    input  wire        clk,
    input  wire        pix_en,
    input  wire        cpu_en,
    input  wire        reset,
    input  wire        cpu_reset_n,
    input  wire [2:0]  core_mod,
    input  wire        ioctl_download,
    input  wire [7:0]  ioctl_index,
    input  wire        ioctl_wr,
    input  wire [24:0] ioctl_addr,
    input  wire [7:0]  ioctl_dout,
    input  wire [4:0]  palreg0,
    input  wire [4:0]  palreg1,
    input  wire        flipscreen,
    input  wire [13:0] cpu1_vram_addr,
    input  wire [7:0]  cpu1_vram_data,
    input  wire        cpu1_vram_we,
    output wire [7:0]  cpu1_vram_q,
    input  wire        cpu2_int_n,
    output wire [15:0] cpu2_addr_out,
    output wire [7:0]  cpu2_data_out,
    input  wire [7:0]  cpu2_data_in,
    output wire        cpu2_mreq_n_out,
    output wire        cpu2_wr_n_out,
    output wire        shared_ram_we_b,
    output reg  [2:0]  video_r,
    output reg  [2:0]  video_g,
    output reg  [2:0]  video_b,
    output reg         video_hs,
    output reg         video_vs,
    output wire        video_hb,
    output wire        video_vb,
    output wire [8:0]  v_count_out
);

    wire [15:0] cpu2_a;
    wire [7:0]  cpu2_di;
    wire [7:0]  cpu2_do;
    wire        cpu2_mreq_n;
    wire        cpu2_rd_n;
    wire        cpu2_wr_n;

    assign cpu2_addr_out   = cpu2_a;
    assign cpu2_data_out   = cpu2_do;
    assign cpu2_mreq_n_out = cpu2_mreq_n;
    assign cpu2_wr_n_out   = cpu2_wr_n;
    assign shared_ram_we_b = ~cpu2_mreq_n && ~cpu2_wr_n && (cpu2_a[15:11] == 5'b01000);

    wire [7:0]  rom2_q;
    wire [7:0]  vram1_q_b;
    wire [7:0]  vram2_q_a, vram2_q_b;
    wire [13:0] scan_vram_addr;
    wire        vram2_we_a = ~cpu2_mreq_n && ~cpu2_wr_n && (cpu2_a[15:14] == 2'b10);

    always_comb begin
        if (~cpu2_mreq_n && ~cpu2_rd_n) begin
            if (cpu2_a[15:13] == 3'b000)         cpu2_di = rom2_q;
            else if (cpu2_a[15:11] == 5'b01000)  cpu2_di = cpu2_data_in;
            else if (cpu2_a[15:14] == 2'b10)     cpu2_di = vram2_q_a;
            else                                 cpu2_di = 8'hFF;
        end else begin
            cpu2_di = 8'hFF;
        end
    end

    T80se u_cpu2 (
        .RESET_n(cpu_reset_n),
        .CLK_n(clk),
        .CLKEN(cpu_en),
        .WAIT_n(1'b1),
        .INT_n(cpu2_int_n),
        .NMI_n(1'b1),
        .BUSRQ_n(1'b1),
        .MREQ_n(cpu2_mreq_n),
        .RD_n(cpu2_rd_n),
        .WR_n(cpu2_wr_n),
        .A(cpu2_a),
        .DI(cpu2_di),
        .DO(cpu2_do)
    );

    wire rom2_we = ioctl_download && (ioctl_index == 8'd0) && ioctl_wr && (ioctl_addr[16:13] == 4'b0010);

    dpram #(13, 8) u_rom2 (
        .clock_a(clk),
        .enable_a(1'b1),
        .wren_a(rom2_we),
        .address_a(ioctl_addr[12:0]),
        .data_a(ioctl_dout),
        .q_a(),
        .clock_b(clk),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(cpu2_a[12:0]),
        .data_b(8'h00),
        .q_b(rom2_q)
    );

    dpram #(14, 8) u_vram1 (
        .clock_a(clk),
        .clock_b(clk),
        .enable_a(1'b1),
        .wren_a(cpu1_vram_we),
        .address_a(cpu1_vram_addr),
        .data_a(cpu1_vram_data),
        .q_a(cpu1_vram_q),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(scan_vram_addr),
        .data_b(8'h00),
        .q_b(vram1_q_b)
    );

    dpram #(14, 8) u_vram2 (
        .clock_a(clk),
        .clock_b(clk),
        .enable_a(1'b1),
        .wren_a(vram2_we_a),
        .address_a(cpu2_a[13:0]),
        .data_a(cpu2_do),
        .q_a(vram2_q_a),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(scan_vram_addr),
        .data_b(8'h00),
        .q_b(vram2_q_b)
    );

    reg [9:0] h_count;
    reg [8:0] v_count;

    assign v_count_out = v_count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 9'd0;
        end else if (pix_en) begin
            if (h_count == 10'd319) begin
                h_count <= 10'd0;
                if (v_count == 9'd263) begin
                    v_count <= 9'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    wire [7:0] x_coord = h_count[7:0];
    wire [7:0] y_coord = v_count[7:0];

    wire [7:0] eff_x = flipscreen ? (8'd255 - x_coord) : x_coord;
    wire [7:0] eff_y = flipscreen ? (8'd255 - y_coord) : y_coord;

    assign scan_vram_addr = {eff_y, eff_x[7:2]};

    wire [1:0] bit_sel = eff_x[1:0];
    reg        pixel1_d0, pixel1_d1;
    reg        pixel2_d0, pixel2_d1;
    reg  [1:0] bit_sel_d;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            bit_sel_d <= 2'b00;
        else
            bit_sel_d <= bit_sel;
    end

    always_comb begin
        case (bit_sel_d)
            2'b00: begin
                pixel1_d0 = vram1_q_b[0]; pixel1_d1 = vram1_q_b[4];
                pixel2_d0 = vram2_q_b[0]; pixel2_d1 = vram2_q_b[4];
            end
            2'b01: begin
                pixel1_d0 = vram1_q_b[1]; pixel1_d1 = vram1_q_b[5];
                pixel2_d0 = vram2_q_b[1]; pixel2_d1 = vram2_q_b[5];
            end
            2'b10: begin
                pixel1_d0 = vram1_q_b[2]; pixel1_d1 = vram1_q_b[6];
                pixel2_d0 = vram2_q_b[2]; pixel2_d1 = vram2_q_b[6];
            end
            2'b11: begin
                pixel1_d0 = vram1_q_b[3]; pixel1_d1 = vram1_q_b[7];
                pixel2_d0 = vram2_q_b[3]; pixel2_d1 = vram2_q_b[7];
            end
        endcase
    end

    wire       prom1_a7   = (core_mod[2:0] == 3'd2) ? 1'b0 : palreg0[1:1];
    wire       prom2_a7   = (core_mod[2:0] == 3'd2) ? (pixel1_d1 | pixel1_d0) : palreg1[1:1];
    wire [7:0] prom1_addr = {prom1_a7, palreg0[4:0], pixel1_d1, pixel1_d0};
    wire [7:0] prom2_addr = {prom2_a7, palreg1[4:0], pixel2_d1, pixel2_d0};

    wire [7:0] prom1_q;
    wire [7:0] prom2_q;

    wire prom1_we = ioctl_download && (ioctl_index == 8'd0) && ioctl_wr && (ioctl_addr[16:8] == 9'h060);
    wire prom2_we = ioctl_download && (ioctl_index == 8'd0) && ioctl_wr && (ioctl_addr[16:8] == 9'h061);

    dpram #(8, 8) u_color_prom1 (
        .clock_a(clk),
        .enable_a(1'b1),
        .wren_a(prom1_we),
        .address_a(ioctl_addr[7:0]),
        .data_a(ioctl_dout),
        .q_a(),
        .clock_b(clk),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(prom1_addr),
        .data_b(8'h00),
        .q_b(prom1_q)
    );

    dpram #(8, 8) u_color_prom2 (
        .clock_a(clk),
        .enable_a(1'b1),
        .wren_a(prom2_we),
        .address_a(ioctl_addr[7:0]),
        .data_a(ioctl_dout),
        .q_a(),
        .clock_b(clk),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(prom2_addr),
        .data_b(8'h00),
        .q_b(prom2_q)
    );

    wire [2:0] final_color = prom1_q[2:0] | prom2_q[2:0];

    assign video_hb = (h_count >= 10'd256);
    assign video_vb = (v_count >= 9'd256);
    wire blank = video_hb | video_vb;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            video_r  <= 3'b000;
            video_g  <= 3'b000;
            video_b  <= 2'b00;
            video_hs <= 1'b1;
            video_vs <= 1'b1;
        end else if (pix_en) begin
            video_hs <= (h_count >= 10'd272 && h_count < 10'd296) ? 1'b0 : 1'b1;
            video_vs <= (v_count >= 9'd258 && v_count < 9'd261) ? 1'b0 : 1'b1;

            if (blank) begin
                video_r <= 3'b000;
                video_g <= 3'b000;
                video_b <= 3'b000;
            end else begin
                video_r <= final_color[0] ? 3'b111 : 3'b000;
                video_g <= final_color[1] ? 3'b111 : 3'b000;
                video_b <= final_color[2] ? 3'b111 : 3'b000;
            end
        end
    end

endmodule
