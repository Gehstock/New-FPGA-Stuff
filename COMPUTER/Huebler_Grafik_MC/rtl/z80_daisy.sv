module z80_daisy #(
    parameter int NUM_CHIPS = 3
)(
    input  logic        cpu_clk,
    input  logic        rst_n,
    
    input  logic        cpu_m1_n,
    input  logic        cpu_iorq_n,
    input  logic        cpu_rd_n,
    input  logic [7:0]  cpu_data_in,
    output logic [7:0]  cpu_data_out,
    output logic        cpu_data_oe,
    output logic        cpu_int_n,
    
    input  logic        chain_iei,
    output logic        chain_ieo,
    
    input  logic [NUM_CHIPS-1:0]       irq_req,
    output logic [NUM_CHIPS-1:0]       irq_active,
    input  logic [NUM_CHIPS-1:0][7:0]  irq_vector
);

    typedef enum logic { IDLE, ED_FETCHED } state_t;
    state_t state [NUM_CHIPS-1:0];

    logic [NUM_CHIPS-1:0] irq_pending;
    logic [NUM_CHIPS-1:0] irq_ius;

    logic [NUM_CHIPS:0]   internal_chain;
    logic [NUM_CHIPS-1:0] iei_array;
    logic [NUM_CHIPS-1:0] ieo_array;

    logic m1_read_d;
    wire  m1_read_raw = !cpu_m1_n && !cpu_rd_n && cpu_iorq_n;

    wire cpu_int_ack_cycle = !cpu_m1_n && !cpu_iorq_n;

    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) m1_read_d <= 1'b0;
        else        m1_read_d <= m1_read_raw;
    end
    wire cpu_m1_fetch_strobe = !m1_read_raw && m1_read_d;

    always_comb begin
        internal_chain[0] = chain_iei;
        
        for (int i = 0; i < NUM_CHIPS; i++) begin
            iei_array[i]        = internal_chain[i];
            ieo_array[i]        = iei_array[i] && !irq_ius[i] && !(cpu_int_ack_cycle && irq_pending[i]);
            internal_chain[i+1] = ieo_array[i];
        end
        
        chain_ieo = internal_chain[NUM_CHIPS];
    end

    always_comb begin
        cpu_int_n    = 1'b1;
        cpu_data_out = 8'h00;
        cpu_data_oe  = 1'b0;
        irq_active   = irq_ius;

        for (int i = 0; i < NUM_CHIPS; i++) begin
            if (iei_array[i] && irq_pending[i]) begin
                cpu_int_n = 1'b0;
                if (cpu_int_ack_cycle) begin
                    cpu_data_out = irq_vector[i];
                    cpu_data_oe  = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= '{default: IDLE};
            irq_pending <= '0;
            irq_ius     <= '0;
        end else begin
            for (int i = 0; i < NUM_CHIPS; i++) begin
                if (irq_req[i]) begin
                    irq_pending[i] <= 1'b1;
                end else if (!irq_ius[i]) begin
                    irq_pending[i] <= 1'b0;
                end

                if (cpu_int_ack_cycle) begin
                    if (iei_array[i] && irq_pending[i]) begin
                        irq_pending[i] <= 1'b0;
                        irq_ius[i]     <= 1'b1;
                    end
                end

                if (cpu_m1_fetch_strobe) begin
                    case (state[i])
                        IDLE: begin
                            if (cpu_data_in == 8'hED) begin
                                state[i] <= ED_FETCHED;
                            end
                        end
                        
                        ED_FETCHED: begin
                            if (cpu_data_in == 8'h4D) begin
                                if (iei_array[i] && irq_ius[i]) begin
                                    irq_ius[i] <= 1'b0;
                                end
                                state[i] <= IDLE;
                            end else if (cpu_data_in == 8'hED) begin
                                state[i] <= ED_FETCHED;
                            end else begin
                                state[i] <= IDLE;
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule
