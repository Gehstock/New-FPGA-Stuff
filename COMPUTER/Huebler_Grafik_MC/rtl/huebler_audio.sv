module huebler_audio (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tone_on,
    output logic        audio_signal
);

    localparam int TONE_DIV = 7692;

    logic [12:0] tone_cnt;
    logic        tone_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_cnt <= '0;
            tone_q   <= 1'b1;
        end else if (!tone_on) begin
            tone_cnt <= '0;
            tone_q   <= 1'b1;
        end else begin
            if (tone_cnt == TONE_DIV - 1) begin
                tone_cnt <= '0;
                tone_q   <= !tone_q;
            end else begin
                tone_cnt <= tone_cnt + 1'b1;
            end
        end
    end

    assign audio_signal = tone_q;

endmodule
