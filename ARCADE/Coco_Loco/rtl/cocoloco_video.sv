`default_nettype none

module cocoloco_video (
    input  wire        clk,
    input  wire        clk_pix_en,      
    input  wire        clk_cpu_en,      
    input  wire        reset,
    
    input  wire        cpu_vram_cs,     
    input  wire        cpu_vram_wr,     
    input  wire [3:0]  cpu_vram_bank,   
    input  wire [13:0] cpu_vram_addr,   
    input  wire [7:0]  cpu_vram_data,   
    output reg  [7:0]  cpu_vram_q,      
    
    output reg         video_hsync,
    output reg         video_vsync,
    output reg  [3:0]  video_r,
    output reg  [3:0]  video_g,
    output wire [3:0]  video_b,
    
    output reg        video_hblank,    
    output reg        video_vblank     
);

    localparam H_ACTIVE_PIXELS = 256; 
    localparam H_TOTAL         = 384; 
    localparam V_ACTIVE_LINES  = 256;
    localparam V_TOTAL         = 262; 

    reg [8:0] h_cnt; 
    reg [8:0] v_cnt; 
	 assign video_hsync = ~((h_cnt >= 280) && (h_cnt < 312)); 
    assign video_vsync = ~((v_cnt >= 257) && (v_cnt < 260)); 


    wire is_cpu_vram = cpu_vram_addr[13]; 
    wire [12:0] internal_addr = cpu_vram_addr[12:0];
	 wire [12:0] base_render_addr = {h_cnt[7:3], ~v_cnt[7:0]};
    wire wram_we = clk_cpu_en && cpu_vram_cs && cpu_vram_wr && !is_cpu_vram;
    wire vram_base_we = clk_cpu_en && cpu_vram_cs && cpu_vram_wr && is_cpu_vram;
    wire [7:0] p0_data_in = (cpu_vram_bank == 4'h0) ? cpu_vram_data : 8'h00;
    wire [7:0] p1_data_in = (cpu_vram_bank & 4'h2)  ? cpu_vram_data : 8'h00;
    wire [7:0] p2_data_in = (cpu_vram_bank & 4'h4)  ? cpu_vram_data : 8'h00;
    wire [7:0] p3_data_in = (cpu_vram_bank & 4'h8)  ? cpu_vram_data : 8'h00;
    wire [7:0] wram_q;
    wire [7:0] p0_cpu_q, p1_cpu_q, p2_cpu_q, p3_cpu_q;
    wire [7:0] p0_vid_q, p1_vid_q, p2_vid_q, p3_vid_q;

    spram #(13,8) wram_inst (
        .clock   (clk),
        .enable  (1'b1),
        .address (internal_addr),
        .data    (cpu_vram_data),
        .q       (wram_q),
        .wren    (wram_we)
    );

    dpram #(13,8) vram_p0 (
        .clock    (clk),
        .enable_a (1'b1), 
		  .wren_a(vram_base_we), 
		  .address_a(internal_addr), 
		  .data_a(p0_data_in), 
		  .q_a(p0_cpu_q),
        .enable_b (1'b1), 
		  .wren_b(1'b0),         
		  .address_b(base_render_addr), 
		  .data_b(8'h00),  
		  .q_b(p0_vid_q)
    );

    dpram #(13,8) vram_p1 (
        .clock    (clk),
        .enable_a (1'b1), 
		  .wren_a(vram_base_we), 
		  .address_a(internal_addr), 
		  .data_a(p1_data_in), 
		  .q_a(p1_cpu_q),
        .enable_b (1'b1), 
		  .wren_b(1'b0),         
		  .address_b(base_render_addr), 
		  .data_b(8'h00),  
		  .q_b(p1_vid_q)
    );

    dpram #(13,8) vram_p2 (
        .clock    (clk),
        .enable_a (1'b1), 
		  .wren_a(vram_base_we), 
		  .address_a(internal_addr), 
		  .data_a(p2_data_in), 
		  .q_a(p2_cpu_q),
        .enable_b (1'b1), 
		  .wren_b(1'b0),         
		  .address_b(base_render_addr), 
		  .data_b(8'h00),  
		  .q_b(p2_vid_q)
    );

    dpram #(13,8) vram_p3 (
        .clock    (clk),
        .enable_a (1'b1), 
		  .wren_a(vram_base_we), 
		  .address_a(internal_addr), 
		  .data_a(p3_data_in), 
		  .q_a(p3_cpu_q),
        .enable_b (1'b1), 
		  .wren_b(1'b0),         
		  .address_b(base_render_addr), 
		  .data_b(8'h00),  
		  .q_b(p3_vid_q)
    );

    reg is_cpu_vram_reg;
    always_ff @(posedge clk) begin
        is_cpu_vram_reg <= is_cpu_vram;
    end

    wire [7:0] vram_cpu_combined = p0_cpu_q | p1_cpu_q | p2_cpu_q | p3_cpu_q;

    always_comb begin
        cpu_vram_q = (is_cpu_vram_reg) ? vram_cpu_combined : wram_q;
    end

    wire plane0_bit = p0_vid_q[h_cnt[2:0]];
    wire plane1_bit = p1_vid_q[h_cnt[2:0]];
    wire plane2_bit = p2_vid_q[h_cnt[2:0]];
    wire plane3_bit = p3_vid_q[h_cnt[2:0]];
    
    wire [3:0] pixel_color_idx = {plane3_bit, plane2_bit, plane1_bit, plane0_bit};


    always_ff @(posedge clk) begin
        if (clk_pix_en) begin
				video_hblank <= (h_cnt >= H_ACTIVE_PIXELS);
            video_vblank <= (v_cnt >= V_ACTIVE_LINES);
                case (pixel_color_idx)
                    4'h0: begin video_r <= 4'h0; video_g <= 4'h0; video_b <= 4'h0; end
                    4'h1: begin video_r <= 4'hF; video_g <= 4'hF; video_b <= 4'h0; end
                    4'h2: begin video_r <= 4'h0; video_g <= 4'hF; video_b <= 4'h0; end
                    4'h3: begin video_r <= 4'h0; video_g <= 4'h0; video_b <= 4'hF; end 
                    4'h4: begin video_r <= 4'h0; video_g <= 4'hA; video_b <= 4'hF; end
                    4'h5: begin video_r <= 4'hF; video_g <= 4'h0; video_b <= 4'hF; end
                    4'h6: begin video_r <= 4'hA; video_g <= 4'hA; video_b <= 4'hA; end
                    4'h7: begin video_r <= 4'hF; video_g <= 4'hA; video_b <= 4'h0; end
                    4'h8: begin video_r <= 4'hC; video_g <= 4'h5; video_b <= 4'h0; end
                    4'h9: begin video_r <= 4'h0; video_g <= 4'hA; video_b <= 4'hA; end
                    4'hA: begin video_r <= 4'h0; video_g <= 4'hF; video_b <= 4'hF; end
                    4'hB: begin video_r <= 4'hA; video_g <= 4'h0; video_b <= 4'h0; end
                    4'hC: begin video_r <= 4'hF; video_g <= 4'h0; video_b <= 4'h0; end
                    4'hD: begin video_r <= 4'hA; video_g <= 4'hF; video_b <= 4'hA; end
                    4'hE: begin video_r <= 4'hF; video_g <= 4'hF; video_b <= 4'hF; end
                    4'hF: begin video_r <= 4'hA; video_g <= 4'hA; video_b <= 4'hF; end
                endcase
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            h_cnt <= 9'd0;
            v_cnt <= 9'd0;
        end else if (clk_pix_en) begin
            if (h_cnt == (H_TOTAL - 1)) begin
                h_cnt <= 9'd0;
                if (v_cnt == (V_TOTAL - 1)) begin
                    v_cnt <= 9'd0;
                end else begin
                    v_cnt <= v_cnt + 1'b1;
                end
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

endmodule 