module nitedrvr_bus (
    input  wire         clk_sys,
    input  wire         rst_n,
    input  wire  [23:0] cpu_a,
    input  wire   [7:0] cpu_di,
    output reg    [7:0] cpu_do,
    input  wire         cpu_rw_n,
    input  wire         cpu_ce,
    input  wire         v_blank,
    input  wire         dip_service,
    input  wire         gear1,
    input  wire         gear2,
    input  wire         gear3,
    input  wire         gear4,
    input  wire         steer_moved,
    input  wire         steer_dir,
    input  wire   [7:0] IN0,
    output reg          hvc_we,
    output wire   [3:0] hvc_addr,
    output wire   [7:0] hvc_data,
    input  wire   [7:0] pfw_data,
    output reg          pfw_we,
    input  wire   [7:0] scram_data,
    output reg          scram_we,
    input  wire   [7:0] rom1_data,
    input  wire   [7:0] rom2_data,
    output reg          steer_clear
);

    wire [15:0] addr = cpu_a[15:0];
    assign hvc_addr = addr[3:0];
    assign hvc_data = cpu_di;
    wire coin1_n  = IN0[0];
    wire coin2_n  = IN0[1];
    wire start1_n = IN0[2];
    wire gas_n    = IN0[3];
    wire novice   = IN0[4];
    wire expert   = IN0[5];

    reg [1:0] ac_line;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            ac_line <= 2'd0;
        else if (cpu_ce && cpu_rw_n && addr >= 16'h0800 && addr <= 16'h09FF)
            ac_line <= (ac_line == 2'd2) ? 2'd0 : ac_line + 1'b1;
    end

    always @(*) begin
        scram_we    = 1'b0;
        pfw_we      = 1'b0;
        hvc_we      = 1'b0;
        steer_clear = 1'b0;
        cpu_do      = 8'hFF;

        if (addr <= 16'h01FF) begin
            cpu_do   = scram_data;
            scram_we = !cpu_rw_n;
        end
        else if (addr >= 16'h0200 && addr <= 16'h03FF) begin
            cpu_do = pfw_data;
            pfw_we = !cpu_rw_n;
        end
        else if (addr >= 16'h0400 && addr <= 16'h05FF) begin
            if (addr[5:4] != 2'b11)
                hvc_we = !cpu_rw_n;
        end
        else if (addr >= 16'h0600 && addr <= 16'h07FF) begin
            case (addr[1:0])
                0: begin
                    cpu_do = 8'b1001_0000;
                end
                1: begin
                    cpu_do = {~dip_service, v_blank, 1'b1, 1'b0, 4'b0000};
                end
                2: begin
                    if (gear1)      cpu_do = 8'he0;
                    else if (gear2) cpu_do = 8'hd0;
                    else if (gear3) cpu_do = 8'hb0;
                    else            cpu_do = 8'h70; // gear4
                end
                3: begin
                    cpu_do = {steer_moved, steer_dir, 6'b000000};
                end
            endcase
        end
        else if (addr >= 16'h0800 && addr <= 16'h09FF) begin
            case (addr[2:0])
                3'd0: cpu_do = {coin1_n,  7'b0000000}; // COIN1
                3'd1: cpu_do = {coin2_n,  7'b0000000}; // COIN2
                3'd2: cpu_do = {start1_n, 7'b0000000}; // START
                3'd3: cpu_do = {gas_n,    7'b0000000}; // ACC/GAS
                3'd4: cpu_do = expert ? 8'h80 : 8'h00; // EXPERT track
                3'd5: cpu_do = novice ? 8'h80 : 8'h00; // NOVICE track
                3'd6: cpu_do = (ac_line == 2'd0) ? 8'h80 : 8'h00; // alt signal
                3'd7: cpu_do = 8'h00; 
                default: cpu_do = 8'hFF;
            endcase
        end
        else if (addr >= 16'h8400 && addr <= 16'h87FF) begin
            cpu_do = 8'h00;
            if (cpu_ce) steer_clear = 1'b1;
        end
        else if (addr >= 16'h9000 && addr <= 16'h97FF) begin
            cpu_do = rom1_data;
        end
        else if ((addr >= 16'h9800 && addr <= 16'h9FFF) || (addr >= 16'hFFF0)) begin
            cpu_do = rom2_data;
        end
    end

endmodule
