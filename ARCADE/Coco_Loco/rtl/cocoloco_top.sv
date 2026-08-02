
`default_nettype none

module cocoloco_top (
    input  wire        clk,              
    input  wire        reset,            
    input  wire [7:0]  input_port_in0,
    input  wire [7:0]  dsw1,             
    input  wire [7:0]  dsw2,             
    output wire        video_hsync,
    output wire        video_vsync,
    output wire [3:0]  video_r,
    output wire [3:0]  video_g,
    output wire [3:0]  video_b,
    output wire        video_hblank,    
    output wire        video_vblank,    
    output wire [9:0]  audio_out
);

    reg [3:0] clk_div;
    reg       clk_cpu_en; 
    reg       clk_snd_en; 
    reg       clk_pix_en; 

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div    <= 4'd0;
            clk_cpu_en <= 1'b0;
            clk_snd_en <= 1'b0;
            clk_pix_en <= 1'b0;
        end else begin
            clk_div    <= clk_div + 1'b1;
            clk_pix_en <= (clk_div[1:0] == 2'b11);  
            clk_snd_en <= (clk_div[2:0] == 3'b111); 
            clk_cpu_en <= (clk_div == 4'b1111);     
        end
    end

    wire        res_n = ~reset;
    wire [23:0] cpu_addr;
    wire [7:0]  cpu_data_out;
    reg  [7:0]  cpu_data_in;
    wire        cpu_rw_n;
    wire        cpu_write = ~cpu_rw_n;
    
    reg         nmi_n;
    reg         coin_old;

    wire [7:0]  video_vram_q; 
    wire [7:0]  rom_q;
    wire [7:0]  psg_data_out;

    reg  [3:0]  video_bank;

    T65 cpu_inst (
        .Res_n(res_n), 
        .Enable(clk_cpu_en), 
        .Clk(clk),
        .Rdy(1'b1), 
        .Abort_n(1'b1), 
        .IRQ_n(1'b1), 
        .NMI_n(nmi_n), 
        .SO_n(1'b1), 
        .R_W_n(cpu_rw_n),
        .A(cpu_addr), 
        .DI(cpu_data_in), 
        .DO(cpu_data_out)
    );


    wire is_wram   = (cpu_addr[15:13] == 3'b000);  // $0000 - $1FFF (Haupt-RAM)
    wire is_vram   = (cpu_addr[15:13] == 3'b001);  // $2000 - $3FFF (Video-RAM)
    wire unified_ram_cs = is_wram || is_vram;
    wire is_psg_rd = (cpu_addr[15:0]  == 16'h6001);
    wire is_psg_wr = (cpu_addr[15:0]  == 16'h6002);
    wire is_psg_ad = (cpu_addr[15:0]  == 16'h6003);
    wire is_vbank  = (cpu_addr[15:0]  == 16'h8003);
    wire is_port0  = (cpu_addr[15:0]  == 16'hA000);
    wire is_prom_rd= (cpu_addr[15:0]  == 16'hA005);
    
    wire is_rom    = (cpu_addr[15:14] == 2'b11); 
    wire [13:0] rom_addr = 14'(cpu_addr[15:0] - 16'hC000);

    always_comb begin
        if (unified_ram_cs) cpu_data_in = video_vram_q;
        else if (is_psg_rd) cpu_data_in = psg_data_out;
        else if (is_port0)  cpu_data_in = input_port_in0; 
        else if (is_prom_rd)cpu_data_in = 8'hFF;
        else if (is_rom)    cpu_data_in = rom_q;
        else                cpu_data_in = 8'hFF; 
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset)                                    video_bank <= 4'b0000;
        else if (clk_cpu_en && cpu_write && is_vbank) video_bank <= cpu_data_out[3:0];
    end

    main_rom main_rom(
        .clk(clk),
        .addr(rom_addr),
        .data(rom_q)
    );

    reg coin_sync_0, coin_sync_1;
    reg coin_reg_old;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            coin_sync_0  <= 1'b0;
            coin_sync_1  <= 1'b0;
            coin_reg_old <= 1'b0;
        end else begin
            coin_sync_0  <= input_port_in0[0];
            coin_sync_1  <= coin_sync_0;
            if (clk_cpu_en) begin
                coin_reg_old <= coin_sync_1;
            end
        end
    end

    reg [3:0] nmi_counter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            nmi_n       <= 1'b1;
            nmi_counter <= 4'd0;
        end else if (clk_cpu_en) begin
            if (coin_sync_1 && !coin_reg_old) begin
                nmi_n       <= 1'b0;
                nmi_counter <= 4'd8;
            end else if (nmi_counter != 4'd0) begin
                nmi_counter <= nmi_counter - 1'b1;
                if (nmi_counter == 4'd1) begin
                    nmi_n <= 1'b1;
                end
            end
        end
    end


    cocoloco_audio audio_module (
        .clk(clk), 
		  .clk_snd_en(clk_snd_en), 
		  .reset(reset),
        .psg_rd(is_psg_rd), 
		  .psg_wr(is_psg_wr), 
		  .psg_ad(is_psg_ad),
        .dsw1(dsw1), 
		  .dsw2(dsw2), 
		  .data_in(cpu_data_out), 
		  .data_out(psg_data_out), 
		  .audio_out(audio_out)
    );

    cocoloco_video video_module (
        .clk            (clk),
        .clk_pix_en     (clk_pix_en),
        .clk_cpu_en     (clk_cpu_en),
        .reset          (reset),
        .cpu_vram_cs    (unified_ram_cs),       
        .cpu_vram_wr    (cpu_write),
        .cpu_vram_bank  (video_bank),
        .cpu_vram_addr  (cpu_addr[13:0]),
        .cpu_vram_data  (cpu_data_out),
        .cpu_vram_q     (video_vram_q),
        .video_hsync    (video_hsync),
        .video_vsync    (video_vsync),
        .video_r        (video_r),
        .video_g        (video_g),
        .video_b        (video_b),
        .video_hblank   (video_hblank), 
        .video_vblank   (video_vblank)  
    );

endmodule

