module mole_video (
    input  logic        clk_sys,
    input  logic        rst_n,
    
    input  logic [9:0]  cpu_addr,
    input  logic [7:0]  cpu_din,
    input  logic        cpu_we,
    output logic [7:0]  cpu_dout,
    input  logic [7:0]  tile_bank,
    input  logic [7:0]  video_flip,
    
    output logic        video_hs,
    output logic        video_vs,
    output logic        video_r,
    output logic        video_g,
    output logic        video_b,
    output logic        video_hb,
    output logic        video_vb
);

    logic [1:0]  v_div;
    logic        v_en;
    logic [9:0]  h_count;
    logic [8:0]  v_count;
    
    logic        hs_comb;
    logic        vs_comb;
    logic        hb_comb;
    logic        vb_comb;
    logic        blank_comb;

    logic        hs_pipe1, hs_pipe2, hs_pipe3;
    logic        vs_pipe1, vs_pipe2, vs_pipe3;
    logic        hb_pipe1, hb_pipe2, hb_pipe3;
    logic        vb_pipe1, vb_pipe2, vb_pipe3;
    logic        blank_pipe1, blank_pipe2, blank_pipe3;
    
    logic [2:0]  tile_rgb;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            v_div <= 2'd0;
            v_en  <= 1'b0;
        end else begin
            if (v_div == 2'd2) begin
                v_div <= 2'd0;
                v_en  <= 1'b1;
            end else begin
                v_div <= v_div + 2'd1;
                v_en  <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 10'd0;
        end else if (v_en) begin
            if (h_count == 10'd391) begin
                h_count <= 10'd0;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            v_count <= 9'd0;
        end else if (v_en && (h_count == 10'd391)) begin
            if (v_count == 9'd283) begin
                v_count <= 9'd0;
            end else begin
                v_count <= v_count + 9'd1;
            end
        end
    end

    assign hs_comb    = (h_count >= 10'd330 && h_count < 10'd365) ? 1'b0 : 1'b1;
    assign vs_comb    = (v_count >= 9'd262 && v_count < 9'd266) ? 1'b0 : 1'b1;
    assign hb_comb    = (h_count >= 10'd320);
    assign vb_comb    = (v_count >= 9'd200);
    assign blank_comb = hb_comb || vb_comb;

    mole_tile tile_layer (
        .clk_sys   (clk_sys),
        .cpu_addr  (cpu_addr),
        .cpu_din   (cpu_din),
        .cpu_we    (cpu_we),
        .cpu_dout  (cpu_dout),
        .tile_bank (tile_bank),
        .video_flip(video_flip),
        .h_count   (h_count),
        .v_count   (v_count),
        .rgb_out   (tile_rgb)
    );

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            hs_pipe1    <= 1'b1; hs_pipe2    <= 1'b1; hs_pipe3    <= 1'b1;
            vs_pipe1    <= 1'b1; vs_pipe2    <= 1'b1; vs_pipe3    <= 1'b1;
            hb_pipe1    <= 1'b0; hb_pipe2    <= 1'b0; hb_pipe3    <= 1'b0;
            vb_pipe1    <= 1'b0; vb_pipe2    <= 1'b0; vb_pipe3    <= 1'b0;
            blank_pipe1 <= 1'b1; blank_pipe2 <= 1'b1; blank_pipe3 <= 1'b1;
            video_hs    <= 1'b1;
            video_vs    <= 1'b1;
            video_hb    <= 1'b0;
            video_vb    <= 1'b0;
            video_r     <= 1'b0;
            video_g     <= 1'b0;
            video_b     <= 1'b0;
        end else begin
            hs_pipe1    <= hs_comb;
            vs_pipe1    <= vs_comb;
            hb_pipe1    <= hb_comb;
            vb_pipe1    <= vb_comb;
            blank_pipe1 <= blank_comb;

            hs_pipe2    <= hs_pipe1;
            vs_pipe2    <= vs_pipe1;
            hb_pipe2    <= hb_pipe1;
            vb_pipe2    <= vb_pipe1;
            blank_pipe2 <= blank_pipe1;

            hs_pipe3    <= hs_pipe2;
            vs_pipe3    <= vs_pipe2;
            hb_pipe3    <= hb_pipe2;
            vb_pipe3    <= vb_pipe2;
            blank_pipe3 <= blank_pipe2;

            video_hs    <= hs_pipe3;
            video_vs    <= vs_pipe3;
            video_hb    <= hb_pipe3;
            video_vb    <= vb_pipe3;
            
            video_r     <= blank_pipe3 ? 1'b0 : tile_rgb[0];
            video_g     <= blank_pipe3 ? 1'b0 : tile_rgb[2];
            video_b     <= blank_pipe3 ? 1'b0 : tile_rgb[1];
        end
    end

endmodule
