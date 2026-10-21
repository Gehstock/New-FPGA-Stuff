module mole_audio (
    input  logic        clk_sys,
    input  logic        rst_n,
    input  logic        cpu_en,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_dout,
    input  logic        cpu_rw_n,
    
    output logic [7:0]  sound_dout,
    output logic        sound_ack,
    output logic [9:0]  audio
);

    logic is_ay_zone;
    assign is_ay_zone = (cpu_addr == 16'h8C00 || cpu_addr == 16'h8C01);
    assign sound_ack  = is_ay_zone;
    logic [3:0] current_reg, next_reg;
    assign next_reg = (is_ay_zone && cpu_addr[0] && !cpu_rw_n) ? cpu_dout[3:0] : current_reg;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            current_reg <= 4'd0;
        end else if (cpu_en && !cpu_rw_n && is_ay_zone && cpu_addr[0]) begin
            current_reg <= cpu_dout[3:0];
        end
    end

    logic [3:0] clk_2mhz_div;
    logic       jt49_clk_en;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_2mhz_div <= 4'd0;
            jt49_clk_en  <= 1'b0;
        end else begin
            if (clk_2mhz_div == 4'd9) begin
                clk_2mhz_div <= 4'd0;
            end else begin
                clk_2mhz_div <= clk_2mhz_div + 4'd1;
            end
            jt49_clk_en <= (clk_2mhz_div == 4'd0);
        end
    end

    logic cs_n, wr_n;
    always_comb begin
        cs_n = 1'b1;
        wr_n = 1'b1;
        if (is_ay_zone && !cpu_addr[0]) begin
            cs_n = 1'b0;
            wr_n = cpu_rw_n;
        end
    end

    logic [7:0] jt49_dout;
    assign sound_dout = (is_ay_zone && cpu_rw_n) ? jt49_dout : 8'hFF;

    jt49 u_jt49 (
        .rst_n      (rst_n),
        .clk        (clk_sys),
        .clk_en     (jt49_clk_en),  
        .addr       (next_reg),
        .cs_n       (cs_n),
        .wr_n       (wr_n),         
        .din        (cpu_dout),     
        .dout       (jt49_dout),    
        .sel        (1'b1),         
        .sound      (audio),
        .A(), .B(), .C(), .sample(),
        .IOA_in(8'hFF), .IOA_out(), .IOA_oe(),
        .IOB_in(8'hFF), .IOB_out(), .IOB_oe()
    );

endmodule

