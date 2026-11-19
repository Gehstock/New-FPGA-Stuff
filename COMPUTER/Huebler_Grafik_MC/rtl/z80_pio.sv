module z80_pio (
    input  logic        clk,
    input  logic        clken,
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
    input  logic [7:0]  port_a_in,
    output logic [7:0]  port_a_out,
    input  logic [7:0]  port_b_in,
    output logic [7:0]  port_b_out,
    input  logic        iei,
    output logic        ieo,
    output logic        int_n
);

    typedef enum logic [1:0] {
        MODE_OUTPUT = 2'b00,
        MODE_INPUT  = 2'b01,
        MODE_BIDI   = 2'b10,
        MODE_CTRL   = 2'b11
    } pio_mode_e;

    typedef struct packed {
        pio_mode_e    mode;
        logic [7:0]   output_reg;
        logic [7:0]   input_reg;
        logic [7:0]   io_select;
        logic [7:0]   mask_reg;
        logic         int_enable;
        logic         int_and_or;
        logic         int_high_low;
        logic         int_mask_follows;
        logic [7:0]   int_vector;
        logic         int_pending;
        logic         int_in_service;
    } pio_port_t;

    pio_port_t port_a, port_b;

    logic [1:0] expect_io_dir;
    logic [1:0] expect_mask;

    wire bus_write_raw = (!iorq_n) && (!ce_n) && (rd_n) && m1_n;
    wire bus_read_raw  = (!iorq_n) && (!ce_n) && (!rd_n) && m1_n;
    wire int_ack_raw   = (!m1_n) && (!iorq_n);

    logic bus_write_d, int_ack_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_write_d <= 1'b0;
            int_ack_d   <= 1'b0;
        end else begin
            bus_write_d <= bus_write_raw;
            int_ack_d   <= int_ack_raw;
        end
    end

    wire bus_write = bus_write_raw && !bus_write_d;
    wire int_ack   = int_ack_raw && !int_ack_d;

    logic reti_prefix_ed;
    wire m1_read = (!m1_n) && (!rd_n) && (iorq_n);
    logic m1_read_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m1_read_d      <= 1'b0;
            reti_prefix_ed <= 1'b0;
        end else begin
            m1_read_d <= m1_read;
            if (m1_read && !m1_read_d) begin
                if (din == 8'hED)
                    reti_prefix_ed <= 1'b1;
                else if (din != 8'h4D)
                    reti_prefix_ed <= 1'b0;
            end
        end
    end
    wire reti_detected = m1_read && !m1_read_d && reti_prefix_ed && (din == 8'h4D);

    logic port_a_request, port_b_request;
    assign port_a_request = port_a.int_enable && port_a.int_pending;
    assign port_b_request = port_b.int_enable && port_b.int_pending;

    assign dout_en    = bus_read_raw || (int_ack_raw && iei && (port_a_request || port_b_request));
    assign port_a_out = port_a.output_reg;
    assign port_b_out = port_b.output_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expect_io_dir          <= 2'b00;
            expect_mask            <= 2'b00;
            port_a.mode            <= MODE_INPUT;
            port_a.io_select       <= 8'hFF;
            port_a.mask_reg        <= 8'hFF;
            port_a.int_enable      <= 1'b0;
            port_a.int_and_or      <= 1'b0;
            port_a.int_high_low    <= 1'b0;
            port_a.int_mask_follows<= 1'b0;
            port_a.int_vector      <= 8'h00;
            port_a.output_reg      <= 8'h00;
            port_a.input_reg       <= 8'hFF;
            port_a.int_pending     <= 1'b0;
            port_a.int_in_service  <= 1'b0;
            port_b.mode            <= MODE_INPUT;
            port_b.io_select       <= 8'hFF;
            port_b.mask_reg        <= 8'hFF;
            port_b.int_enable      <= 1'b0;
            port_b.int_and_or      <= 1'b0;
            port_b.int_high_low    <= 1'b0;
            port_b.int_mask_follows<= 1'b0;
            port_b.int_vector      <= 8'h00;
            port_b.output_reg      <= 8'h00;
            port_b.input_reg       <= 8'hFF;
            port_b.int_pending     <= 1'b0;
            port_b.int_in_service  <= 1'b0;
        end else begin
            if (clken) begin
                port_a.input_reg <= port_a_in;
                port_b.input_reg <= port_b_in;
            end

            if (reti_detected && iei) begin
                if (port_a.int_in_service)      port_a.int_in_service <= 1'b0;
                else if (port_b.int_in_service) port_b.int_in_service <= 1'b0;
            end

            if (bus_write) begin
                if (!cd_sel) begin
                    if (!ba_sel) port_a.output_reg <= din;
                    else         port_b.output_reg <= din;
                end else begin
                    if (!ba_sel && expect_io_dir[0]) begin
                        port_a.io_select <= din;
                        expect_io_dir[0] <= 1'b0;
                    end else if (!ba_sel && expect_mask[0]) begin
                        port_a.mask_reg <= din;
                        expect_mask[0]  <= 1'b0;
                    end else if (ba_sel && expect_io_dir[1]) begin
                        port_b.io_select <= din;
                        expect_io_dir[1] <= 1'b0;
                    end else if (ba_sel && expect_mask[1]) begin
                        port_b.mask_reg <= din;
                        expect_mask[1]  <= 1'b0;
                    end else begin
                        if (din[0] == 1'b0) begin
                            if (!ba_sel) port_a.int_vector <= din;
                            else         port_b.int_vector <= din;
                        end else if (din[3:0] == 4'b1111) begin
                            if (!ba_sel) begin
                                port_a.mode <= pio_mode_e'(din[7:6]);
                                if (din[7:6] == 2'b11) expect_io_dir[0] <= 1'b1;
                            end else begin
                                port_b.mode <= pio_mode_e'(din[7:6]);
                                if (din[7:6] == 2'b11) expect_io_dir[1] <= 1'b1;
                            end
                        end else if (din[3:0] == 4'b0111) begin
                            if (!ba_sel) begin
                                port_a.int_enable       <= din[7];
                                port_a.int_and_or       <= din[6];
                                port_a.int_high_low     <= din[5];
                                port_a.int_mask_follows <= din[4];
                                if (din[4]) expect_mask[0] <= 1'b1;
                            end else begin
                                port_b.int_enable       <= din[7];
                                port_b.int_and_or       <= din[6];
                                port_b.int_high_low     <= din[5];
                                port_b.int_mask_follows <= din[4];
                                if (din[4]) expect_mask[1] <= 1'b1;
                            end
                        end else if (din[3:0] == 4'b0011) begin
                            if (!ba_sel) port_a.int_enable <= din[7];
                            else         port_b.int_enable <= din[7];
                        end
                    end
                end
            end

            if (port_a.mode == MODE_CTRL && port_a.int_enable) begin
                logic [7:0] match_bits_a;
                match_bits_a = port_a.int_high_low ? port_a.input_reg : ~port_a.input_reg;
                match_bits_a = match_bits_a & ~port_a.mask_reg;
                if (port_a.int_and_or) begin
                    if (match_bits_a == (~port_a.mask_reg) && (~port_a.mask_reg != 8'h00)) 
                        port_a.int_pending <= 1'b1;
                end else begin
                    if (match_bits_a != 8'h00) 
                        port_a.int_pending <= 1'b1;
                end
            end

            if (port_b.mode == MODE_CTRL && port_b.int_enable) begin
                logic [7:0] match_bits_b;
                match_bits_b = port_b.int_high_low ? port_b.input_reg : ~port_b.input_reg;
                match_bits_b = match_bits_b & ~port_b.mask_reg;
                if (port_b.int_and_or) begin
                    if (match_bits_b == (~port_b.mask_reg) && (~port_b.mask_reg != 8'h00)) 
                        port_b.int_pending <= 1'b1;
                end else begin
                    if (match_bits_b != 8'h00) 
                        port_b.int_pending <= 1'b1;
                end
            end

            if (int_ack && iei) begin
                if (port_a_request) begin
                    port_a.int_pending    <= 1'b0;
                    port_a.int_in_service <= 1'b1;
                end else if (port_b_request) begin
                    port_b.int_pending    <= 1'b0;
                    port_b.int_in_service <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        ieo   = iei && !port_a.int_in_service && !port_b.int_in_service;
        int_n = 1'b1;
        if (iei && !port_a.int_in_service && !port_b.int_in_service) begin
            if (port_a_request || port_b_request) begin
                ieo   = 1'b0;
                int_n = 1'b0;
            end
        end
    end

    always_comb begin
        dout = 8'hFF;
        if (bus_read_raw) begin
            if (!cd_sel) begin
                if (!ba_sel) begin
                    case (port_a.mode)
                        MODE_OUTPUT: dout = port_a.output_reg;
                        MODE_CTRL:   dout = (port_a.input_reg & port_a.io_select) | (port_a.output_reg & ~port_a.io_select);
                        default:     dout = port_a.input_reg;
                    endcase
                end else begin
                    case (port_b.mode)
                        MODE_OUTPUT: dout = port_b.output_reg;
                        MODE_CTRL:   dout = (port_b.input_reg & port_b.io_select) | (port_b.output_reg & ~port_b.io_select);
                        default:     dout = port_b.input_reg;
                    endcase
                end
            end else begin
                dout = (!ba_sel) ? {port_a.int_enable, port_a.mode, 5'b00000} : 
                                   {port_b.int_enable, port_b.mode, 5'b00000};
            end
        end else if (int_ack_raw && iei) begin
            if (port_a_request)      dout = port_a.int_vector;
            else if (port_b_request) dout = port_b.int_vector;
        end
    end

endmodule
