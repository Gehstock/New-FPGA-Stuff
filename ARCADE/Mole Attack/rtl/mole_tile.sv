module mole_tile (
    input  logic        clk_sys,
    input  logic [9:0]  cpu_addr,
    input  logic [7:0]  cpu_din,
    input  logic        cpu_we,
    output logic [7:0]  cpu_dout,
    input  logic [7:0]  tile_bank,
    input  logic [7:0]  video_flip,
    input  logic [9:0]  h_count,
    input  logic [8:0]  v_count,
    output logic [2:0]  rgb_out
);

    logic [5:0]  tile_col;
    logic [4:0]  tile_row;
    logic [5:0]  final_col;
    logic [4:0]  final_row;
    logic [9:0]  video_tile_addr;
    
    logic [15:0] video_tile_a;
    logic [15:0] video_tile_b;
    
    logic [1:0]  current_tile_bank;
    logic [7:0]  current_tile_id;
    
    logic [11:0] gfx_rom_addr;
    logic [2:0]  pixel_bit_pipe1;
    logic [2:0]  pixel_bit_pipe2;
    logic [2:0]  pixel_bit_pipe3;
    
    logic [1:0]  bank_pipe1;
    logic [1:0]  bank_pipe2;
    logic [1:0]  bank_pipe3;

    logic [7:0]  rom_maa_data;
    logic [7:0]  rom_mba_data;
    logic [7:0]  rom_mca_data;
    logic [7:0]  rom_mda_data;
    logic [7:0]  rom_mea_data;
    logic [7:0]  rom_mfa_data;

    assign tile_col = h_count[8:3];
    assign tile_row = v_count[7:3];
    
    assign final_col = video_flip ? (6'd39 - tile_col) : tile_col;
    assign final_row = video_flip ? (5'd24 - tile_row) : tile_row;
    
    assign video_tile_addr = (final_row * 6'd40) + final_col;

    dpram #(
        .address_width(10),
        .data_width(16)
    ) video_tile_ram (
        .clock_a   (clk_sys),
        .clock_b   (clk_sys),
        .enable_a  (1'b1),
        .wren_a    (cpu_we),
        .address_a (cpu_addr),
        .data_a    ({6'b000000, tile_bank[1:0], cpu_din}),
        .q_a       (video_tile_a),

        .enable_b  (1'b1),
        .wren_b    (1'b0),
        .address_b (video_tile_addr),
        .data_b    (16'h0000),
        .q_b       (video_tile_b)
    );

    assign cpu_dout          = video_tile_a[7:0];
    assign current_tile_bank = video_tile_b[9:8];
    assign current_tile_id   = video_tile_b[7:0];

    always_ff @(posedge clk_sys) begin
        pixel_bit_pipe1 <= video_flip ? h_count[2:0] : (3'd7 - h_count[2:0]);
        gfx_rom_addr    <= video_flip ? {current_tile_bank[0], current_tile_id, ~v_count[2:0]} : {current_tile_bank[0], current_tile_id, v_count[2:0]};
        
        pixel_bit_pipe2 <= pixel_bit_pipe1;
        pixel_bit_pipe3 <= pixel_bit_pipe2;
        
        bank_pipe1      <= current_tile_bank;
        bank_pipe2      <= bank_pipe1;
        bank_pipe3      <= bank_pipe2;
    end

    rom_maa gfx_inst_maa (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_maa_data));
    rom_mba gfx_inst_mba (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_mba_data));
    rom_mca gfx_inst_mca (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_mca_data));
    rom_mda gfx_inst_mda (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_mda_data));
    rom_mea gfx_inst_mea (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_mea_data));
    rom_mfa gfx_inst_mfa (.clk(clk_sys), .addr(gfx_rom_addr), .data(rom_mfa_data));

    logic p0_bit, p1_bit, p2_bit;

    always_comb begin
        if (bank_pipe3[1] == 1'b0) begin
            p0_bit = rom_maa_data[pixel_bit_pipe3];
            p1_bit = rom_mca_data[pixel_bit_pipe3];
            p2_bit = rom_mea_data[pixel_bit_pipe3];
        end else begin
            p0_bit = rom_mba_data[pixel_bit_pipe3];
            p1_bit = rom_mda_data[pixel_bit_pipe3];
            p2_bit = rom_mfa_data[pixel_bit_pipe3];
        end
    end

    always_ff @(posedge clk_sys) begin
        rgb_out <= {p2_bit, p1_bit, p0_bit};
    end

endmodule
