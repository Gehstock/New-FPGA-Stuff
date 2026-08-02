`default_nettype none

module cocoloco_audio (
    input  wire        clk,
    input  wire        clk_snd_en,
    input  wire        reset,
    input  wire        psg_rd,
    input  wire        psg_wr,
    input  wire        psg_ad,
    input  wire [7:0]  dsw1,
    input  wire [7:0]  dsw2,
    
    input  wire [7:0]  data_in,
    output wire [7:0]  data_out,
    output reg  [9:0]  audio_out
);

    reg psg_bc;
    reg psg_bdir;

    always_comb begin
        psg_bc   = 1'b0;
        psg_bdir = 1'b0;
        
        if (psg_ad) begin
            psg_bc   = 1'b1; 
            psg_bdir = 1'b1;
        end else if (psg_wr) begin
            psg_bc   = 1'b0; 
            psg_bdir = 1'b1;
        end else if (psg_rd) begin
            psg_bc   = 1'b1; 
            psg_bdir = 1'b0;
        end
    end


    wire [7:0] ch_a;
    wire [7:0] ch_b;
    wire [7:0] ch_c;

    ym2149 sound_chip (
        .CLK       (clk),
        .CE        (clk_snd_en),
        .RESET     (reset),
        .BDIR      (psg_bdir),
        .BC        (psg_bc),
        .DI        (data_in),
        .DO        (data_out),
        .CHANNEL_A (ch_a),
        .CHANNEL_B (ch_b),
        .CHANNEL_C (ch_c),
        .SEL       (1'b1),
        .MODE      (1'b0),
        .ACTIVE    (),
        .IOA_in    (dsw1), 
        .IOA_out   (),
        .IOB_in    (dsw2), 
        .IOB_out   ()
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            audio_out <= 10'd0;
        end else begin
            audio_out <= ({2'b00, ch_a} + {2'b00, ch_b} + {2'b00, ch_c});
        end
    end

endmodule
