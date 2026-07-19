`timescale 1ns / 1ps

module skyraid_top (
    input  logic        clk_12M,          
    input  logic        rst_n,              
    input  logic [5:0]  language_input,   
    input  logic [7:0]  dsw_input,        
    input  logic [7:0]  coin_input,       
    input  logic [7:0]  system_input,     
    input  logic        btn_left,         
    input  logic        btn_right,        
    input  logic        btn_up,           
    input  logic        btn_down,         
    output logic [2:0]  video_r,
    output logic [2:0]  video_g,
    output logic [2:0]  video_b,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic        video_blank,
    output logic [15:0] audio_mixer,
    output logic        DBG	 
);

    logic [23:0] cpu_addr;
    logic [7:0]  cpu_data_out;
    logic [7:0]  cpu_data_in;
    logic        cpu_rw_n;
    logic        cpu_sync;
	 logic 		  cpu_irq_n;
    logic [7:0]  reg_scroll;
    logic [7:0]  sound_data;
    logic        sound_we;
    logic [7:0]  vram_alpha_cpu, vram_alpha_vid;
    logic [7:0]  vram_pos_cpu;
    logic [7:0]  vram_obj_cpu;
    logic        ram_main_we;
    logic        vram_pos_we;
    logic        vram_alpha_we;
    logic        vram_obj_we;
    logic        scroll_we;
    logic        sound_we_reg;
    logic        range_we;
    logic        offset_we;
    logic [5:0]  reg_analog_range;
    logic [5:0]  reg_analog_offset;
    logic [5:0]  pot_x_counter;
    logic [5:0]  pot_y_counter;
    logic        vsync_old;  
    logic [7:0]  port_0_data;
    logic [7:0]  ram_main_out;
    logic [7:0]  rom_cpu_out;
    logic [7:0]  rom_d1_out;
    logic [7:0]  rom_e1_out;
    logic [10:0] video_alpha_addr;
    logic [7:0]  vram_pos_array [15:0];
    logic [7:0]  vram_obj_array [15:0];
    logic [3:0]  cpu_clk_div;
    logic        cpu_en;

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            cpu_clk_div <= 4'd0;
            cpu_en      <= 1'b0;
        end else begin
            if (cpu_clk_div == 4'd11) begin
                cpu_clk_div <= 4'd0;
                cpu_en      <= 1'b1;
            end else begin
                cpu_clk_div <= cpu_clk_div + 1'b1;
                cpu_en      <= 1'b0;
            end
        end
		  
		  end


    assign cpu_irq_n = video_vsync;
    T65 u_cpu (
        .Mode(2'b00), 
        .BCD_en(1'b1), 
        .Res_n(rst_n), 
        .Enable(cpu_en),
        .Clk(clk_12M), 
        .Rdy(1'b1), 
        .Abort_n(1'b1), 
        .IRQ_n(cpu_irq_n), 
        .NMI_n(1'b1), 
        .SO_n(1'b1),
        .R_W_n(cpu_rw_n), 
        .Sync(cpu_sync), 
        .A(cpu_addr), 
        .DI(cpu_data_in), 
        .DO(cpu_data_out)
    );

    always_comb begin
        port_0_data = language_input;
        port_0_data[6] = 1'b0;
        port_0_data[7] = 1'b0;
        
        if (pot_y_counter > reg_analog_range) port_0_data[6] = 1'b1;
        if (pot_x_counter > reg_analog_range) port_0_data[7] = 1'b1;
    end

    always_comb begin
        ram_main_we   = 1'b0; 
		  vram_pos_we   = 1'b0; 
		  vram_alpha_we = 1'b0; 
		  vram_obj_we   = 1'b0;
        scroll_we     = 1'b0; 
		  sound_we      = 1'b0; 
		  range_we      = 1'b0; 
		  offset_we     = 1'b0;       
        if (~cpu_rw_n && (cpu_addr[23:16] == 8'h00 || cpu_addr[23:16] == 8'hFF)) begin
            if (cpu_addr[15:0] >= 16'h0000 && cpu_addr[15:0] <= 16'h03FF) ram_main_we   = 1'b1;
            if (cpu_addr[15:0] >= 16'h0400 && cpu_addr[15:0] <= 16'h040F) vram_pos_we   = 1'b1;
            if (cpu_addr[15:0] >= 16'h0800 && cpu_addr[15:0] <= 16'h0C7F) vram_alpha_we = 1'b1;
            if (cpu_addr[15:0] >= 16'h1C00 && cpu_addr[15:0] <= 16'h1C0F) vram_obj_we   = 1'b1;
            if (cpu_addr[15:0] == 16'h4000)                               scroll_we     = 1'b1;
            if (cpu_addr[15:0] == 16'h4400)                               sound_we      = 1'b1;
            if (cpu_addr[15:0] == 16'h4800)                               range_we      = 1'b1;
            if (cpu_addr[15:0] == 16'h5800)                               offset_we     = 1'b1;
        end
    end

    always_comb begin
        if (cpu_addr[15:0] >= 16'h0000 && cpu_addr[15:0] <= 16'h03FF)      cpu_data_in = ram_main_out;
        else if (cpu_addr[15:0] >= 16'h0400 && cpu_addr[15:0] <= 16'h040F) cpu_data_in = vram_pos_cpu;
        else if (cpu_addr[15:0] >= 16'h0800 && cpu_addr[15:0] <= 16'h0C7F) cpu_data_in = vram_alpha_cpu;
        else if (cpu_addr[15:0] == 16'h1000)                               cpu_data_in = port_0_data;   
        else if (cpu_addr[15:0] == 16'h1001)                               cpu_data_in = dsw_input;     
        else if (cpu_addr[15:0] == 16'h1400)                               cpu_data_in = coin_input;    
        else if (cpu_addr[15:0] == 16'h1401)                               cpu_data_in = system_input;  
        else if (cpu_addr[15:0] >= 16'h1C00 && cpu_addr[15:0] <= 16'h1C0F) cpu_data_in = vram_obj_cpu;
		  
        else if (cpu_addr[15:0] >= 16'h7000 && cpu_addr[15:0] <= 16'h77FF) cpu_data_in = rom_e1_out;
		  
		  else if (cpu_addr[15:0] >= 16'hF000 && cpu_addr[15:0] <= 16'hF7FF) cpu_data_in = rom_e1_out;
		  
		  else if (cpu_addr[15:0] >= 16'h7800 && cpu_addr[15:0] <= 16'h7FFF) cpu_data_in = rom_d1_out;
		  
		  else if (cpu_addr[15:0] >= 16'hF800 && cpu_addr[15:0] <= 16'hFFFF) cpu_data_in = rom_d1_out;
		  
        else                                                               cpu_data_in = 8'hFF;
    end


    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            reg_scroll        <= 8'h00;
            reg_analog_range  <= 6'd0;
            reg_analog_offset <= 6'd0;
            sound_data        <= 8'h00;
        end else begin
            if (scroll_we) reg_scroll        <= cpu_data_out;
            if (range_we)  reg_analog_range  <= cpu_data_out[5:0];
            if (offset_we) reg_analog_offset <= cpu_data_out[5:0];
            if (sound_we)  sound_data        <= cpu_data_out;
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            pot_x_counter <= 6'd32;
            pot_y_counter <= 6'd32;
            vsync_old     <= 1'b0;
        end else begin
            vsync_old <= video_vsync;
            if (video_vsync && !vsync_old) begin
                if (btn_left && (pot_x_counter > 6'd0)) begin
                    pot_x_counter <= pot_x_counter - 1'b1;
                end else if (btn_right && (pot_x_counter < 6'd63)) begin
                    pot_x_counter <= pot_x_counter + 1'b1;
                end else if (!btn_left && !btn_right) begin
                    if (pot_x_counter > 6'd32)      pot_x_counter <= pot_x_counter - 1'b1;
                    else if (pot_x_counter < 6'd32) pot_x_counter <= pot_x_counter + 1'b1;
                end

                if (btn_up && (pot_y_counter > 6'd0)) begin
                    pot_y_counter <= pot_y_counter - 1'b1;
                end else if (btn_down && (pot_y_counter < 6'd63)) begin
                    pot_y_counter <= pot_y_counter + 1'b1;
                end else if (!btn_up && !btn_down) begin
                    if (pot_y_counter > 6'd32)      pot_y_counter <= pot_y_counter - 1'b1;
                    else if (pot_y_counter < 6'd32) pot_y_counter <= pot_y_counter + 1'b1;
                end
            end
        end
    end

    spram #(10,8) ram_main (
      .clock(clk_12M), 
		.wren(ram_main_we), 
		.address(cpu_addr[9:0]), 
		.data(cpu_data_out), 
		.q(ram_main_out)
    );

    dpram #(11,8) vram_alpha (
      .clock_a(clk_12M), 
		.enable_a(1'b1), 
		.wren_a(vram_alpha_we), 
		.address_a(cpu_addr[10:0]), 
		.data_a(cpu_data_out), 
		.q_a(vram_alpha_cpu),
      .clock_b(clk_12M), 
		.enable_b(1'b1), 
		.wren_b(1'b0),          
		.address_b(video_alpha_addr), 
		.data_b(8'd0),        
		.q_b(vram_alpha_vid)
    );
	 
	 always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) vram_pos_array[i] <= 8'd0;
        end else if (vram_pos_we) begin
            vram_pos_array[cpu_addr[3:0]] <= cpu_data_out;
        end
    end
    assign vram_pos_cpu = vram_pos_array[cpu_addr[3:0]];

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) vram_obj_array[i] <= 8'd0;
        end else if (vram_obj_we) begin
            vram_obj_array[cpu_addr[3:0]] <= cpu_data_out;
        end
    end
    assign vram_obj_cpu = vram_obj_array[cpu_addr[3:0]];

    e1 e1_inst (
		.clk(clk_12M), 
		.addr(cpu_addr[10:0]), 
		.data(rom_e1_out)
	);
	
    d1 d1_inst (
		.clk(clk_12M), 
		.addr(cpu_addr[10:0]), 
		.data(rom_d1_out)
		);


    skyraid_video u_video (
        .clk_12M(clk_12M), 
        .rst_n(rst_n), 
        .reg_scroll(reg_scroll),
        .m_alpha_num_ram(vram_alpha_vid),
        .m_pos_ram(vram_pos_array),
        .m_obj_ram(vram_obj_array),
        .video_alpha_addr(video_alpha_addr),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_blank(video_blank)
    );

    skyraid_sound u_sound (
        .clk_12M(clk_12M), 
        .rst_n(rst_n), 
        .sound_data(sound_data),
        .sound_we(sound_we),
        .audio_mixer(audio_mixer),
		  .dbg(DBG)
    );

endmodule
