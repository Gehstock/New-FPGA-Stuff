module BKing_Top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  in0_din,
    input  logic [7:0]  in1_din,
    input  logic [7:0]  dswa_din,
    input  logic [7:0]  dswb_din,
    input  logic [7:0]  dswc_din,
    input  logic [7:0]  track0_x_din,
    input  logic [7:0]  track0_y_din,
    input  logic [7:0]  track1_x_din,
    input  logic [7:0]  track1_y_din,
    output logic [14:0] rom_addr,
    input  logic [7:0]  rom_do,
	 output logic [12:0] snd_addr,
    input  logic [7:0]  snd_do,
    output logic [5:0]  Video_R,
    output logic [5:0]  Video_G,
    output logic [5:0]  Video_B,
    output logic        Video_HS,
    output logic        Video_VS,
    output logic        Video_HB,
    output logic        Video_VB,
    output logic [15:0] audio_out
);

    logic [1:0] clk_div;
    logic       cpu_en;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_div <= 2'b00;
        else        clk_div <= clk_div + 1'b1;
    end
    
    assign cpu_en = (clk_div == 2'b11);

    logic [15:0] bus_addr;
    logic [7:0]  bus_din;
    logic [7:0]  bus_dout;
    logic        main_mreq_n, main_iorq_n, main_rd_n, main_wr_n, main_int_n;
    logic        sel_rom, sel_wram, sel_playfield;
    
    logic [7:0] rom_dout, wram_dout, playfield_q_a, video_playfield_q;
    logic [10:0] video_playfield_addr;

    always_comb begin
        sel_rom       = 1'b0;
        sel_wram   = 1'b0;
        sel_playfield = 1'b0;
        
        if (!main_mreq_n) begin
            if (bus_addr >= 16'h0000 && bus_addr <= 16'h7FFF) begin
                sel_rom = 1'b1;
            end else if (bus_addr >= 16'h8000 && bus_addr <= 16'h8FFF) begin
                sel_wram = 1'b1;
            end else if (bus_addr >= 16'h9000 && bus_addr <= 16'h97FF) begin
                sel_playfield = 1'b1;
            end
        end
    end

    T80se main_cpu (
        .RESET_n(rst_n),
        .CLK_n(!clk),
        .CLKEN(cpu_en),
        .WAIT_n(1'b1),
        .INT_n(main_int_n),
        .NMI_n(1'b1),
        .BUSRQ_n(1'b1),
        .MREQ_n(main_mreq_n),
        .IORQ_n(main_iorq_n),
        .RD_n(main_rd_n),
        .WR_n(main_wr_n),
        .A(bus_addr),
        .DI(bus_din),
        .DO(bus_dout)
    );

    assign rom_addr = bus_addr[14:0];

    spram #(10,8) wram (
        .clock(clk),
        .enable(sel_wram),
        .address(bus_addr[9:0]),
        .data(bus_dout),
        .q(wram_dout),
        .wren(!main_wr_n && cpu_en)
    );

    dpram #(11,8) playfield_ram (
        .clock_a(clk),
        .clock_b(clk),
        .enable_a(sel_playfield),
        .wren_a(!main_wr_n),
        .address_a(bus_addr[10:0]),
        .data_a(bus_dout),
        .q_a(playfield_q_a),
        .enable_b(1'b1),
        .wren_b(1'b0),
        .address_b(video_playfield_addr),
        .data_b(8'h00),
        .q_b(video_playfield_q)
    );

    logic [7:0] ball1_x, ball1_y, ball2_x, ball2_y, crow_x, crow_y, io_rd_data;
    logic [2:0] ball1_pic, ball2_pic;
    logic [3:0] crow_pic;
    logic       crow_flip;
    logic [1:0] palette_bank, hit_mode;
    logic       controller_select, flip_screen;
    logic       hit_clear, sound_latch_wr;
    logic [15:0] collision_latch;
    logic [1:0] pc3259_mask;
    logic       sound_stop;
    logic [7:0] latch_data;

    logic main_wr_n_d1;
    logic io_write_stroke;

    always_ff @(posedge clk) begin
        main_wr_n_d1 <= main_wr_n;
    end
    assign io_write_stroke = cpu_en && !main_iorq_n && !main_wr_n && main_wr_n_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ball1_x           <= 8'h00; 
            ball1_y           <= 8'h00;
            ball2_x           <= 8'h00; 
            ball2_y           <= 8'h00;
            crow_x            <= 8'h00; 
            crow_y            <= 8'h00;
            ball1_pic         <= 3'b000; 
            ball2_pic         <= 3'b000;
            crow_pic          <= 4'b0000; 
            crow_flip         <= 1'b0;
            palette_bank      <= 2'b00; 
            controller_select <= 1'b0;
            flip_screen       <= 1'b0; 
            hit_mode          <= 2'b00;
            hit_clear         <= 1'b0; 
            sound_latch_wr    <= 1'b0;
            pc3259_mask       <= 2'b00;
            sound_stop        <= 1'b0;
            latch_data        <= 8'h00;
        end else begin
            hit_clear      <= 1'b0;
            sound_latch_wr <= 1'b0;
            
            if (io_write_stroke) begin
                unique case (bus_addr[7:0])
                    8'h00: ball1_x <= ~bus_dout;
                    8'h01: ball1_y <= ~bus_dout;
                    8'h02: ball2_x <= ~bus_dout;
                    8'h03: ball2_y <= ~bus_dout;
                    8'h04: crow_x  <= ~bus_dout;
                    8'h05: crow_y  <= ~bus_dout;
                    8'h06: pc3259_mask <= bus_dout[1:0]; 
                    8'h08: begin//cont1
                        controller_select <= bus_dout[1];
                        flip_screen       <= bus_dout[2];
                        crow_pic          <= bus_dout[7:4];
                    end
                    8'h09: begin//cont2
                        ball1_pic <= bus_dout[2:0];
                        ball2_pic <= bus_dout[5:3];
                        hit_mode  <= bus_dout[7:6];
                    end
                    8'h0a: begin//cont3
                        crow_flip    <= !bus_dout[0];
                        palette_bank <= bus_dout[2:1];
                        sound_stop   <= bus_dout[3];
                    end
                    8'h0b: begin
                        sound_latch_wr <= 1'b1;
                        latch_data     <= {bus_dout[0], bus_dout[1], bus_dout[2], bus_dout[3],
                                           bus_dout[4], bus_dout[5], bus_dout[6], bus_dout[7]};
                    end
                    8'h0d: begin
                        hit_clear   <= 1'b1;
                        pc3259_mask <= 2'b00;
                    end
                    default: ;
                endcase
            end
        end
    end


    logic [7:0] active_track_x;
    logic [7:0] active_track_y;
    
    assign active_track_x = controller_select ? track1_x_din : track0_x_din;
    assign active_track_y = controller_select ? track1_y_din : track0_y_din;

    always_comb begin
        io_rd_data = 8'hFF;
        if (!main_iorq_n && !main_rd_n) begin
            if (bus_addr[7:0] >= 8'h07 && bus_addr[7:0] <= 8'h1F) begin
                unique case (pc3259_mask[1:0])
                    2'b00: io_rd_data = {collision_latch[3:0],   4'h0};
                    2'b01: io_rd_data = {collision_latch[7:4],   4'h0};
                    2'b10: io_rd_data = {collision_latch[11:8],  4'h0};
                    2'b11: io_rd_data = {collision_latch[15:12], 4'h0};
                endcase
            end else begin
                unique case (bus_addr[7:0])
                    8'h00:   io_rd_data = in0_din;
                    8'h01:   io_rd_data = in1_din;
                    8'h02:   io_rd_data = dswa_din;
                    8'h03:   io_rd_data = dswb_din;
                    8'h04:   io_rd_data = dswc_din;
                    8'h05:   io_rd_data = active_track_x;
                    8'h06:   io_rd_data = active_track_y;
                    default: io_rd_data = 8'hFF;
                endcase
            end
        end
    end

    always_comb begin
        bus_din = 8'hFF;
        if (!main_rd_n) begin
            if (!main_mreq_n) begin
                if (sel_rom)        bus_din = rom_do;
                else if (sel_wram)   bus_din = wram_dout;
                else if (sel_playfield) bus_din = playfield_q_a;
            end else if (!main_iorq_n) begin
                bus_din = io_rd_data;
            end
        end
    end


    BKing_Video video_inst (
        .clk(clk),
        .rst_n(rst_n),
        .scroll_x(crow_x),
        .scroll_y(crow_y),
        .palette_bank(palette_bank),
        .flip_screen(flip_screen),
        .playfield_addr(video_playfield_addr),
        .playfield_q(video_playfield_q),
        .ball1_x(ball1_x),
        .ball1_y(ball1_y),
        .ball1_pic(ball1_pic),
        .ball2_x(ball2_x),
        .ball2_y(ball2_y),
        .ball2_pic(ball2_pic),
        .crow_x(crow_x),
        .crow_y(crow_y),
        .crow_pic(crow_pic),
        .crow_flip(crow_flip),
        .hit_mode(hit_mode),
        .hit_clear(hit_clear),
        .pc3259_mask(pc3259_mask),
        .collision_latch(collision_latch),
        .main_int_n(main_int_n),
        .Video_R(Video_R),
        .Video_G(Video_G),
        .Video_B(Video_B),
        .Video_HS(Video_HS),
        .Video_VS(Video_VS),
        .Video_HB(Video_HB),
        .Video_VB(Video_VB)
    );


    BKing_Audio audio_inst (
        .clk(clk),
        .rst_n(rst_n),
        .sound_latch_wr(sound_latch_wr),
        .sound_latch_din(latch_data),
        .sound_stop(sound_stop),
		  .snd_addr(snd_addr),
		  .snd_do(snd_do),
        .audio_out(audio_out)
    );

endmodule
