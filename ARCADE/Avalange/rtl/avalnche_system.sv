// Atari Avalanche (1978) on MiST FPGA
// (Gehstock 2026)
module avalnche_system (
    input  logic        clk_12m,
    input  logic        reset_n,
    input  logic [7:0]  in0_inputs,
    input  logic [6:0]  in1_inputs,
    input  logic [7:0]  paddle_input,
    output logic        video_hs,
    output logic        video_vs,
    output logic        video_blank,
    output logic [3:0]  video_r,
    output logic [3:0]  video_g,
    output logic [3:0]  video_b,
    output logic [15:0] audio,
    output              dbg
);
    assign dbg = cpu_nmi;
    
    logic        cpu_rw_n;
    logic [23:0] cpu_addr_full;
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_data_to_peripheral;
    logic [7:0]  cpu_data_from_peripheral;
    assign cpu_addr = cpu_addr_full[15:0];
    
    logic [12:0] cpu_vram_addr;
    logic [7:0]  cpu_vram_data;
    logic        vram_wren;
    logic [7:0]  vram_cpu_q;
    logic [8:0]  video_vpos;
    logic        video_inverted;
    logic [5:0]  noise_amplitude;
    logic [2:0]  catch_audio;        
    logic        attract_en;   
    logic [3:0]  clk_div;
    logic        cpu_ena;

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            clk_div <= 4'b0000;
            cpu_ena <= 1'b0;
        end else begin
            clk_div <= clk_div + 1'b1;
            cpu_ena <= (clk_div == 4'b1111);
        end
    end

    logic [15:0] base_addr;
    assign base_addr = cpu_addr & 16'h7FFF;
    assign cpu_vram_addr = base_addr[12:0]; 
    assign cpu_vram_data = cpu_data_to_peripheral;
    assign vram_wren = (base_addr <= 16'h1FFF) && !cpu_rw_n && cpu_ena;
    
    logic [3:0] rom_d2_q;
    logic [3:0] rom_d3_q;   
    logic [3:0] rom_e2_q;
    logic [3:0] rom_e3_q;  
    logic [3:0] rom_c2_q;
    logic [3:0] rom_c3_q;

    rom_d2 rom_d2_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_d2_q));
    rom_d3 rom_d3_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_d3_q));
    rom_e2 rom_e2_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_e2_q));
    rom_e3 rom_e3_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_e3_q));
    rom_c2 rom_c2_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_c2_q));
    rom_c3 rom_c3_inst (.clk(clk_12m), .addr(base_addr[10:0]), .data(rom_c3_q));

    logic [7:0] combined_rom_d;
    logic [7:0] combined_rom_e;
    logic [7:0] combined_rom_c;
    assign combined_rom_d = {rom_d2_q, rom_d3_q};
    assign combined_rom_e = {rom_e2_q, rom_e3_q};
    assign combined_rom_c = {rom_c2_q, rom_c3_q};
    
    logic rom_d_hit, rom_e_hit, rom_c_hit;
    assign rom_d_hit = (base_addr >= 16'h6800 && base_addr <= 16'h6FFF);
    assign rom_e_hit = (base_addr >= 16'h7000 && base_addr <= 16'h77FF);
    assign rom_c_hit = (base_addr >= 16'h7800 && base_addr <= 16'h7FFF);

    always_comb begin
        if (cpu_rw_n) begin
            if (base_addr <= 16'h1FFF) begin
                cpu_data_from_peripheral = vram_cpu_q;				 
            end else if (rom_d_hit) begin
                cpu_data_from_peripheral = combined_rom_d; 
            end else if (rom_e_hit) begin
                cpu_data_from_peripheral = combined_rom_e; 
            end else if (rom_c_hit) begin
                cpu_data_from_peripheral = combined_rom_c; 
            end else if ((base_addr & 16'h7FFC) == 16'h2000) begin
                case (base_addr[1:0])
                    2'd0:    cpu_data_from_peripheral = in0_inputs;   
                    2'd1:    cpu_data_from_peripheral = {(video_vpos < 16) || (video_vpos >= 256), in1_inputs};   
                    2'd2:    cpu_data_from_peripheral = paddle_input; 
                    default: cpu_data_from_peripheral = 8'hFF;        
                endcase
            end else begin
                cpu_data_from_peripheral = 8'hFF;
            end
        end else begin
            cpu_data_from_peripheral = 8'h00; 
        end
    end

    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            video_inverted  <= 1'b0;
            noise_amplitude <= 3'b000;
            catch_audio     <= 3'b000;
            attract_en      <= 1'b0;
        end else begin
            if (cpu_ena && !cpu_rw_n) begin
                if ((base_addr & 16'h7FF8) == 16'h4000) begin
                    case (base_addr[2:0])
                        3'd1: attract_en      <= cpu_data_to_peripheral[0];
                        3'd2: video_inverted  <= cpu_data_to_peripheral[0];
                        3'd4: catch_audio[0]  <= cpu_data_to_peripheral[0]; 
                        3'd5: catch_audio[1]  <= cpu_data_to_peripheral[0]; 
                        3'd6: catch_audio[2]  <= cpu_data_to_peripheral[0]; 
                        default: ;
                    endcase
                end
                if ((base_addr & 16'h7FFF) == 16'h5000) begin
                    noise_amplitude <= cpu_data_to_peripheral[5:0];
                end
            end
        end
    end
     
    logic video_16h_d;
    logic cpu_nmi;
    
    always_ff @(posedge clk_12m or negedge reset_n) begin
        if (!reset_n) begin
            video_16h_d <= 1'b0;
            cpu_nmi     <= 1'b1;
        end else begin
            video_16h_d <= video_vpos[4]; 
            
            if (video_16h_d && !video_vpos[4]) begin
                cpu_nmi <= 1'b0; 
            end else if (cpu_ena && !cpu_nmi) begin
                cpu_nmi <= 1'b1; 
            end
        end
    end

    T65 cpu_inst (
        .Res_n  (reset_n),
        .Enable (cpu_ena), 
        .Clk    (clk_12m), 
        .Rdy    (1'b1), 
        .Abort_n(1'b1),
        .IRQ_n  (1'b1), 
        .NMI_n  (cpu_nmi), 
        .SO_n   (1'b1),
        .R_W_n  (cpu_rw_n), 
        .DI     (cpu_data_from_peripheral), 
        .A      (cpu_addr_full), 
        .DO     (cpu_data_to_peripheral)
    );

    avalnche_sound sound_card (
        .clk_12m         (clk_12m),
        .reset_n         (reset_n),
        .attract_en      (attract_en),
        .aud0_en         (catch_audio[0]), 
        .aud1_en         (catch_audio[1]), 
        .aud2_en         (catch_audio[2]), 
        .noise_amplitude (noise_amplitude),
        .audio           (audio)
    );

    avalnche_video video_card (
        .clk_12m        (clk_12m),
        .reset_n        (reset_n),
        .cpu_vram_addr  (cpu_vram_addr),
        .cpu_vram_data  (cpu_vram_data),
        .vram_wren      (vram_wren),
        .vram_cpu_q     (vram_cpu_q),
        .video_inverted (video_inverted),
        .video_hs       (video_hs),
        .video_vs       (video_vs),
        .video_blank    (video_blank),
        .video_r        (video_r),
        .video_g        (video_g),
        .video_b        (video_b),
        .video_vpos     (video_vpos)
    );

endmodule
