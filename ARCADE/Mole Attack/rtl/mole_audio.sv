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

    logic [7:0] ay_data_out;
    logic       ay_bdir;
    logic       ay_bc1;
    logic [7:0] ay_data_in;

    assign sound_ack = (cpu_addr == 16'h8C00 || cpu_addr == 16'h8C01);

    always_comb begin
        ay_bdir = 1'b0;
        ay_bc1  = 1'b0;
        if (sound_ack && cpu_en) begin
            if (!cpu_rw_n) begin
                if (cpu_addr[0] == 1'b0) begin
                    ay_bdir = 1'b1;
                    ay_bc1  = 1'b1;
                end else begin
                    ay_bdir = 1'b1;
                    ay_bc1  = 1'b0;
                end
            end else begin
                if (cpu_addr[0] == 1'b1) begin
                    ay_bdir = 1'b0;
                    ay_bc1  = 1'b1;
                end
            end
        end
    end

    assign ay_data_in = (!cpu_rw_n) ? cpu_dout : 8'hFF;

    reg [7:0] sound_dout_reg;
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sound_dout_reg <= 8'hFF;
        end else if (sound_ack && cpu_rw_n) begin
            sound_dout_reg <= ay_data_out;
        end else begin
            sound_dout_reg <= 8'hFF;
        end
    end
    assign sound_dout = sound_dout_reg;

    YM2149 psg_core (
        .CLK       (clk_sys),
        .ENA       (cpu_en),
        .RESET_L   (rst_n),
        .I_DA      (ay_data_in),
        .O_DA      (ay_data_out),
        .O_DA_OE_L (),
        .I_A9_L    (1'b0),
        .I_A8      (1'b1),
        .I_BDIR    (ay_bdir),
        .I_BC2     (1'b1),
        .I_BC1     (ay_bc1),
        .I_SEL_L   (1'b1),
        .I_STEREO  (1'b0),
        .O_AUDIO_L (audio),
        .O_AUDIO_R (),
        .O_AUDIO   (),
        .O_CHAN    (),
        .I_IOA     (8'hFF),
        .O_IOA     (),
        .O_IOA_OE_L(),
        .I_IOB     (8'hFF),
        .O_IOB     (),
        .O_IOB_OE_L()
    );

endmodule
