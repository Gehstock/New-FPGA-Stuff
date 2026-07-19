// Atari Avalanche (1978) on MiST FPGA
// (Gehstock 2026)
module avalnche_video (
    input  logic        clk_12m,
    input  logic        reset_n,
    input  logic [12:0] cpu_vram_addr,     
    input  logic [7:0]  cpu_vram_data,     
    input  logic        vram_wren,         
    output logic [7:0]  vram_cpu_q,   
    input  logic        video_inverted,    
    output logic [3:0]  video_r,
    output logic [3:0]  video_g,
    output logic [3:0]  video_b,
    output logic        video_hs,          
    output logic        video_vs,          
    output logic        video_blank,       
    output logic [8:0]  video_vpos         
);

    logic [8:0] h_pos;
    logic [8:0] v_pos;
    logic       clk_6m_ena;

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) clk_6m_ena <= 1'b0;
        else          clk_6m_ena <= ~clk_6m_ena;
    end

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            h_pos <= '0; v_pos <= '0;
        end else if (clk_6m_ena) begin
            if (h_pos == 9'd383) begin
                h_pos <= '0;
                v_pos <= (v_pos == 9'd261) ? 9'd0 : v_pos + 1'b1;
            end else begin
                h_pos <= h_pos + 1'b1;
            end
        end
    end

    assign video_hs    = (h_pos >= 272 && h_pos < 312); 
    assign video_vs    = (v_pos >= 256 && v_pos < 260); 
   // assign video_blank = (h_pos >= 256) || (v_pos < 16) || (v_pos >= 256);
	 assign video_blank = (h_pos < 2) || (h_pos >= 256) || (v_pos < 18) || (v_pos >= 256);
    assign video_vpos  = v_pos;

    logic [12:0] video_vram_addr;
    logic [7:0]  video_vram_q;
    assign video_vram_addr = {v_pos[7:0], h_pos[7:3]};

    dpram #(
        .address_width(13),
        .data_width(8)
    ) framebuffer_inst (
        .clock    (clk_12m),
        .enable_a (1'b1), 
        .wren_a   (vram_wren), 
        .address_a(cpu_vram_addr), 
        .data_a   (cpu_vram_data), 
        .q_a      (vram_cpu_q),
        .enable_b (1'b1), 
        .wren_b   (1'b0), 
        .address_b(video_vram_addr), 
        .data_b   (8'h00), 
        .q_b      (video_vram_q)
    );

    logic [7:0] pixel_shift_reg;
    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            pixel_shift_reg <= 8'h00;
        end else if (clk_6m_ena) begin
            if (h_pos[2:0] == 3'd0) begin
                pixel_shift_reg <= video_vram_q;
            end else begin
                pixel_shift_reg <= {pixel_shift_reg[6:0], 1'b0};
            end
        end
    end

    logic monochrome_color;
    assign monochrome_color = video_inverted ? pixel_shift_reg[7] : !pixel_shift_reg[7];
    logic [3:0] overlay_r;
    logic [3:0] overlay_g;
    logic [3:0] overlay_b;

    always_comb begin
        if (v_pos <= 9'd25) begin
            overlay_r = 4'h0; overlay_g = 4'hF; overlay_b = 4'hF;
        end else if (v_pos <= 9'd35) begin
            overlay_r = 4'h0; overlay_g = 4'h0; overlay_b = 4'hF;
        end else if (v_pos <= 9'd44) begin
            overlay_r = 4'hF; overlay_g = 4'hF; overlay_b = 4'h0;
        end else if (v_pos <= 9'd55) begin
            overlay_r = 4'hF; overlay_g = 4'h6; overlay_b = 4'h0;
        end else begin
            overlay_r = 4'h0; overlay_g = 4'hF; overlay_b = 4'hF;
        end
    end

    always_ff @(posedge clk_12m) begin
        if (video_blank) begin
            video_r <= 4'h0; video_g <= 4'h0; video_b <= 4'h0;
        end else begin
            video_r <= monochrome_color ? overlay_r : 4'h0;
            video_g <= monochrome_color ? overlay_g : 4'h0;
            video_b <= monochrome_color ? overlay_b : 4'h0;
        end
    end

endmodule
