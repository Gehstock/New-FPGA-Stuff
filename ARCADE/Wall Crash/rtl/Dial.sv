module Dial #(
    parameter int   DIV_BITS = 16,
    parameter [7:0] MIN_VAL  = 8'h00,
    parameter [7:0] MAX_VAL  = 8'hFF
) (
    input  logic       clk12,
    input  logic       rst_n,
    input  logic       m_left,
    input  logic       m_right,
    input  logic [7:0] joystick_0,
    output logic [7:0] paddle_reg
);

    logic [DIV_BITS-1:0] paddle_speed_div;

    always_ff @(posedge clk12 or negedge rst_n) begin
        if (!rst_n) begin
            paddle_reg       <= 8'h80;
            paddle_speed_div <= '0;
        end else begin
            paddle_speed_div <= paddle_speed_div + 1'b1;

            if (paddle_speed_div == '0) begin
                if ((m_left || joystick_0[2]) && (paddle_reg < MAX_VAL)) begin
                    paddle_reg <= paddle_reg + 1'b1;
                end
                if ((m_right || joystick_0[3]) && (paddle_reg > MIN_VAL)) begin
                    paddle_reg <= paddle_reg - 1'b1;
                end
            end
        end
    end

endmodule

