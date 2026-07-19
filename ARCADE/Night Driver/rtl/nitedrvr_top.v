module nitedrvr_top (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        dip_service,	 
    input  wire  [7:0] IN0,
    input  wire        gearup,
    input  wire        geardown,
	 input  wire        bezel_active,
    input  wire        steer_left_btn,
    input  wire        steer_right_btn,
    output wire        video_h_sync,
    output wire        video_v_sync,
    output wire        video_h_blank,
    output wire        video_v_blank,
    output wire  [3:0] video_r,
    output wire  [3:0] video_g,
    output wire  [3:0] video_b,
    output wire  [7:0] audio_out
);

    reg [3:0] cpu_clk_div;
    reg       cpu_ce; 

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            cpu_clk_div <= 4'd0;
            cpu_ce      <= 1'b0;
        end else begin
            if (cpu_clk_div == 4'd11) begin 
                cpu_clk_div <= 4'd0;
                cpu_ce      <= 1'b1; 
            end else begin
                cpu_clk_div <= cpu_clk_div + 1'b1;
                cpu_ce      <= 1'b0;
            end
        end
    end

    reg [3:0] cpu_rst_reg;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) 
            cpu_rst_reg <= 4'b1111;
        else if (cpu_ce)      
            cpu_rst_reg <= {cpu_rst_reg[2:0], 1'b0};
    end
    wire cpu_reset_n = !cpu_rst_reg;

    wire [23:0] cpu_a;
    wire  [7:0] cpu_di;
    wire  [7:0] cpu_do;
    wire        cpu_rw_n;
    wire        cpu_sync;
    wire        irq_n;

    T65 cpu (
        .Res_n(cpu_reset_n),
        .Enable(cpu_ce),     
        .Clk(clk_sys),       
        .Rdy(1'b1),
        .Abort_n(1'b1),
        .IRQ_n(irq_n),
        .NMI_n(1'b1),
        .SO_n(1'b1),
        .R_W_n(cpu_rw_n),
        .Sync(cpu_sync),
        .A(cpu_a),
        .DI(cpu_do),         
        .DO(cpu_di)
    );

    wire clk_6mhz;
    wire clk_star;
    wire [8:0] h_cnt;
    wire [8:0] v_cnt;

    nitedrvr_sync sync_core (
        .CLK12(clk_sys),
        .RESET(!rst_n),
        .CLK6(clk_6mhz),
        .CLK_STAR(clk_star),
        .HSYNC(video_h_sync),
        .VSYNC(video_v_sync),
        .HBLANK(video_h_blank),
        .VBLANK(video_v_blank),
        .IRQn(irq_n),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );

    reg [2:0] gear;
    reg       old_gear_up;
    reg       old_gear_down;
    reg       gear1, gear2, gear3, gear4;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            gear          <= 3'b000;
            old_gear_up   <= 1'b0;
            old_gear_down <= 1'b0;
        end else begin
            if (gearup) begin
                if (!old_gear_up) begin
                    old_gear_up <= 1'b1;
                    if (gear < 3'd3) gear <= gear + 1'b1;
                end
            end else if (geardown) begin
                if (!old_gear_down) begin
                    old_gear_down <= 1'b1;
                    if (gear > 3'd0) gear <= gear - 1'b1;
                end
            end else begin
                old_gear_up   <= 1'b0;
                old_gear_down <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (gear)
            3'b000:  begin gear1 = 1'b1; gear2 = 1'b0; gear3 = 1'b0; gear4 = 1'b0; end
            3'b001:  begin gear1 = 1'b0; gear2 = 1'b1; gear3 = 1'b0; gear4 = 1'b0; end
            3'b010:  begin gear1 = 1'b0; gear2 = 1'b0; gear3 = 1'b1; gear4 = 1'b0; end
            3'b011:  begin gear1 = 1'b0; gear2 = 1'b0; gear3 = 1'b0; gear4 = 1'b1; end
            default: begin gear1 = 1'b0; gear2 = 1'b0; gear3 = 1'b0; gear4 = 1'b0; end
        endcase
    end

    reg [17:0] steer_sim_clk; 
    reg [1:0]  steer_sim_phase;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            steer_sim_clk   <= 18'd0;
            steer_sim_phase <= 2'b00;
        end else begin
            if (steer_left_btn || steer_right_btn) begin
                if (steer_sim_clk >= 18'd50000) begin 
                    steer_sim_clk <= 18'd0;
                    if (steer_left_btn)       steer_sim_phase <= steer_sim_phase - 1'b1;
                    else if (steer_right_btn) steer_sim_phase <= steer_sim_phase + 1'b1;
                end else begin
                    steer_sim_clk <= steer_sim_clk + 1'b1;
                end
            end else begin
                steer_sim_clk <= 18'd0;
            end
        end
    end

    wire sim_steerA = (steer_sim_phase == 2'b01 || steer_sim_phase == 2'b10);
    wire sim_steerB = (steer_sim_phase == 2'b10 || steer_sim_phase == 2'b11);

    reg steer_moved;
    reg steer_dir;
    reg old_sim_steerB; 
    wire steer_clear; 

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            steer_moved    <= 1'b0;
            steer_dir      <= 1'b0;
            old_sim_steerB <= 1'b0;
        end else begin
            old_sim_steerB <= sim_steerB;
            
            if (sim_steerB && !old_sim_steerB) begin
                steer_dir   <= sim_steerA;
                steer_moved <= 1'b1; 
            end else if (steer_clear) begin
                steer_moved <= 1'b0; 
            end
        end
    end

    wire [3:0] hvc_addr;
    wire [7:0] hvc_data;
    wire [7:0] pfw_data;
    wire       hvc_we;
    wire [7:0] scram_data;
    wire       scram_we;
    wire [7:0] rom1_data;
    wire [7:0] rom2_data;
    wire       pfw_we;

    nitedrvr_bus bus_io (
        .clk_sys(clk_sys),
        .rst_n(rst_n),
        .cpu_a(cpu_a),
        .cpu_di(cpu_di),
        .cpu_do(cpu_do),
        .cpu_rw_n(cpu_rw_n),
        .cpu_ce(cpu_ce),
        .v_blank(video_v_blank),
        .dip_service(dip_service),
        .gear1(gear1),
        .gear2(gear2),
        .gear3(gear3),
        .gear4(gear4),
        .steer_moved(steer_moved),
        .steer_dir(steer_dir),
        .IN0(IN0),
        .hvc_we(hvc_we),
        .hvc_addr(hvc_addr),
        .hvc_data(hvc_data),
        .pfw_data(pfw_data),
        .pfw_we(pfw_we),
        .scram_data(scram_data),
        .scram_we(scram_we),
        .rom1_data(rom1_data),
        .rom2_data(rom2_data),
        .steer_clear(steer_clear)  
    );
	 
    reg [21:0] crash_blink_cnt;
    wire       crash_blink_clk = crash_blink_cnt[21];
    wire       crash_active;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) crash_blink_cnt <= 22'd0;
        else        crash_blink_cnt <= crash_blink_cnt + 22'd1;
    end

    nitedrvr_ram scram (
        .clk(clk_sys), 
        .addr(cpu_a[8:0]), 
        .din(cpu_di), 
        .dout(scram_data), 
        .we(scram_we)
    );

    wire [7:0] pfw_v_data;
    wire [8:0] pfw_addr_mux = pfw_we ? cpu_a[8:0] : {v_cnt[7:4], h_cnt[7:3]};
    
    nitedrvr_ram pfw_ram (
        .clk(clk_sys), 
        .addr(pfw_addr_mux), 
        .din(cpu_di), 
        .dout(pfw_v_data), 
        .we(pfw_we)
    );
    assign pfw_data = pfw_v_data;

    nitedrvr_rom1 rom1 (
        .clk(clk_sys), 
        .addr(cpu_a[10:0]), 
        .data(rom1_data)
    );
    nitedrvr_rom2 rom2 (
        .clk(clk_sys), 
        .addr(cpu_a[10:0]), 
        .data(rom2_data)
    );

    wire [1:0] hvc_reg_sel = cpu_a[5:4];
    wire hvc_posh_we = hvc_we && (hvc_reg_sel == 2'b00);
    wire hvc_posv_we = hvc_we && (hvc_reg_sel == 2'b01);
    wire hvc_char_we = hvc_we && (hvc_reg_sel == 2'b10);

    wire road_pix;
    nitedrvr_road road_gen (
        .clk_sys(clk_sys), 
        .rst_n(rst_n), 
        .h_cnt(h_cnt), 
        .v_cnt(v_cnt),
        .hvc_posh_we(hvc_posh_we), 
        .hvc_posv_we(hvc_posv_we), 
        .hvc_char_we(hvc_char_we),
        .hvc_addr(hvc_addr), 
        .hvc_data(hvc_data), 
        .road_video(road_pix)
    );

    wire [7:0] char_rom_out;
    nitedrvr_char_rom char_rom (
        .clk(clk_sys), 
        .addr({pfw_v_data[5:0], v_cnt[3:1]}), 
        .data(char_rom_out)
    );

    wire pfw_pix = char_rom_out[~h_cnt[2:0]];
    wire blank = video_h_blank || video_v_blank;
    
    wire raw_game_video = pfw_pix || road_pix;
    wire game_video_signal = (crash_active && crash_blink_clk) ? ~raw_game_video : raw_game_video;
    
    wire [3:0] bezel_r, bezel_g, bezel_b;

    bezel_overlay bezel_inst (
        .clk(clk_sys),
		  .ena(bezel_active),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .game_pixel(game_video_signal),
        .r(bezel_r), 
        .g(bezel_g), 
        .b(bezel_b)
    );

    reg [3:0] r_reg, g_reg, b_reg;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            r_reg <= 4'h0;
            g_reg <= 4'h0;
            b_reg <= 4'h0;
        end else begin
            if (blank) begin
                r_reg <= 4'h0; 
                g_reg <= 4'h0;
                b_reg <= 4'h0;
            end else begin
                r_reg <= bezel_r; 
                g_reg <= bezel_g;
                b_reg <= bezel_b;
            end
        end
    end
          
    assign video_r = r_reg;
    assign video_g = g_reg;
    assign video_b = b_reg;

    wire out0_we = (cpu_a[15:9] == 7'b0000101) && !cpu_rw_n;
    wire out1_we = (cpu_a[15:9] == 7'b0000110) && !cpu_rw_n;
     
    nitedrvr_sound audio_core (
        .clk_sys(clk_sys), 
        .rst_n(rst_n), 
        .out0_we(out0_we), 
        .out1_we(out1_we), 
        .cpu_data_in(cpu_di),
		  .h_cnt(h_cnt),
		  .v_cnt(v_cnt),
        .audio_out(audio_out),
        .video_crash(crash_active)
    );

endmodule
