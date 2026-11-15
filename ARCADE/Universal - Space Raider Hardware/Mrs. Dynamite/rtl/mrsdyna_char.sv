module mrsdyna_char (
    input  logic        clk_20mhz_i,
    input  logic        por_n_i,
    input  logic        res_n_i,
    input  logic        clk_en_5mhz_i,
    input  logic        clk_en_4mhz_i,
    input  logic        cs10_n_i,
    input  logic        cs13_n_i,
    input  logic [10:0] a_i,
    input  logic        rd_n_i,
    input  logic        wr_n_i,
    output logic        wait_n_o,
    input  logic [7:0]  d_from_cpu_i,
    output logic [7:0]  d_from_char_o,
    input  logic [3:0]  h_i,
    input  logic [3:0]  h_t_i,
    input  logic        ha_t_rise_i,
    input  logic        hx_i,
    input  logic [3:0]  v_i,
    input  logic [3:0]  v_t_i,
    input  logic        hbl_i,
    input  logic        blank_flont_i,
    output logic        blank_o,
    output logic [5:1]  crg_o,
    output logic        vblank_o,
    output logic        hblank_o,
    output logic        flip_screen_q
);

    logic [15:0] d_char_rom_q, d_char_rom_q_reg, d_char_rom_i;
    logic [11:0] rom_char_a_o;
    logic [9:0]  ram_addr_s, ram_addr_s_net;
    logic [8:0]  sum_v;
    logic [7:0]  d_from_char_ram_s, s_q, d_char_ram_q, d_from_char_o_net;
    logic [4:1]  h_ctrl_d_s, h_ctrl_s, h_ctrl_n_s, h_ctrl_d_out_s, h_ctrl_rise_s, h_ctrl_n_s_rise;
    logic [3:0]  h_flip_s, h_t_flip_s, v_flip_s, v_t_flip_s, d_from_col_ram_s, d_col_ram_q, idx_4bit;
    logic [2:0]  ram_vec_v, idx_v;
    logic [1:0]  mux_vec_v;
    logic        h0_s, h1_s, h2_s, hx_ctrl_q, hx_ctrl_s, hx_ctrl_n_rise_s, hx_ctrl_clear_q;
    logic        b1_ff_q, b1_ff_s, b1_ff_n_rise_s, wait_q, wait_clear_q, cgs_q, cgs_s, cgs_rise_s;
    logic        select_a_s, char_ram_cs_n_s, char_ram_we_n_s, col_ram_cs_n_s, col_ram_we_n_s;
    logic        crg1_s, crg2_s, crg3_q, crg4_q, crg5_q, hbl_q, hbl_d;
    logic        a_v_wire, b_v_wire, g_n_v_wire;
    logic        char_ram_cs_n_s_net, char_ram_we_n_s_net, col_ram_cs_n_s_net, col_ram_we_n_s_net;
    logic        cpu_read_char_ram_v, cpu_write_char_ram_v, cpu_read_col_ram_v, cpu_write_col_ram_v;
    logic        hblank_reg, vblank_reg, blank_v;
    int          hcnt;

    assign d_char_rom_q = d_char_rom_q_reg;
    assign sum_v        = {1'b0, s_q} + {1'b0, h_t_i, h_i};

    always_ff @(posedge clk_20mhz_i or negedge res_n_i) begin
        if (res_n_i == 1'b0) begin
            flip_screen_q <= 1'b0;
        end else begin
            if (a_i[2:0] == 3'b000 && cs10_n_i == 1'b0) begin
                flip_screen_q <= d_from_cpu_i[0:0];
            end
        end
    end

    always_comb begin
        h0_s       = sum_v[0:0];
        h1_s       = sum_v[1:1];
        h2_s       = sum_v[2:2];
        h_flip_s   = {4{flip_screen_q}} ^ sum_v[3:0];
        h_t_flip_s = {4{flip_screen_q}} ^ sum_v[7:4];
        v_flip_s   = {4{flip_screen_q}} ^ v_i;
        v_t_flip_s = {4{flip_screen_q}} ^ v_t_i;
    end

    always_comb begin
        h_ctrl_d_s[1:1] = !(!h2_s && (h1_s ^ h0_s));
        h_ctrl_d_s[2:2] = hx_i;
        h_ctrl_d_s[3:3] = !((h1_s ^ h0_s) || (!h2_s ^ h1_s));
        h_ctrl_d_s[4:4] = 1'b0;
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            h_ctrl_s   <= 4'b0000;
            h_ctrl_n_s <= 4'b1111;
        end else if (clk_en_5mhz_i == 1'b1) begin
            h_ctrl_s   <= h_ctrl_d_s;
            h_ctrl_n_s <= ~h_ctrl_d_s;
        end
    end

    always_comb begin
        h_ctrl_d_out_s   = clk_en_5mhz_i ? h_ctrl_d_s : h_ctrl_s;
    end

    assign h_ctrl_rise_s   = ~h_ctrl_s & h_ctrl_d_out_s;
    assign h_ctrl_n_s_rise =  h_ctrl_s & ~h_ctrl_d_out_s;

    always_comb begin
        hx_ctrl_s        = hx_ctrl_q;
        hx_ctrl_n_rise_s = 1'b0;
        b1_ff_s          = b1_ff_q;
        b1_ff_n_rise_s   = 1'b0;
        cgs_s            = cgs_q;
        cgs_rise_s       = 1'b0;

        if (hx_ctrl_clear_q == 1'b1) begin
            hx_ctrl_s = 1'b0;
            if (hx_ctrl_q) hx_ctrl_n_rise_s = 1'b1;
        end else if (h_ctrl_rise_s[1:1] == 1'b1) begin
            if (hx_i == 1'b1) begin
                hx_ctrl_s = !hx_ctrl_q;
                if (hx_ctrl_q) hx_ctrl_n_rise_s = 1'b1;
            end
        end

        if (hx_ctrl_q == 1'b1) begin
            b1_ff_s = 1'b0;
            if (b1_ff_q) b1_ff_n_rise_s = 1'b1;
        end else if (h_ctrl_n_s_rise[3:3] == 1'b1) begin
            b1_ff_s = 1'b1;
        end
        cgs_s      = !cs13_n_i;
        cgs_rise_s = !cgs_q && !cs13_n_i;
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            hx_ctrl_q       <= 1'b0;
            hx_ctrl_clear_q <= 1'b0;
            b1_ff_q         <= 1'b0;
            wait_q          <= 1'b0;
            wait_clear_q    <= 1'b0;
            cgs_q           <= 1'b0;
        end else begin
            hx_ctrl_q <= hx_ctrl_s;
            if (h_ctrl_s[2:2] == 1'b0) begin
                hx_ctrl_clear_q <= 1'b0;
            end else if (hx_ctrl_n_rise_s == 1'b1) begin
                hx_ctrl_clear_q <= 1'b1;
            end
            b1_ff_q <= b1_ff_s;
            cgs_q   <= cgs_s;
            if (wait_clear_q == 1'b1) begin
                wait_q <= 1'b0;
            end else if (cgs_rise_s == 1'b1) begin
                wait_q <= 1'b1;
            end
            if (clk_en_4mhz_i == 1'b1) begin
                wait_clear_q <= wait_q && (h_ctrl_s[3:3] && (b1_ff_q || hx_ctrl_q));
            end
        end
    end

    assign a_v_wire   = !(h_ctrl_n_s[1:1] && (b1_ff_q || hx_ctrl_q));
    assign b_v_wire   = hx_ctrl_q;
    assign g_n_v_wire = hx_ctrl_q && (h_ctrl_n_s[1:1] && (b1_ff_q || hx_ctrl_q));
    assign mux_vec_v  = {b_v_wire, a_v_wire};

    always_comb begin
        ram_addr_s_net = 10'd0;
        case (mux_vec_v)
            2'b00: begin
                ram_addr_s_net[0:0] = h_flip_s[3:3];
                ram_addr_s_net[1:1] = h_t_flip_s[0:0];
                ram_addr_s_net[2:2] = h_t_flip_s[1:1];
                ram_addr_s_net[3:3] = h_t_flip_s[2:2];
            end
            2'b01: begin
                ram_addr_s_net[0:0] = a_i[0:0];
                ram_addr_s_net[1:1] = a_i[1:1];
                ram_addr_s_net[2:2] = a_i[2:2];
                ram_addr_s_net[3:3] = a_i[3:3];
            end
            2'b10: begin
                ram_addr_s_net[0:0] = v_t_flip_s[1:1];
                ram_addr_s_net[1:1] = v_t_flip_s[2:2];
                ram_addr_s_net[2:2] = v_t_flip_s[3:3];
                ram_addr_s_net[3:3] = 1'b0;
            end
            default: begin
                ram_addr_s_net[0:0] = a_i[0:0];
                ram_addr_s_net[1:1] = a_i[1:1];
                ram_addr_s_net[2:2] = a_i[2:2];
                ram_addr_s_net[3:3] = a_i[3:3];
            end
        endcase
        if (a_v_wire == 1'b0) begin
            ram_addr_s_net[4:4] = h_t_flip_s[3:3] && !g_n_v_wire;
            ram_addr_s_net[7:7] = v_t_flip_s[1:1] && !g_n_v_wire;
            ram_addr_s_net[8:8] = v_t_flip_s[2:2] && !g_n_v_wire;
            ram_addr_s_net[9:9] = v_t_flip_s[3:3] && !g_n_v_wire;
            ram_addr_s_net[5:5] = v_flip_s[3:3];
            ram_addr_s_net[6:6] = v_t_flip_s[0:0];
        end else begin
            ram_addr_s_net[4:4] = a_i[4:4] && !g_n_v_wire;
            ram_addr_s_net[7:7] = a_i[7:7] && !g_n_v_wire;
            ram_addr_s_net[8:8] = a_i[8:8] && !g_n_v_wire;
            ram_addr_s_net[9:9] = a_i[9:9] && !g_n_v_wire;
            ram_addr_s_net[5:5] = a_i[5:5];
            ram_addr_s_net[6:6] = a_i[6:6];
        end
    end

    assign ram_addr_s = ram_addr_s_net;
    assign select_a_s = a_v_wire;

    always_comb begin
        ram_vec_v            = 3'b000;
        char_ram_cs_n_s_net  = 1'b1;
        char_ram_we_n_s_net  = 1'b1;
        col_ram_cs_n_s_net   = 1'b1;
        col_ram_we_n_s_net   = 1'b1;
        d_from_char_o_net    = 8'hFF;
        cpu_read_char_ram_v  = 1'b0;
        cpu_write_char_ram_v = 1'b0;
        cpu_read_col_ram_v   = 1'b0;
        cpu_write_col_ram_v  = 1'b0;

        if ((!cs13_n_i && select_a_s && !wait_q) == 1'b1) begin
            ram_vec_v = {a_i[10:10], rd_n_i, wr_n_i};
            case (ram_vec_v)
                3'b001:  cpu_read_char_ram_v  = 1'b1;
                3'b010:  cpu_write_char_ram_v = 1'b1;
                3'b101:  cpu_read_col_ram_v   = 1'b1;
                3'b110:  cpu_write_col_ram_v  = 1'b1;
                default: ;
            endcase
        end
        if (select_a_s == 1'b0 || cpu_read_char_ram_v || cpu_write_char_ram_v) char_ram_cs_n_s_net = 1'b0;
        if (select_a_s == 1'b0 || cpu_read_col_ram_v  || cpu_write_col_ram_v)  col_ram_cs_n_s_net  = 1'b0;
        if (cpu_write_char_ram_v) char_ram_we_n_s_net = 1'b0;
        if (cpu_write_col_ram_v)  col_ram_we_n_s_net  = 1'b0;
        if (cpu_read_char_ram_v)     d_from_char_o_net      = d_from_char_ram_s;
        else if (cpu_read_col_ram_v) d_from_char_o_net[3:0] = d_from_col_ram_s;
    end

    assign char_ram_cs_n_s = char_ram_cs_n_s_net;
    assign char_ram_we_n_s = char_ram_we_n_s_net;
    assign col_ram_cs_n_s  = col_ram_cs_n_s_net;
    assign col_ram_we_n_s  = col_ram_we_n_s_net;
    assign d_from_char_o   = d_from_char_o_net;

    spram #(10,8) char_ram_b (
        .clock  (clk_20mhz_i),
        .enable (clk_en_4mhz_i & ~char_ram_cs_n_s),
        .address(ram_addr_s),
        .data   (d_from_cpu_i),
        .wren   (~char_ram_we_n_s),
        .q      (d_from_char_ram_s)
    );

    spram #(10,4) col_ram_b (
        .clock  (clk_20mhz_i),
        .enable (clk_en_4mhz_i & ~col_ram_cs_n_s),
        .address(ram_addr_s),
        .data   (d_from_cpu_i[3:0]),
        .wren   (~col_ram_we_n_s),
        .q      (d_from_col_ram_s)
    );


    assign rom_char_a_o[2:0]   = v_flip_s[2:0];
    assign rom_char_a_o[10:3]  = d_char_ram_q;
    assign rom_char_a_o[11:11] = d_col_ram_q[3:3];

    gfx1_16bit char_rom_inst (
        .clk(clk_20mhz_i),
        .addr(rom_char_a_o),
        .data(d_char_rom_i)
    );

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            s_q              <= 8'h00;
            d_char_ram_q     <= 8'h00;
            d_col_ram_q      <= 4'h0;
            d_char_rom_q_reg <= 16'h0000;
            crg3_q           <= 1'b0;
            crg4_q           <= 1'b0;
            crg5_q           <= 1'b0;
        end else begin
            if (hx_ctrl_n_rise_s == 1'b1) begin
                s_q <= d_from_char_ram_s;
            end
            if ((h_ctrl_rise_s[1:1] && (b1_ff_q || hx_ctrl_q)) ||
                (hx_ctrl_n_rise_s && (!b1_ff_q && !h_ctrl_n_s[1:1])) ||
                (b1_ff_n_rise_s   && (!hx_ctrl_q && !h_ctrl_s[1:1]))) begin
                d_char_ram_q <= d_from_char_ram_s;
                d_col_ram_q  <= d_from_col_ram_s;
            end
            if ((clk_en_5mhz_i && h2_s && h1_s && h0_s) == 1'b1) begin
                d_char_rom_q_reg <= d_char_rom_i;
                crg3_q           <= d_col_ram_q[0:0];
                crg4_q           <= d_col_ram_q[1:1];
                crg5_q           <= d_col_ram_q[2:2];
            end
        end
    end

    always_ff @(posedge clk_20mhz_i or negedge por_n_i) begin
        if (por_n_i == 1'b0) begin
            hbl_q <= 1'b0;
            hcnt  <= 0;
        end else begin
            if (clk_en_5mhz_i == 1'b1) begin
                if (hcnt != 255) hcnt <= hcnt + 1;
            end
            if (ha_t_rise_i == 1'b1) begin
                hbl_q <= hbl_i;
                if (hbl_q == 1'b1 && hbl_i == 1'b0) begin
                    hcnt <= 0;
                end
            end
        end
    end

    always_ff @(posedge clk_20mhz_i) begin
        if (clk_en_5mhz_i == 1'b1) begin
            hbl_d <= hbl_q;
            if (hcnt < 240) begin
                hblank_reg <= 1'b0;
            end else begin
                hblank_reg <= 1'b1;
            end
            if (hbl_d == 1'b0 && hbl_q == 1'b1) begin
                vblank_reg <= !blank_flont_i;
            end
        end
    end

    assign hblank_o = hblank_reg;
    assign vblank_o = vblank_reg;
    assign idx_4bit = {1'b0, idx_v};

    always_comb begin
        blank_v = !(blank_flont_i && !hbl_q);
        idx_v   = h_flip_s[2:0];
        if (blank_v == 1'b0) begin
            crg1_s = d_char_rom_q[idx_4bit +: 1];
            crg2_s = d_char_rom_q[(4'd8 + idx_v) +: 1];
        end else begin
            crg1_s = 1'b0;
            crg2_s = 1'b0;
        end
    end

    assign blank_o  = blank_v;
    assign wait_n_o = !wait_q;
    assign crg_o    = {crg5_q, crg4_q, crg3_q, crg2_s, crg1_s};

endmodule
