module skyarmy_main (
    input  wire        clk_sys,       // Hauptsystemtakt (z. B. ~18.432 MHz)
    input  wire        rst_n,         // Asynchroner Reset (Aktiv-Low)
    input  wire [7:0]  dsw_input,     // Dip-Switches
    input  wire [7:0]  p1_input,      // Player 1 Eingaben
    input  wire [7:0]  p2_input,      // Player 2 Eingaben
    input  wire [7:0]  system_input,  // System-Eingaben (Coins, Start)
    output wire        blank,         // VGA Blanking-Signal
    output wire        hsync,         // VGA Horizontale Synchronisation
    output wire        vsync,         // VGA Vertikale Synchronisation
    output wire [3:0]  video_r,       // 4-Bit VGA Ausgang Rot
    output wire [3:0]  video_g,       // 4-Bit VGA Ausgang Grün
    output wire [3:0]  video_b,       // 4-Bit VGA Ausgang Blau
    output wire [8:0]  audio_out      // Gemischter Audio-Ausgang
);

    reg [1:0] clk_counter;
    reg       clk_z80_reg;
    reg [7:0] cpu_acc;

    reg [2:0] z80_clk_div;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 2'd0;
            z80_clk_div <= 3'd0;
            clk_z80_reg <= 1'b0;
        end else begin
            if (clk_counter >= 2'd2) begin
                clk_counter <= 2'd0;
            end else begin
                clk_counter <= clk_counter + 1'b1;
            end

            if (z80_clk_div >= 3'd2) begin
                z80_clk_div <= 3'd0;
                clk_z80_reg <= ~clk_z80_reg;
            end else begin
                z80_clk_div <= z80_clk_div + 1'b1;
            end
        end
    end


    wire clk_pixel = (clk_counter == 2'd0); 
    wire clk_z80   = clk_z80_reg;
    reg [8:0] h_counter;
    reg [8:0] v_counter;

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            h_counter <= 9'd0;
            v_counter <= 9'd0;
        end else begin
            if (h_counter >= 9'd383) begin
                h_counter <= 9'd0;
                if (v_counter >= 9'd263) begin
                    v_counter <= 9'd0;
                end else begin
                    v_counter <= v_counter + 1'b1;
                end
            end else begin
                h_counter <= h_counter + 1'b1;
            end
        end
    end

    assign hsync = ~((h_counter >= 9'd298) && (h_counter < 9'd326));
    assign vsync = ~((v_counter >= 9'd250) && (v_counter < 9'd254));
    assign blank = !((h_counter >= 9'd2 && h_counter < 9'd262) && (v_counter >= 9'd8 && v_counter < 9'd248));

    reg [3:0] nmi_divider;
    reg       z80_nmi_n;
    reg       z80_int_n;
    reg       int_triggered;
    reg       nmi_triggered;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            nmi_divider   <= 4'd0;
            z80_nmi_n     <= 1'b1;
            z80_int_n     <= 1'b1;
            int_triggered <= 1'b0;
            nmi_triggered <= 1'b0;
        end else begin
            
            if (v_counter < 9'd240 && nmi_mask) begin
                if (h_counter == 9'd0 && (v_counter[3:0] == 4'd0)) begin
                    if (!nmi_triggered) begin
                        z80_nmi_n     <= 1'b0;
                        nmi_triggered <= 1'b1;
                    end
                end else begin
                    z80_nmi_n <= 1'b1;
                    if (h_counter == 9'd383) nmi_triggered <= 1'b0;
                end
            end else begin
                z80_nmi_n     <= 1'b1;
                nmi_triggered <= 1'b0;
            end

            if (v_counter == 9'd248) begin
                if (!int_triggered) begin
                    z80_int_n     <= 1'b0;
                    int_triggered <= 1'b1;
                end else if (!cpu_iorq_n && !cpu_m1_n) begin
                    z80_int_n     <= 1'b1;
                end
            end else begin
                z80_int_n     <= 1'b1;
                if (v_counter == 9'd0) int_triggered <= 1'b0;
            end
        end
    end

    wire [15:0] cpu_addr;
    reg  [7:0]  cpu_data_to_cpu;
    wire [7:0]  cpu_data_from_cpu;
    wire        cpu_mreq_n;
    wire        cpu_iorq_n;
    wire        cpu_rd_n;
    wire        cpu_wr_n;
    wire        cpu_m1_n;
    wire cpu_wr   = !cpu_mreq_n && !cpu_wr_n;
    wire cpu_io_r = !cpu_iorq_n && !cpu_rd_n && cpu_m1_n;
    wire cpu_io_w = !cpu_iorq_n && !cpu_wr_n && cpu_m1_n;
    wire [7:0] rom_data_out;
    u_program_rom u_program_rom (
        .clk  (clk_sys),
        .addr (cpu_addr[14:0]),
        .data (rom_data_out)
    );

    wire [7:0] ram_data_out;
    wire       ram_wren = cpu_wr && (cpu_addr >= 16'h8000 && cpu_addr <= 16'h87FF);

    spram #(.address_width(11), .data_width(8)) u_main_ram (
        .clock   (clk_sys),
        .address (cpu_addr[10:0]),
        .data    (cpu_data_from_cpu),
        .wren    (ram_wren),
        .q       (ram_data_out)
    );

    wire [7:0] vram_data_out;
    wire [7:0] cram_data_out;
    wire [7:0] sram_data_out;
    wire [7:0] scram_data_out;

    skyarmy_video u_video (
        .clk_sys          (clk_sys),
        .clk_pixel        (clk_pixel),
        .rst_n            (rst_n),
        .flip_x           (flip_screen_x),
        .flip_y           (flip_screen_y),
        .h_cnt_in         (h_counter),
        .v_cnt_in         (v_counter),
        .cpu_addr         (cpu_addr),
        .cpu_data_in      (cpu_data_from_cpu),
        .cpu_we           (cpu_wr),
        .vram_data_out    (vram_data_out),
        .cram_data_out    (cram_data_out),
        .sram_data_out    (sram_data_out),
        .scram_data_out   (scram_data_out),
        .video_r          (video_r),
        .video_g          (video_g),
        .video_b          (video_b)
    );

    wire [7:0] audio_data_out;

    skyarmy_audio u_audio (
        .clk_sys        (clk_sys),
        .rst_n          (rst_n),
        .cpu_addr       (cpu_addr),
        .cpu_data_in    (cpu_data_from_cpu),
        .audio_data_out (audio_data_out),
        .cpu_io_rd      (cpu_io_r),
        .cpu_io_wr    (cpu_io_w),
        .sound_mix_out  (audio_out)
    );
     
    reg        nmi_mask;
    reg        flip_screen_x;
    reg        flip_screen_y;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            nmi_mask      <= 1'b0;
            flip_screen_x <= 1'b0;
            flip_screen_y <= 1'b0;
        end else begin
            if (cpu_wr && (cpu_addr >= 16'hA000 && cpu_addr <= 16'hA007)) begin
                case (cpu_addr[2:0])
                    3'd4: nmi_mask      <= cpu_data_from_cpu[0];
                    3'd5: flip_screen_x <= cpu_data_from_cpu[0];
                    3'd6: flip_screen_y <= cpu_data_from_cpu[0];
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        cpu_data_to_cpu = 8'hFF;
        
        if (!cpu_mreq_n) begin
            if (cpu_addr <= 16'h7FFF) begin
                cpu_data_to_cpu = rom_data_out;
            end else if (cpu_addr <= 16'h87FF) begin
                cpu_data_to_cpu = ram_data_out;
            end else if (cpu_addr <= 16'h8FFF) begin
                cpu_data_to_cpu = vram_data_out;
            end else if (cpu_addr >= 16'h9000 && cpu_addr <= 16'h93FF) begin
                cpu_data_to_cpu = cram_data_out;
            end else if (cpu_addr >= 16'h9800 && cpu_addr <= 16'h983F) begin
                cpu_data_to_cpu = sram_data_out;
            end else if (cpu_addr >= 16'h9840 && cpu_addr <= 16'h985F) begin
                cpu_data_to_cpu = scram_data_out;
            end else begin
                case (cpu_addr)
                    16'hA000: cpu_data_to_cpu = dsw_input;
                    16'hA001: cpu_data_to_cpu = p1_input;
                    16'hA002: cpu_data_to_cpu = p2_input;
                    16'hA003: cpu_data_to_cpu = system_input;
                    default:  cpu_data_to_cpu = 8'hFF;
                endcase
            end
        end else if (cpu_io_r) begin
            cpu_data_to_cpu = audio_data_out;
        end
    end


    T80se u_main_cpu (
        .RESET_n (rst_n),
        .CLK_n   (clk_z80),
        .CLKEN   (1'b1),
        .WAIT_n  (1'b1),
        .INT_n   (z80_int_n),
        .NMI_n   (z80_nmi_n),
        .BUSRQ_n (1'b1),
        .M1_n    (cpu_m1_n),
        .MREQ_n  (cpu_mreq_n),
        .IORQ_n  (cpu_iorq_n),
        .RD_n    (cpu_rd_n),
        .WR_n    (cpu_wr_n),
        .A       (cpu_addr),
        .DI      (cpu_data_to_cpu),
        .DO      (cpu_data_from_cpu)
    );

endmodule
