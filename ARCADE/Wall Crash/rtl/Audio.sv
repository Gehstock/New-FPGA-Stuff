module Audio (
    input  logic       clk_sys,
    input  logic       reset,
    input  logic       ce_ay,

    input  logic       ay_cs,
    input  logic       ay_addr_w,
    input  logic       ay_data_w,
    input  logic       ay_data_r,
    input  logic [7:0] din,
    output logic [7:0] dout,
    input  logic [7:0] dsw2,

    output logic [9:0] audio
);

    logic ym_bdir, ym_bc1;
    assign ym_bdir = ay_cs && (ay_addr_w || ay_data_w);
    assign ym_bc1  = ay_cs && (ay_addr_w || ay_data_r);

    YM2149 #(
        .MIXER_VOLTABLE (1'b0),
        .IO_OUT_READ_IN (1'b1)
    ) ay_inst (
        .I_DA       (din),
        .O_DA       (dout),
        .O_DA_OE_L  (),
        .I_A9_L     (1'b0),
        .I_A8       (1'b1),
        .I_BDIR     (ym_bdir),
        .I_BC2      (1'b1),
        .I_BC1      (ym_bc1),
        .I_SEL_L    (1'b0),
        .I_STEREO   (1'b0),
        .O_AUDIO    (),
        .O_CHAN     (),
        .O_AUDIO_L  (audio),
        .I_IOA      (dsw2),
        .O_IOA      (),
        .O_IOA_OE_L (),
        .I_IOB      (8'hFF),
        .O_IOB      (),
        .O_IOB_OE_L (),
        .ENA        (ce_ay),
        .RESET_L    (~reset),
        .CLK        (clk_sys)
    );

endmodule
