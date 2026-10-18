module warlords_sound (
    input  logic        Clk12,
    input  logic        Phi0,
    input  logic        Reset,
    input  logic [3:0]  Addr,
    input  logic [7:0]  Din,
    input  logic        Pokey_WRn,
    input  logic        Pokey_CSn, 
    output logic [7:0]  PokeyDout,
    input  logic [3:0]  JoyLeft,
    input  logic [3:0]  JoyRight,
    output logic [5:0]  Audio
);

    logic [3:0] Ch0, Ch1, Ch2, Ch3;   
    logic [7:0] PaddleBus, PaddleReg;
    logic       Potreset;
    logic [16:0] Speeddiv;
    logic [3:0][7:0] Paddlepos; 
    logic [7:0] Chargetimer;
    logic       Scanactive;

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            Speeddiv <= '0;
        end else if (Phi0) begin
            Speeddiv <= Speeddiv + 1'b1;
        end
    end

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            Paddlepos[0] <= 8'd114;
            Paddlepos[1] <= 8'd114;
            Paddlepos[2] <= 8'd114;
            Paddlepos[3] <= 8'd114;
        end else if (Speeddiv == '0) begin
            for (int i = 0; i < 4; i++) begin
                if (JoyLeft[i] && Paddlepos[i] > 8'd0) begin
                    Paddlepos[i] <= Paddlepos[i] - 1'b1;
                end else if (JoyRight[i] && Paddlepos[i] < 8'd228) begin
                    Paddlepos[i] <= Paddlepos[i] + 1'b1;
                end
            end
        end
    end

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            Chargetimer <= '0;
            Scanactive  <= 1'b0;
        end else if (Phi0) begin
            if (Potreset) begin
                Chargetimer <= '0;
                Scanactive  <= 1'b1;
            end else if (Scanactive) begin
                if (Chargetimer < 8'd228) begin
                    Chargetimer <= Chargetimer + 1'b1;
                end else begin
                    Scanactive  <= 1'b0;
                end
            end
        end
    end

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            PaddleReg <= 8'h00;
        end else if (Phi0) begin
            if (Potreset) begin
                PaddleReg <= 8'h00;
            end else begin
                PaddleReg[7:4] <= 4'hF; 
                for (int i = 0; i < 4; i++) begin
                    if (Scanactive && (Chargetimer >= Paddlepos[i])) begin
                        PaddleReg[i] <= 1'b1;
                    end
                end
            end
        end
    end

    assign PaddleBus = PaddleReg;

    POKEY Pokey ( 
        .CLK            		( Clk12 ),
        .ENABLE_179     		( Phi0 ),
        .ADDR           		( Addr ),
        .DATA_IN        		( Din ),
        .WR_EN          		( !Pokey_CSn && !Pokey_WRn ),
        .RESET_N        		( !Reset ),
        .POT_IN         		( PaddleBus ),
        .DATA_OUT       		( PokeyDout ),
        .CHANNEL_0_OUT  		( Ch0 ),
        .CHANNEL_1_OUT  		( Ch1 ),
        .CHANNEL_2_OUT  		( Ch2 ),
        .CHANNEL_3_OUT  		( Ch3 ),
        .POT_RESET      		( Potreset ),
        .keyboard_scan_enable ( 1'b0 ),
        .keyboard_scan        ( ),
        .keyboard_response    ( 2'b00 ),
        .SIO_IN1              ( 1'b1 ),
        .SIO_IN2              ( 1'b1 ),
        .SIO_IN3              ( 1'b1 )
    );

    assign Audio = ( 6'(Ch0) + 6'(Ch1) + 6'(Ch2) + 6'(Ch3) ) >> 1;

endmodule
