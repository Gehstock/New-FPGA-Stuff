module z80_sio (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        m1_n,
    input  logic        ba_sel,
    input  logic        cd_sel,
    input  logic        ce_n,
    input  logic        iorq_n,
    input  logic        rd_n,
    input  logic [7:0]  din,
    output logic [7:0]  dout,
    output logic        dout_en,

    input  logic        txca,
    input  logic        rxca,
    input  logic        rxa,
    output logic        txda,
    input  logic        ctsa_n,
    input  logic        dcda_n,
    output logic        dtra_n,
    output logic        rtsa_n,

    input  logic        txcb,
    input  logic        rxcb,
    input  logic        rxb,
    output logic        txdb,
    input  logic        ctsb_n,
    input  logic        dcdb_n,
    output logic        dtrb_n,
    output logic        rtsb_n,

    input  logic        iei,
    output logic        ieo,
    output logic        int_n
);

    logic [7:0] int_vector;
    logic       int_ch_a_active;
    logic       int_ch_b_active;
    
    logic [7:0] ch_a_dout, ch_b_dout;
    logic       ch_a_we, ch_b_we;
    logic       ch_a_re, ch_b_re;
    logic [2:0] ch_a_reg_sel, ch_b_reg_sel;

    logic [2:0] pointer_a;
    logic [2:0] pointer_b;

    wire is_sio_we_raw  = (!ce_n && !iorq_n && m1_n && rd_n);
    wire is_sio_re_raw  = (!ce_n && !iorq_n && m1_n && !rd_n);
    wire is_int_ack_raw = (!iorq_n && !m1_n);

    logic is_sio_we_d, is_sio_re_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_sio_we_d <= 1'b0;
            is_sio_re_d <= 1'b0;
        end else begin
            is_sio_we_d <= is_sio_we_raw;
            is_sio_re_d <= is_sio_re_raw;
        end
    end

    wire we_pulse = is_sio_we_raw && !is_sio_we_d;
    wire re_end   = !is_sio_re_raw && is_sio_re_d;

    assign ch_a_we = we_pulse && !ba_sel;
    assign ch_b_we = we_pulse && ba_sel;
    assign ch_a_re = re_end && !ba_sel;
    assign ch_b_re = re_end && ba_sel;

    assign ch_a_reg_sel = cd_sel ? pointer_a : 3'd0;
    assign ch_b_reg_sel = cd_sel ? pointer_b : 3'd0;

    wire any_int = int_ch_a_active || int_ch_b_active;
    assign dout_en = is_sio_re_raw || (is_int_ack_raw && iei && any_int);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_a <= 3'd0;
        end else if (ch_a_we) begin
            if (cd_sel) begin
                if (pointer_a == 3'd0) begin
                    if (din[5:3] == 3'b011)
                        pointer_a <= 3'd0;
                    else
                        pointer_a <= din[2:0];
                end else begin
                    pointer_a <= 3'd0;
                end
            end else begin
                pointer_a <= 3'd0;
            end
        end else if (ch_a_re) begin
            if (cd_sel) pointer_a <= 3'd0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_b  <= 3'd0;
            int_vector <= 8'h00;
        end else if (ch_b_we) begin
            if (cd_sel) begin
                if (pointer_b == 3'd0) begin
                    if (din[5:3] == 3'b011)
                        pointer_b <= 3'd0;
                    else
                        pointer_b <= din[2:0];
                end else begin
                    if (pointer_b == 3'd2) int_vector <= din;
                    pointer_b <= 3'd0;
                end
            end else begin
                pointer_b <= 3'd0;
            end
        end else if (ch_b_re) begin
            if (cd_sel) pointer_b <= 3'd0;
        end
    end

    z80_sio_channel channel_a (
        .clk       (clk),
        .rst_n     (rst_n),
        .we        (ch_a_we),
        .re        (ch_a_re),
        .cd_sel    (cd_sel),
        .reg_sel   (ch_a_reg_sel),
        .din       (din),
        .dout      (ch_a_dout),
        .txc       (txca),
        .rxc       (rxca),
        .rx        (rxa),
        .tx        (txda),
        .cts_n     (ctsa_n),
        .dcd_n     (dcda_n),
        .dtr_n     (dtra_n),
        .rts_n     (rtsa_n),
        .int_req   (int_ch_a_active)
    );

    z80_sio_channel channel_b (
        .clk       (clk),
        .rst_n     (rst_n),
        .we        (ch_b_we),
        .re        (ch_b_re),
        .cd_sel    (cd_sel),
        .reg_sel   (ch_b_reg_sel),
        .din       (din),
        .dout      (ch_b_dout),
        .txc       (txcb),
        .rxc       (rxcb),
        .rx        (rxb),
        .tx        (txdb),
        .cts_n     (ctsb_n),
        .dcd_n     (dcdb_n),
        .dtr_n     (dtrb_n),
        .rts_n     (rtsb_n),
        .int_req   (int_ch_b_active)
    );

    assign ieo   = iei && !any_int;
    assign int_n = (iei && any_int) ? 1'b0 : 1'b1;

    always_comb begin
        if (is_int_ack_raw && iei && any_int) begin
            if (int_ch_a_active)      dout = {int_vector[7:3], 3'b100};
            else if (int_ch_b_active) dout = {int_vector[7:3], 3'b000};
            else                      dout = int_vector;
        end else if (!ba_sel) begin
            dout = ch_a_dout;
        end else begin
            dout = ch_b_dout;
        end
    end

endmodule

module z80_sio_channel (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic        re,
    input  logic        cd_sel,
    input  logic [2:0]  reg_sel,
    input  logic [7:0]  din,
    output logic [7:0]  dout,

    input  logic        txc,
    input  logic        rxc,
    input  logic        rx,
    output logic        tx,
    input  logic        cts_n,
    input  logic        dcd_n,
    output logic        dtr_n,
    output logic        rts_n,
    output logic        int_req
);

    logic [7:0] wr [0:7];
    logic [7:0] rr0, rr1;
    logic [7:0] rx_data;

    logic [7:0] tx_shift;
    logic [7:0] rx_shift;
    logic [3:0] tx_bit_cnt;
    logic [3:0] rx_bit_cnt;
    
    logic       tx_buffer_empty;
    logic       rx_char_available;
    logic       sync_hunt;

    logic txc_q, rxc_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txc_q <= 1'b0;
            rxc_q <= 1'b0;
        end else begin
            txc_q <= txc;
            rxc_q <= rxc;
        end
    end
    
    wire txc_fall = (!txc && txc_q);
    wire rxc_rise = (rxc && !rxc_q);
    wire ch_reset = we && cd_sel && (reg_sel == 3'd0) && (din[5:3] == 3'b011);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) wr[i] <= 8'h00;
        end else if (ch_reset) begin
            for (int i = 0; i < 8; i++) wr[i] <= 8'h00;
        end else if (we && cd_sel) begin
            wr[reg_sel] <= din;
        end
    end

    assign dtr_n   = !wr[5][7];
    assign rts_n   = !wr[5][1];
    assign int_req = ((wr[1][4] || wr[1][3]) && rx_char_available) || (wr[1][1] && tx_buffer_empty);

    always_comb begin
        rr0 = {1'b0, 1'b0, cts_n, sync_hunt, dcd_n, tx_buffer_empty, 1'b0, rx_char_available};
        rr1 = 8'h01;

        if (!cd_sel) begin
            dout = rx_data;
        end else begin
            case (reg_sel)
                3'd0:    dout = rr0;
                3'd1:    dout = rr1;
                3'd2:    dout = wr[2];
                default: dout = rr0;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx              <= 1'b1;
            tx_shift        <= 8'hFF;
            tx_bit_cnt      <= 4'd0;
            tx_buffer_empty <= 1'b1;
        end else if (ch_reset) begin
            tx              <= 1'b1;
            tx_shift        <= 8'hFF;
            tx_bit_cnt      <= 4'd0;
            tx_buffer_empty <= 1'b1;
        end else begin
            if (we && !cd_sel) begin
                tx_shift        <= din;
                tx_bit_cnt      <= 4'd8;
                tx_buffer_empty <= 1'b0;
            end else if (txc_fall && (tx_bit_cnt > 4'd0)) begin
                tx         <= tx_shift[0];
                tx_shift   <= {1'b1, tx_shift[7:1]};
                tx_bit_cnt <= tx_bit_cnt - 4'd1;
                if (tx_bit_cnt == 4'd1) begin
                    tx_buffer_empty <= 1'b1;
                end
            end
        end
    end

    wire enter_hunt = we && cd_sel && ((reg_sel == 3'd3 && din[4]) || (reg_sel == 3'd0 && din[5:3] == 3'b010));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift          <= 8'h00;
            rx_bit_cnt        <= 4'd0;
            rx_data           <= 8'h00;
            rx_char_available <= 1'b0;
            sync_hunt         <= 1'b0;
        end else if (ch_reset) begin
            rx_shift          <= 8'h00;
            rx_bit_cnt        <= 4'd0;
            rx_data           <= 8'h00;
            rx_char_available <= 1'b0;
            sync_hunt         <= 1'b0;
        end else begin
            if (enter_hunt) begin
                sync_hunt  <= 1'b1;
                rx_bit_cnt <= 4'd0;
            end

            if (re && !cd_sel) begin
                rx_char_available <= 1'b0;
            end

            if (rxc_rise && wr[3][0]) begin
                if (sync_hunt) begin
                    logic [7:0] next_shift;
                    next_shift = {rx, rx_shift[7:1]};
                    rx_shift <= next_shift;
                    if (next_shift == wr[6] || next_shift == wr[7]) begin
                        sync_hunt  <= 1'b0;
                        rx_bit_cnt <= 4'd0;
                    end
                end else begin
                    if (rx_bit_cnt == 4'd7) begin
                        rx_data           <= {rx, rx_shift[7:1]};
                        rx_char_available <= 1'b1;
                        rx_bit_cnt        <= 4'd0;
                    end else begin
                        rx_shift   <= {rx, rx_shift[7:1]};
                        rx_bit_cnt <= rx_bit_cnt + 4'd1;
                    end
                end
            end
        end
    end

endmodule
