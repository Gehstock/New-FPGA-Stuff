module skyarmy_audio (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire [15:0] cpu_addr,
    input  wire [7:0]  cpu_data_in,
    output reg  [7:0]  audio_data_out,
    input  wire        cpu_io_rd,
    input  wire        cpu_io_wr,
    output reg  [8:0]  sound_mix_out
);

    reg [3:0] sound_clk_div;
    reg       ay_ce;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sound_clk_div <= 4'd0;
            ay_ce         <= 1'b0;
        end else begin
            if (sound_clk_div >= 4'd11) begin 
                sound_clk_div <= 4'd0;
                ay_ce         <= 1'b1;       
            end else begin
                sound_clk_div <= sound_clk_div + 1'b1;
                ay_ce         <= 1'b0;
            end
        end
    end

    wire [7:0] port_sel      = cpu_addr[7:0];
    wire       port_ay0_addr = (port_sel == 8'h00);
    wire       port_ay0_data = (port_sel == 8'h01);
    wire       port_ay0_read = (port_sel == 8'h02);
    wire       port_ay1_addr = (port_sel == 8'h04);
    wire       port_ay1_data = (port_sel == 8'h05);
    wire       port_ay1_read = (port_sel == 8'h06);

    reg        cpu_io_wr_last;
    reg        cpu_io_rd_last;
    wire       cpu_wr_edge = (cpu_io_wr && !cpu_io_wr_last);
    wire       cpu_rd_edge = (cpu_io_rd && !cpu_io_rd_last);

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cpu_io_wr_last <= 1'b0;
            cpu_io_rd_last <= 1'b0;
        end else begin
            cpu_io_wr_last <= cpu_io_wr;
            cpu_io_rd_last <= cpu_io_rd;
        end
    end
    reg [7:0] s_data;
    reg       req_ay0_addr;
    reg       req_ay0_write;
    reg       req_ay0_read;
    reg       req_ay1_addr;
    reg       req_ay1_write;
    reg       req_ay1_read;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            s_data        <= 8'd0;
            req_ay0_addr  <= 1'b0; req_ay0_write <= 1'b0; req_ay0_read  <= 1'b0;
            req_ay1_addr  <= 1'b0; req_ay1_write <= 1'b0; req_ay1_read  <= 1'b0;
        end else begin
            if (cpu_wr_edge) begin
                s_data <= cpu_data_in;
                if (port_ay0_addr) req_ay0_addr  <= 1'b1;
                if (port_ay0_data) req_ay0_write <= 1'b1;
                if (port_ay1_addr) req_ay1_addr  <= 1'b1;
                if (port_ay1_data) req_ay1_write <= 1'b1;
            end 
            if (cpu_rd_edge) begin
                if (port_ay0_read) req_ay0_read  <= 1'b1;
                if (port_ay1_read) req_ay1_read  <= 1'b1;
            end
            if (ay_ce) begin
                req_ay0_addr  <= 1'b0;
                req_ay0_write <= 1'b0;
                req_ay1_addr  <= 1'b0;
                req_ay1_write <= 1'b0;
                req_ay0_read  <= 1'b0;
                req_ay1_read  <= 1'b0;
            end
        end
    end

    reg s_ay0_bdir, s_ay0_bc1;
    reg s_ay1_bdir, s_ay1_bc1;

    wire req_ay0_code_run = (req_ay0_addr || req_ay0_write || req_ay0_read);
    wire req_ay1_code_run = (req_ay1_addr || req_ay1_write || req_ay1_read);

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            s_ay0_bdir <= 1'b0; s_ay0_bc1 <= 1'b0;
            s_ay1_bdir <= 1'b0; s_ay1_bc1 <= 1'b0;
        end else begin
            if (req_ay0_code_run) begin
                s_ay0_bdir <= (req_ay0_addr || req_ay0_write);
                s_ay0_bc1  <= (req_ay0_addr || req_ay0_read);
            end else if (ay_ce) begin
                s_ay0_bdir <= 1'b0;
                s_ay0_bc1  <= 1'b0;
            end

            if (req_ay1_code_run) begin
                s_ay1_bdir <= (req_ay1_addr || req_ay1_write);
                s_ay1_bc1  <= (req_ay1_addr || req_ay1_read);
            end else if (ay_ce) begin
                s_ay1_bdir <= 1'b0;
                s_ay1_bc1  <= 1'b0;
            end
        end
    end
    wire [7:0] ay0_data_out;
    wire [9:0] ay0_audio;
    wire [7:0] zero_byte = 8'h00;

    YM2149 u_ay0 (
        .I_DA          (s_data),
        .O_DA          (ay0_data_out),
        .O_DA_OE_L     (),
        .I_A9_L        (1'b0),
        .I_A8          (1'b1),
        .I_BDIR        (s_ay0_bdir),
        .I_BC2         (1'b1),
        .I_BC1         (s_ay0_bc1),
        .I_SEL_L       (1'b1),
        .I_STEREO      (1'b0),
        .O_AUDIO       (),
        .O_CHAN        (),
        .O_AUDIO_L     (ay0_audio),
        .O_AUDIO_R     (),
        .I_IOA         (zero_byte),
        .O_IOA         (),
        .O_IOA_OE_L    (),
        .I_IOB         (zero_byte),
        .O_IOB         (),
        .O_IOB_OE_L    (),
        .ENA           (ay_ce),
        .RESET_L       (rst_n),
        .CLK           (clk_sys)
    );

    wire [7:0] ay1_data_out;
    wire [9:0] ay1_audio;

    YM2149 u_ay1 (
        .I_DA          (s_data),
        .O_DA          (ay1_data_out),
        .O_DA_OE_L     (),
        .I_A9_L        (1'b0),
        .I_A8          (1'b1),
        .I_BDIR        (s_ay1_bdir),
        .I_BC2         (1'b1),
        .I_BC1         (s_ay1_bc1),
        .I_SEL_L       (1'b1),
        .I_STEREO      (1'b0),
        .O_AUDIO       (),
        .O_CHAN        (),
        .O_AUDIO_L     (ay1_audio),
        .O_AUDIO_R     (),
        .I_IOA         (zero_byte),
        .O_IOA         (),
        .O_IOA_OE_L    (),
        .I_IOB         (zero_byte),
        .O_IOB         (),
        .O_IOB_OE_L    (),
        .ENA           (ay_ce),
        .RESET_L       (rst_n),
        .CLK           (clk_sys)
    );

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            audio_data_out <= 8'hFF;
        end else begin
            if (cpu_io_rd && port_ay0_read)
                audio_data_out <= ay0_data_out;
            else if (cpu_io_rd && port_ay1_read)
                audio_data_out <= ay1_data_out;
            else
                audio_data_out <= 8'hFF;
        end
    end

    wire [10:0] full_sum = ay0_audio + ay1_audio;
    reg [10:0] balanced_sum;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            balanced_sum <= 11'd0;
        end else begin
            balanced_sum <= full_sum - 11'd1024;
        end
    end

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sound_mix_out <= 9'd0;
        end else begin
            sound_mix_out <= balanced_sum[10:2]; 
        end
    end

endmodule
