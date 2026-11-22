module Sub_Audio (
    input  logic        clk_sys,
    input  logic        ce_cpu,
    input  logic        ce_sound,
    input  logic        reset,
    output logic [12:0] srom_addr,
    input  logic [7:0]  srom_data,
    input  logic        m_iorq_n,
    input  logic        m_wr_n,
    input  logic        m_rd_n,
    input  logic [7:0]  m_addr,
    input  logic [7:0]  m_data_out,
    output logic [7:0]  m_data_in,
    output logic [9:0]  audio
);

    logic        m_cs_00;
    logic        m_wr_active;
    logic        m_rd_active;

    logic [15:0] s_addr;
    logic [7:0]  s_data_out;
    logic [7:0]  s_data_in;
    logic        s_mreq_n;
    logic        s_iorq_n;
    logic        s_rd_n;
    logic        s_wr_n;

    logic        s_cs_00;
    logic        s_rd_active;
    logic        s_wr_active;

    logic        m_wr_d1, m_rd_d1;
    logic        s_wr_d1, s_rd_d1;

    logic        m_latch0_wr;
    logic        m_latch1_rd;
    logic        s_latch1_wr;
    logic        s_latch0_rd;

    logic [7:0]  soundlatch_0;
    logic [7:0]  soundlatch_1;
    logic        latch0_pending;
    logic        latch1_pending;
    logic        s_int_n;

    logic        m_nmi_sub_mask;
    logic [13:0] nmi_counter;
    logic        sub_nmi_n;
    logic        nmi_trigger;

    logic [7:0]  s_wram_data;
    logic [7:0]  ay1_da_out;
    logic [7:0]  ay2_da_out;
    logic        sound_ram_we;

    logic        ay1_data_rd;
    logic        ay2_data_rd;
    logic        ay1_addr_wr;
    logic        ay1_data_wr;
    logic        ay2_addr_wr;
    logic        ay2_data_wr;

    logic [7:0]  ay_latched_data;
    logic        ay1_bdir_r, ay1_bc1_r;
    logic        ay2_bdir_r, ay2_bc1_r;
    logic        ay_wr_pending;
    logic        ay_any_wr;

    logic [9:0]  ay1_audio_l;
    logic [9:0]  ay2_audio_l;
    logic [10:0] final_opamp_mix;

    always_comb begin
        m_cs_00      = (~m_iorq_n && (m_addr[7:0] == 8'h00));
        m_wr_active  = m_cs_00 && ~m_wr_n;
        m_rd_active  = m_cs_00 && ~m_rd_n;

        s_cs_00      = (~s_iorq_n && (s_addr[7:0] == 8'h00));
        s_rd_active  = s_cs_00 && ~s_rd_n;
        s_wr_active  = s_cs_00 && ~s_wr_n;

        m_latch0_wr  = ce_cpu &&  m_wr_active && !m_wr_d1;
        m_latch1_rd  = ce_cpu && !m_rd_active &&  m_rd_d1;
        s_latch1_wr  = ce_cpu &&  s_wr_active && !s_wr_d1;
        s_latch0_rd  = ce_cpu && !s_rd_active &&  s_rd_d1;

        s_int_n      = ~latch0_pending;
        m_data_in    = soundlatch_1;
        srom_addr    = s_addr[12:0];
        sound_ram_we = ~s_mreq_n && ~s_wr_n && (s_addr >= 16'h4000 && s_addr <= 16'h47FF);

        ay1_data_rd  = (~s_iorq_n && ~s_rd_n && (s_addr[7:0] == 8'h40 || s_addr[7:0] == 8'h41));
        ay2_data_rd  = (~s_iorq_n && ~s_rd_n && (s_addr[7:0] == 8'h80 || s_addr[7:0] == 8'h81));
        ay1_addr_wr  = (~s_iorq_n && ~s_wr_n && (s_addr[7:0] == 8'h40));
        ay1_data_wr  = (~s_iorq_n && ~s_wr_n && (s_addr[7:0] == 8'h41));
        ay2_addr_wr  = (~s_iorq_n && ~s_wr_n && (s_addr[7:0] == 8'h80));
        ay2_data_wr  = (~s_iorq_n && ~s_wr_n && (s_addr[7:0] == 8'h81));
        ay_any_wr    = ce_cpu && (ay1_addr_wr || ay1_data_wr || ay2_addr_wr || ay2_data_wr);

        audio        = final_opamp_mix[10:1];

        if (~s_mreq_n && ~s_rd_n) begin
            if (s_addr <= 16'h3FFF)
                s_data_in = srom_data;
            else if (s_addr >= 16'h4000 && s_addr <= 16'h47FF)
                s_data_in = s_wram_data;
            else
                s_data_in = 8'hFF;
        end else if (~s_iorq_n && ~s_rd_n) begin
            case (s_addr[7:0])
                8'h00:        s_data_in = soundlatch_0;
                8'h40, 8'h41: s_data_in = ay1_da_out;
                8'h80, 8'h81: s_data_in = ay2_da_out;
                default:      s_data_in = 8'hFF;
            endcase
        end else begin
            s_data_in = 8'hFF;
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            m_wr_d1 <= 1'b0;
            m_rd_d1 <= 1'b0;
            s_wr_d1 <= 1'b0;
            s_rd_d1 <= 1'b0;
        end else if (ce_cpu) begin
            m_wr_d1 <= m_wr_active;
            m_rd_d1 <= m_rd_active;
            s_wr_d1 <= s_wr_active;
            s_rd_d1 <= s_rd_active;
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            soundlatch_0   <= 8'h00;
            latch0_pending <= 1'b0;
        end else begin
            if (m_latch0_wr) begin
                soundlatch_0   <= m_data_out;
                latch0_pending <= 1'b1;
            end else if (s_latch0_rd) begin
                latch0_pending <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            soundlatch_1   <= 8'h00;
            latch1_pending <= 1'b0;
        end else begin
            if (s_latch1_wr) begin
                soundlatch_1   <= s_data_out;
                latch1_pending <= 1'b1;
            end else if (m_latch1_rd) begin
                latch1_pending <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            m_nmi_sub_mask <= 1'b0;
        end else if (ce_cpu && !s_mreq_n && !s_wr_n && (s_addr == 16'h6000)) begin
            m_nmi_sub_mask <= s_data_out[0];
        end
    end

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            nmi_counter <= 14'd0;
            nmi_trigger <= 1'b0;
            sub_nmi_n   <= 1'b1;
        end else begin
            if (!m_nmi_sub_mask) begin
                nmi_counter <= 14'd0;
                nmi_trigger <= 1'b0;
                sub_nmi_n   <= 1'b1;
            end else begin
                if (ce_sound) begin
                    if (nmi_counter == 14'd12799) begin
                        nmi_counter <= 14'd0;
                        nmi_trigger <= 1'b1;
                    end else begin
                        nmi_counter <= nmi_counter + 14'd1;
                    end
                end

                if (ce_cpu) begin
                    if (nmi_trigger) begin
                        sub_nmi_n   <= 1'b0;
                        nmi_trigger <= 1'b0;
                    end else begin
                        sub_nmi_n   <= 1'b1;
                    end
                end
            end
        end
    end

    T80se sound_cpu_inst (
        .RESET_n(~reset),
        .CLK_n  (clk_sys),
        .CLKEN  (ce_cpu),
        .WAIT_n (1'b1),
        .INT_n  (s_int_n),
        .NMI_n  (sub_nmi_n),
        .BUSRQ_n(1'b1),
        .MREQ_n (s_mreq_n),
        .IORQ_n (s_iorq_n),
        .RD_n   (s_rd_n),
        .WR_n   (s_wr_n),
        .A      (s_addr),
        .DI     (s_data_in),
        .DO     (s_data_out)
    );

    spram #(11) sound_ram_inst (
        .clk   (clk_sys),
        .enable(1'b1),
        .we    (sound_ram_we),
        .addr  (s_addr[10:0]),
        .din   (s_data_out),
        .dout  (s_wram_data)
    );

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            ay_latched_data <= 8'h00;
            ay1_bdir_r      <= 1'b0;
            ay1_bc1_r       <= 1'b0;
            ay2_bdir_r      <= 1'b0;
            ay2_bc1_r       <= 1'b0;
            ay_wr_pending   <= 1'b0;
        end else begin
            if (ay_any_wr) begin
                ay_latched_data <= s_data_out;
                ay1_bdir_r      <= ay1_addr_wr || ay1_data_wr;
                ay1_bc1_r       <= ay1_addr_wr;
                ay2_bdir_r      <= ay2_addr_wr || ay2_data_wr;
                ay2_bc1_r       <= ay2_addr_wr;
                ay_wr_pending   <= 1'b1;
            end else if (ce_sound) begin
                if (ay_wr_pending) begin
                    ay_wr_pending <= 1'b0;
                end else begin
                    ay1_bdir_r    <= 1'b0;
                    ay1_bc1_r     <= 1'b0;
                    ay2_bdir_r    <= 1'b0;
                    ay2_bc1_r     <= 1'b0;
                end
            end
        end
    end

    YM2149 psg1_inst (
        .CLK       (clk_sys),
        .ENA       (ce_sound),
        .RESET_L   (~reset),
        .I_DA      (ay_latched_data),
        .O_DA      (ay1_da_out),
        .O_DA_OE_L (),
        .I_A9_L    (1'b0),
        .I_A8      (1'b1),
        .I_BDIR    (ay1_bdir_r),
        .I_BC2     (1'b1),
        .I_BC1     (ay1_bc1_r | ay1_data_rd),
        .I_SEL_L   (1'b0),
        .I_STEREO  (1'b0),
        .O_AUDIO_L (ay1_audio_l),
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

    YM2149 psg2_inst (
        .CLK       (clk_sys),
        .ENA       (ce_sound),
        .RESET_L   (~reset),
        .I_DA      (ay_latched_data),
        .O_DA      (ay2_da_out),
        .O_DA_OE_L (),
        .I_A9_L    (1'b0),
        .I_A8      (1'b1),
        .I_BDIR    (ay2_bdir_r),
        .I_BC2     (1'b1),
        .I_BC1     (ay2_bc1_r | ay2_data_rd),
        .I_SEL_L   (1'b0),
        .I_STEREO  (1'b0),
        .O_AUDIO_L (ay2_audio_l),
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

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            final_opamp_mix <= 11'd0;
        end else if (ce_sound) begin
            final_opamp_mix <= {1'b0, ay1_audio_l} + {1'b0, ay2_audio_l};
        end
    end

endmodule
