module BKing_Audio (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        sound_latch_wr,
    input  logic [7:0]  sound_latch_din,
    input  logic        sound_stop,
	 output logic [12:0] snd_addr,
    input  logic [7:0]  snd_do,
    output logic [15:0] audio_out
);

    logic [1:0] clk_div;
    logic       audio_cpu_en, clk_ay;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_div <= 2'b00;
        else        clk_div <= clk_div + 2'b01;
    end
    
    assign audio_cpu_en = (clk_div[1:0] == 2'b11);
    assign clk_ay       = clk_div[1];

    logic [15:0] audio_addr;
    logic [7:0]  audio_din, audio_dout;
    logic        audio_mreq_n, audio_iorq_n, audio_rd_n, audio_wr_n, audio_nmi_n, audio_int_n;
    assign snd_addr = audio_addr[12:0];
    logic sel_rom, sel_ram, sel_latch, sel_nmi, sel_ay1, sel_ay2;

    always_comb begin
        sel_rom      = (audio_addr >= 16'h0000 && audio_addr <= 16'h1FFF);
        sel_ram      = (audio_addr >= 16'h4000 && audio_addr <= 16'h43FF);
        sel_ay1      = (audio_addr == 16'h4400 || audio_addr == 16'h4401);
        sel_ay2      = (audio_addr == 16'h4402 || audio_addr == 16'h4403);
        sel_latch = (audio_addr == 16'h4800);
        sel_nmi = (audio_addr == 16'h4802);
    end

    logic ay_bdir, ay_bc1;

    always_comb begin
        ay_bdir = 1'b0;
        ay_bc1  = 1'b0;
        if (!audio_wr_n) begin
            ay_bdir = (sel_ay1 || sel_ay2);
            ay_bc1  = (sel_ay1 || sel_ay2) && !audio_addr[0];
        end else if (!audio_rd_n) begin
            ay_bdir = 1'b0;
            ay_bc1  = (sel_ay1 || sel_ay2) && audio_addr[0];
        end
    end

    logic [7:0] sound_latch;
    logic       nmi_enabled, nmi_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sound_latch <= 8'h00;
            nmi_pending <= 1'b0;
        end else begin
            if (sound_latch_wr) begin
                sound_latch <= sound_latch_din;
                nmi_pending <= 1'b1;
            end else if (audio_cpu_en && !audio_rd_n && sel_latch) begin
                nmi_pending <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nmi_enabled <= 1'b0;
        end else if (audio_cpu_en) begin
            if (!audio_rd_n && sel_nmi) begin
                nmi_enabled <= 1'b0;
            end
            if (!audio_wr_n && sel_nmi) begin
                nmi_enabled <= 1'b1;
            end
        end
    end


    assign audio_nmi_n = !(nmi_pending && nmi_enabled);

    logic [16:0] irq_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_cnt     <= 17'd0;
            audio_int_n <= 1'b1;
        end else if (audio_cpu_en) begin
            if (irq_cnt >= 17'd81919) begin
                irq_cnt     <= 17'd0;
                audio_int_n <= 1'b0;
            end else begin
                irq_cnt <= irq_cnt + 17'd1;
                if (irq_cnt == 17'd4) begin
                    audio_int_n <= 1'b1;
                end
            end
        end
    end

    T80se audio_cpu (
        .RESET_n(rst_n),
        .CLK_n(!clk),
        .CLKEN(audio_cpu_en),
        .WAIT_n(1'b1),
        .INT_n(audio_int_n),
        .NMI_n(audio_nmi_n),
        .BUSRQ_n(1'b1),
        .MREQ_n(audio_mreq_n),
        .IORQ_n(audio_iorq_n),
        .RD_n(audio_rd_n),
        .WR_n(audio_wr_n),
        .A(audio_addr),
        .DI(audio_din),
        .DO(audio_dout)
    );

    logic [7:0] ram_dout;
    spram #(10,8) audio_wram (
        .clock(clk),
        .enable(sel_ram),
        .address(audio_addr[9:0]),
        .data(audio_dout),
        .q(ram_dout),
        .wren(!audio_wr_n && audio_cpu_en)
    );

    logic [7:0] ay1_dout, ay2_dout, ay1_audio_raw, ay2_audio_raw, ay2_port_a_out, ay1_port_b_out;
    logic [1:0] ay1_chan, ay2_chan;

    YM2149 ic6E (
        .I_DA(audio_dout),
        .O_DA(ay1_dout),
        .O_DA_OE_L(),
        .I_A9_L(1'b0),
        .I_A8(1'b1),
        .I_BDIR(ay_bdir && sel_ay1),
        .I_BC2(1'b1),
        .I_BC1(ay_bc1 && sel_ay1),
        .I_SEL_L(1'b1),
        .O_AUDIO(ay1_audio_raw),
        .O_CHAN(ay1_chan),
        .I_IOA(8'hFF),
        .O_IOA(),
        .O_IOA_OE_L(),
        .I_IOB(8'hFF),
		  .O_IOB(ay1_port_b_out),
        .ENA(1),
        .RESET_L(rst_n),
        .CLK(clk_ay)
    );

    YM2149 ic6G (
        .I_DA(audio_dout),
        .O_DA(ay2_dout),
        .O_DA_OE_L(),
        .I_A9_L(1'b0),
        .I_A8(1'b1),
        .I_BDIR(ay_bdir && sel_ay2),
        .I_BC2(1'b1),
        .I_BC1(ay_bc1 && sel_ay2),
        .I_SEL_L(1'b1),
        .O_AUDIO(ay2_audio_raw),
        .O_CHAN(ay2_chan),
        .I_IOA(8'hFF),
        .O_IOA(ay2_port_a_out),
        .O_IOA_OE_L(),
        .I_IOB(8'hFF),
        .ENA(1),
        .RESET_L(rst_n),
        .CLK(clk_ay)
    );

    always_comb begin
        audio_din = 8'hFF;
        if (!audio_rd_n) begin
            unique case (1'b1)
                sel_rom:      audio_din = snd_do;//audio_addr[12] ? rom2_dout : rom1_dout;
                sel_ram:      audio_din = ram_dout;
                sel_ay1:      audio_din = ay1_dout;
                sel_ay2:      audio_din = ay2_dout;
                sel_latch: 	audio_din = sound_latch;
                default:      audio_din = 8'hFF;
            endcase
        end
    end

    logic [7:0] ay1_ch_a, ay1_ch_b, ay1_ch_c, ay2_ch_a, ay2_ch_b, ay2_ch_c;

    always_ff @(posedge clk_ay) begin
        case (ay1_chan)
            2'b00: ay1_ch_a <= ay1_audio_raw;
            2'b01: ay1_ch_b <= ay1_audio_raw;
            2'b10: ay1_ch_c <= ay1_audio_raw;
            default: ;
        endcase
        case (ay2_chan)
            2'b00: ay2_ch_a <= ay2_audio_raw;
            2'b01: ay2_ch_b <= ay2_audio_raw;
            2'b10: ay2_ch_c <= ay2_audio_raw;
            default: ;
        endcase
    end

       logic [15:0] crow_phase;
    logic        crow_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crow_phase <= 16'd0;
            crow_out   <= 1'b0;
        end else if (audio_cpu_en) begin
            if (ay1_port_b_out[5:0] == 6'h3F) begin
                crow_phase <= 16'd0;
                crow_out   <= 1'b0;
            end else begin
                crow_phase <= crow_phase + {4'd0, ~ay1_port_b_out[5:0], 6'd0};
                crow_out   <= crow_phase[15];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (sound_stop) begin
            audio_out <= 16'h0000;
        end else begin
            audio_out <= {5'b00000, ay1_ch_a, 3'b000} + 
                         {5'b00000, ay1_ch_b, 3'b000} + 
                         {5'b00000, ay1_ch_c, 3'b000} + 
                         {5'b00000, ay2_ch_a, 3'b000} + 
                         {5'b00000, ay2_ch_b, 3'b000} + 
                         {5'b00000, ay2_ch_c, 3'b000} + 
                         {7'b0000000, crow_out, 8'h00} +
                         {3'b000, ~ay2_port_a_out, 5'b00000};
        end
    end

endmodule
