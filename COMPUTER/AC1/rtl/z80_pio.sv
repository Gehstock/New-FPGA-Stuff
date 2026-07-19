//Gehstock 2024
`timescale 1ns / 1ps
`default_nettype none

module z80_pio (
    input  logic        clk,
    input  logic        clken,Impuls aus dem Top-Level)
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
    } pio_port_t;

    pio_port_t port_a, port_b;

    logic [1:0] expect_io_dir;
    logic [1:0] expect_mask;
    logic bus_write, bus_read, internal_reset;
    
    assign bus_write = (!iorq_n) && (!ce_n) && (rd_n) && m1_n;
    assign bus_read  = (!iorq_n) && (!ce_n) && (!rd_n) && m1_n;
    assign internal_reset = (!m1_n) && iorq_n && rd_n; 
    assign dout_en = bus_read;
    assign port_a_out = port_a.output_reg;
    assign port_b_out = port_b.output_reg;

    always_ff @(posedge clk) begin
        if (internal_reset) begin
            expect_io_dir        <= 2'b00;
            expect_mask          <= 2'b00;
            port_a.mode          <= MODE_INPUT;
            port_a.mask_reg      <= 8'hFF;
            port_a.int_enable    <= 1'b0;
            port_a.output_reg    <= 8'h00;
            port_a.int_pending   <= 1'b0;
            port_b.mode          <= MODE_INPUT;
            port_b.mask_reg      <= 8'hFF;
            port_b.int_enable    <= 1'b0;
            port_b.output_reg    <= 8'h00;
            port_b.int_pending   <= 1'b0;
        end else if (clken) begin // Alle Zustandsänderungen an cpu_clken binden
            if (port_a.mode == MODE_CTRL)  port_a.input_reg <= port_a_in;
            if (port_b.mode == MODE_CTRL)  port_b.input_reg <= port_b_in;
            if (port_a.mode == MODE_INPUT) port_a.input_reg <= port_a_in;
            if (port_b.mode == MODE_INPUT) port_b.input_reg <= port_b_in;

            if (bus_write) begin
                if (!cd_sel) begin
                    if (!ba_sel) port_a.output_reg <= din;
                    else         port_b.output_reg <= din;
                end else begin
                    if (!ba_sel && expect_io_dir) begin
                        port_a.io_select <= din;
                        expect_io_dir <= 2'b00;
                    end
                    else if (!ba_sel && expect_mask) begin
                        port_a.mask_reg <= din;
                        expect_mask  <= 2'b00;
                    end
                    else if (ba_sel && expect_io_dir) begin
                        port_b.io_select <= din;
                        expect_io_dir <= 2'b00;
                    end
                    else if (ba_sel && expect_mask) begin
                        port_b.mask_reg <= din;
                        expect_mask  <= 2'b00;
                    end
                    else begin
                        if (din == 1'b0) begin
                            if (!ba_sel) port_a.int_vector <= din;
                            else         port_b.int_vector <= din;
                        end
                        else if (din[3:0] == 4'b1111) begin
                            if (!ba_sel) begin
                                port_a.mode <= pio_mode_e'(din[7:6]);
                                if (din[7:6] == 2'b11) expect_io_dir <= 2'b01;
                            end else begin
                                port_b.mode <= pio_mode_e'(din[7:6]);
                                if (din[7:6] == 2'b11) expect_io_dir <= 2'b10;
                            end
                        end
                        else if (din[3:0] == 4'b0111) begin
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
                        end
                    end
                end
            end

            if (port_a.mode == MODE_CTRL && port_a.int_enable) begin
                logic [7:0] match_bits;
                match_bits = port_a.int_high_low ? port_a.input_reg : ~port_a.input_reg;
                match_bits = match_bits & ~port_a.mask_reg;
                if (port_a.int_and_or) begin
                    if (match_bits == (~port_a.mask_reg) && (~port_a.mask_reg != 8'h00)) 
                        port_a.int_pending <= 1'b1;
                end else begin
                    if (match_bits != 8'h00) 
                        port_a.int_pending <= 1'b1;
                end
            end

            if (port_b.mode == MODE_CTRL && port_b.int_enable) begin
                logic [7:0] match_bits;
                match_bits = port_b.int_high_low ? port_b.input_reg : ~port_b.input_reg;
                match_bits = match_bits & ~port_b.mask_reg;
                if (port_b.int_and_or) begin
                    if (match_bits == (~port_b.mask_reg) && (~port_b.mask_reg != 8'h00)) 
                        port_b.int_pending <= 1'b1;
                end else begin
                    if (match_bits != 8'h00) 
                        port_b.int_pending <= 1'b1;
                end
            end

            if (!m1_n && !iorq_n) begin
                if (iei) begin
                    if (port_a.int_pending)      port_a.int_pending <= 1'b0;
                    else if (port_b.int_pending) port_b.int_pending <= 1'b0;
                end
            end
        end
    end

    logic port_a_request, port_b_request;
    assign port_a_request = port_a.int_enable && port_a.int_pending;
    assign port_b_request = port_b.int_enable && port_b.int_pending;

    always_comb begin
        ieo   = iei;
        int_n = 1'b1;
        if (!iei) begin
            ieo = 1'b0;
        end else if (port_a_request) begin
            ieo   = 1'b0;
            int_n = 1'b0;
        end else if (port_b_request) begin
            ieo   = 1'b0;
            int_n = 1'b0;
        end
    end

    always_comb begin
        dout = 8'hFF;
        if (bus_read) begin
            if (!cd_sel) begin
                if (!ba_sel) dout = (port_a.mode == MODE_OUTPUT) ? port_a.output_reg : port_a.input_reg;
                else         dout = (port_b.mode == MODE_OUTPUT) ? port_b.output_reg : port_b.input_reg;
            end else begin
                dout = (!ba_sel) ? {port_a.int_enable, port_a.mode, 5'b00000} : 
                                   {port_b.int_enable, port_b.mode, 5'b00000};
            end
        end 
        else if (!m1_n && !iorq_n) begin
            if (iei) begin
                if (port_a_request)       dout = port_a.int_vector;
                else if (port_b_request)  dout = port_b.int_vector;
            end
        end
    end

endmodule
`default_nettype wire
