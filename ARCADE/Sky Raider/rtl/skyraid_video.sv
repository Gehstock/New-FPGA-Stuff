`timescale 1ns / 1ps

module skyraid_video (
    input  logic        clk_12M,          
    input  logic        rst_n,            
    input  logic [7:0]  reg_scroll,       
    input  logic [7:0]  m_alpha_num_ram,  
    input  logic [7:0]  m_pos_ram [15:0],        
    input  logic [7:0]  m_obj_ram [15:0],        
    output logic [10:0] video_alpha_addr,
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic        video_blank
);

    localparam H_ACTIVE = 512, H_FP = 32, H_SP = 64, H_BP = 160, H_TOTAL = 768;
    localparam V_ACTIVE = 240, V_FP = 4,  V_SP = 3,  V_BP = 15,  V_TOTAL = 262;
    logic [9:0] h_cnt;  
    logic [8:0] v_cnt;  

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin 
            h_cnt <= '0; 
            v_cnt <= '0; 
        end
        else if (h_cnt == (H_TOTAL - 1)) begin
            h_cnt <= '0;
            if (v_cnt == (V_TOTAL - 1)) v_cnt <= '0;
            else v_cnt <= v_cnt + 1'b1;
        end else h_cnt <= h_cnt + 1'b1;
    end

    logic [9:0] h_cnt_shifted;
    always_comb begin
        if (h_cnt >= 10'd2)
            h_cnt_shifted = h_cnt - 10'd2;
        else
            h_cnt_shifted = h_cnt + (10'(H_TOTAL) - 10'd2);
    end

    logic [8:0] v_cnt_flipped;
    always_comb begin
        if (v_cnt < V_ACTIVE)
            v_cnt_flipped = 9'd239 - v_cnt;
        else
            v_cnt_flipped = v_cnt;
    end

    logic hsync_raw, vsync_raw, blank_raw;
    always_comb begin
        hsync_raw = ~((h_cnt >= (H_ACTIVE + H_FP)) && (h_cnt < (H_ACTIVE + H_FP + H_SP)));
        vsync_raw = ~((v_cnt >= (V_ACTIVE + V_FP)) && (v_cnt < (V_ACTIVE + V_FP + V_SP)));
        blank_raw = (h_cnt >= H_ACTIVE) || (v_cnt >= V_ACTIVE);
    end

    logic hsync_p1, hsync_p2;
    logic vsync_p1, vsync_p2;
    logic blank_p1, blank_p2;

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            hsync_p1 <= 1'b1; hsync_p2 <= 1'b1;
            vsync_p1 <= 1'b1; vsync_p2 <= 1'b1;
            blank_p1 <= 1'b1; blank_p2 <= 1'b1;
        end else begin
            hsync_p1 <= hsync_raw; hsync_p2 <= hsync_p1;
            vsync_p1 <= vsync_raw; vsync_p2 <= vsync_p1;
            blank_p1 <= blank_raw; blank_p2 <= blank_p1;
        end
    end

    assign video_hsync = hsync_p2;
    assign video_vsync = vsync_p2;
    assign video_blank = blank_p2;
    logic [6:0] terrain_h_cnt;
    logic       inside_trapezoid;
    logic       sprite_pixel;
    logic [1:0] sprite_color;

    draw_trapezoid u_trapezoid (
        .clk_12M(clk_12M), 
        .rst_n(rst_n),
        .h_cnt(h_cnt_shifted), 
        .v_cnt(v_cnt_flipped), 
        .m_pos_ram(m_pos_ram),
        .m_obj_ram(m_obj_ram),
        .inside_trapezoid(inside_trapezoid), 
        .terrain_h_cnt(terrain_h_cnt),
        .sprite_pixel(sprite_pixel),
        .sprite_color(sprite_color)
    );
	 
    logic [2:0] current_terrain_pixel;
    draw_terrain u_terrain (
        .clk_12M(clk_12M), 
        .rst_n(rst_n), 
        .blank(blank_raw), 
        .v_cnt(v_cnt_flipped), 
        .terrain_h_cnt(terrain_h_cnt),
        .reg_scroll(reg_scroll), 
        .current_terrain_pixel(current_terrain_pixel) 
    );

    logic text_pixel;
    draw_text u_text (
        .clk_12M(clk_12M), 
        .blank(blank_raw), 
        .h_cnt(h_cnt_shifted),
        .v_cnt(v_cnt_flipped), 
        .m_alpha_num_ram(m_alpha_num_ram), 
        .video_alpha_addr(video_alpha_addr), 
        .text_pixel(text_pixel) 
    );

    logic missile_pixel;
    draw_missiles u_missiles (
        .clk_12M(clk_12M), 
        .rst_n(rst_n), 
        .terrain_h_cnt(terrain_h_cnt),
        .inside_trapezoid(inside_trapezoid),
        .v_cnt(v_cnt_flipped), 
        .m_pos_ram(m_pos_ram), 
        .m_obj_ram(m_obj_ram), 
        .missile_pixel(missile_pixel) 
    );

    logic [2:0] intensity;

    always_comb begin
        intensity = 3'd0;        
        if (text_pixel) begin
            intensity = 3'd7;
        end 
        else if (inside_trapezoid) begin
            if (missile_pixel) begin
                intensity = 3'd7;
            end
            else if (sprite_pixel) begin
                case (sprite_color)
                    2'd0:    intensity = 3'd1;
                    2'd1:    intensity = 3'd2; 
                    2'd3:    intensity = 3'd7;
                    default: intensity = 3'd0;
                endcase
            end
            else begin
                case (current_terrain_pixel)
                    3'd0:    intensity = 3'd0; 
                    3'd1:    intensity = 3'd1; 
                    3'd2:    intensity = 3'd2; 
                    3'd3:    intensity = 3'd3; 
                    3'd4:    intensity = 3'd4; 
                    3'd5:    intensity = 3'd5; 
                    3'd6:    intensity = 3'd6; 
                    3'd7:    intensity = 3'd7; 
                endcase
            end
        end
    end


    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            video_r <= 3'd0; video_g <= 3'd0; video_b <= 3'd0;
        end else begin
            if (blank_p2) begin
                video_r <= 3'd0; video_g <= 3'd0; video_b <= 3'd0;
            end else begin
                video_r <= intensity; video_g <= intensity; video_b <= intensity;
            end
        end
    end

endmodule
