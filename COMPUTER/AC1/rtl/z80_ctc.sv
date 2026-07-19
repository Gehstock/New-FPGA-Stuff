//Gehstock 2024
`timescale 1ns / 1ps
`default_nettype none

module z80_ctc (
    input  logic        clk,          
    input  logic        clken,
    input  logic        reset_n,      

    input  logic [1:0]  cs,           
    input  logic        ce_n,         
    input  logic        iorq_n,       
    input  logic        rd_n,         
    input  logic [7:0]  din,          
    output logic [7:0]  dout,         
    output logic        dout_en,      

    input  logic [3:0]  clk_trg,      
    output logic [2:0]  zc_to,        

    input  logic        iei,          
    output logic        ieo,          
    output logic        int_n         
);

    logic [7:0] interrupt_vector;     
    logic       int_vector_loaded;    

    typedef struct packed {
        logic       interrupt_enable; 
        logic       mode;             
        logic       prescaler_range;  
        logic       slope;            
        logic       trigger;          
        logic       load_time_const;  
        logic       sw_reset;         
        logic       control_word_sel; 
    } ctc_channel_ctrl_t;

    ctc_channel_ctrl_t [3:0] channel_control;

    logic [7:0] time_constant [3:0];  
    logic [7:0] down_counter  [3:0];  
    logic [7:0] prescaler     [3:0];  
    
    logic [3:0] expect_time_constant; 
    logic [3:0] channel_running;      
    logic [3:0] zc_to_reg;            
    logic [3:0] interrupt_pending;    

    logic [3:0] clk_trg_sync0, clk_trg_sync1, clk_trg_last;
    logic [3:0] clk_trg_edge;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            clk_trg_sync0 <= 4'b0;
            clk_trg_sync1 <= 4'b0;
            clk_trg_last  <= 4'b0;
        end else begin
            clk_trg_sync0 <= clk_trg;
            clk_trg_sync1 <= clk_trg_sync0;
            clk_trg_last  <= clk_trg_sync1;
        end
    end

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            if (channel_control[i].slope) 
                clk_trg_edge[i] = (clk_trg_sync1[i] && !clk_trg_last[i]);
            else                          
                clk_trg_edge[i] = (!clk_trg_sync1[i] && clk_trg_last[i]);
        end
    end

    logic bus_write;
    logic bus_read;

    assign bus_write = (!iorq_n) && (!ce_n) && (rd_n);  
    assign bus_read  = (!iorq_n) && (!ce_n) && (!rd_n); 

    assign dout_en = bus_read;
    assign zc_to   = zc_to_reg[2:0];

    always_comb begin
        dout = 8'hFF;
        if (bus_read) begin
            dout = down_counter[cs];
        end 
        else if (!iorq_n && !rd_n) begin
            if (iei && int_vector_loaded && (interrupt_pending != 4'b0000)) begin
                if      (interrupt_pending[0]) dout = {interrupt_vector[7:3], 3'b000};
                else if (interrupt_pending[1]) dout = {interrupt_vector[7:3], 3'b010};
                else if (interrupt_pending[2]) dout = {interrupt_vector[7:3], 3'b100};
                else if (interrupt_pending[3]) dout = {interrupt_vector[7:3], 3'b110};
            end
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            interrupt_vector      <= 8'h00;
            int_vector_loaded     <= 1'b0;
            expect_time_constant  <= 4'b0000;
            channel_running       <= 4'b0000;
            zc_to_reg             <= 4'b0000;
            interrupt_pending     <= 4'b0000;

            for (int i = 0; i < 4; i++) begin
                channel_control[i] <= 8'h01; 
                time_constant[i]   <= 8'h00;
                down_counter[i]    <= 8'h00;
                prescaler[i]       <= 8'h00;
            end
        end else begin
            zc_to_reg <= 4'b0000;

            if (bus_write) begin
                if (expect_time_constant[cs]) begin
                    time_constant[cs] <= din;
                    expect_time_constant[cs] <= 1'b0;
                    down_counter[cs] <= (din == 8'h00) ? 8'd0 : din;
                    prescaler[cs]    <= 8'h00;
                    
                    if (channel_control[cs].mode == 1'b0 && channel_control[cs].trigger == 1'b0) begin
                        channel_running[cs] <= 1'b1;
                    end else if (channel_control[cs].mode == 1'b1) begin
                        channel_running[cs] <= 1'b1; 
                    end
                end 
                else if (din[0] == 1'b0) begin
                    if (cs == 2'b00) begin
                        interrupt_vector  <= din;
                        int_vector_loaded <= 1'b1;
                    end
                end 
                else begin
                    channel_control[cs].interrupt_enable <= din[7];
                    channel_control[cs].mode             <= din[6];
                    channel_control[cs].prescaler_range  <= din[5];
                    channel_control[cs].slope            <= din[4];
                    channel_control[cs].trigger          <= din[3];
                    channel_control[cs].load_time_const  <= din[2];
                    channel_control[cs].sw_reset         <= din[1];
                    channel_control[cs].control_word_sel <= din[0];

                    if (din[1]) begin
                        channel_running[cs]      <= 1'b0;
                        interrupt_pending[cs]   <= 1'b0;
                        expect_time_constant[cs] <= 1'b0;
                    end else begin
                        expect_time_constant[cs] <= din[2];
                    end
                end
            end

            for (int i = 0; i < 4; i++) begin
                if (channel_running[i]) begin
                    if (channel_control[i].mode == 1'b0) begin
                        if (channel_control[i].trigger && !channel_running[i]) begin
                            if (clk_trg_edge[i]) begin
                                channel_running[i] <= 1'b1;
                            end
                        end 
                        else begin
                            logic [7:0] max_prescale;
                            max_prescale = channel_control[i].prescaler_range ? 8'd255 : 8'd15;

                            // Modifikation: Prescaler reagiert jetzt exakt auf das 2,5 MHz Systemzeit-Raster
                            if (clken) begin
                                if (prescaler[i] >= max_prescale) begin
                                    prescaler[i] <= 8'h00;
                                    if (down_counter[i] <= 8'd1) begin
                                        down_counter[i] <= (time_constant[i] == 8'h00) ? 8'd0 : time_constant[i];
                                        zc_to_reg[i]    <= 1'b1; 
                                        if (channel_control[i].interrupt_enable)
                                            interrupt_pending[i] <= 1'b1; 
                                    end else begin
                                        down_counter[i] <= down_counter[i] - 1'b1;
                                    end
                                end else begin
                                    prescaler[i] <= prescaler[i] + 1'b1;
                                end
                            end
                        end
                    end
                    else begin
                        if (clk_trg_edge[i]) begin
                            if (down_counter[i] <= 8'd1) begin
                                down_counter[i] <= (time_constant[i] == 8'h00) ? 8'd0 : time_constant[i];
                                zc_to_reg[i]    <= 1'b1; 
                                if (channel_control[i].interrupt_enable)
                                    interrupt_pending[i] <= 1'b1;
                            end else begin
                                down_counter[i] <= down_counter[i] - 1'b1;
                            end
                        end
                    end
                end
            end
            
            if (!iorq_n && !rd_n && iei) begin
                 if      (interrupt_pending[0]) interrupt_pending[0] <= 1'b0;
                 else if (interrupt_pending[1]) interrupt_pending[1] <= 1'b0;
                 else if (interrupt_pending[2]) interrupt_pending[2] <= 1'b0;
                 else if (interrupt_pending[3]) interrupt_pending[3] <= 1'b0;
            end
        end
    end

    assign ieo = iei && (interrupt_pending == 4'b0000);
    assign int_n = (iei && (interrupt_pending != 4'b0000)) ? 1'b0 : 1'b1;

endmodule
`default_nettype wire
