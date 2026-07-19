//`timescale 1ns / 1ps
//
//module draw_terrain (
//    input  logic        clk_12M,
//    input  logic        rst_n,
//    input  logic        blank,
//    input  logic [8:0]  v_cnt,
//    input  logic [6:0]  terrain_h_cnt,
//    input  logic [7:0]  reg_scroll,
//    output logic [2:0]  current_terrain_pixel
//);
//
//    logic [10:0] terrain_rom_addr;
//    logic [7:0]  terrain_rom_data;
//
//    j5 rom_terrain_low (
//        .clk(clk_12M),
//        .addr(terrain_rom_addr),
//        .data(terrain_rom_data[3:0])
//    );
//
//    k5 rom_terrain_high (
//        .clk(clk_12M),
//        .addr(terrain_rom_addr),
//        .data(terrain_rom_data[7:4])
//    );
//
//    logic [4:0] rom_count_data;
//    logic [2:0] rom_color;
//    
//    assign rom_count_data = terrain_rom_data[4:0]; 
//    assign rom_color      = terrain_rom_data[7:5]; 
//
//    logic [11:0] scroll_offset;
//    logic [11:0] line_offset;
//    logic [11:0] target_base_addr;
//
//    always_comb begin
//        scroll_offset    = {4'b0000, reg_scroll} << 4;
//        line_offset      = {3'b000, 9'(v_cnt + 9'd1) >> 1} << 4;
//        target_base_addr = (scroll_offset + line_offset) & 12'h7FF;
//    end
//
//    logic [4:0] f5_counter;
//    logic       f5_co;
//    assign f5_co = (f5_counter == 5'h1F); 
//
//    logic [2:0] current_color;
//    logic [6:0] last_terrain_h_cnt;
//    logic       load_next_rle;
//    logic       prefetch_phase;
//
//    assign load_next_rle = f5_co || prefetch_phase;
//
//    always_ff @(posedge clk_12M or negedge rst_n) begin
//        if (!rst_n) begin
//            terrain_rom_addr      <= '0;
//            f5_counter            <= '0;
//            current_color         <= '0;
//            current_terrain_pixel <= '0;
//            last_terrain_h_cnt    <= '0;
//            prefetch_phase        <= 1'b0;
//        end else begin
//            last_terrain_h_cnt <= terrain_h_cnt;
//
//            if (terrain_h_cnt == 7'd0) begin
//                terrain_rom_addr <= target_base_addr[10:0];
//                prefetch_phase   <= 1'b1;
//                f5_counter       <= 5'h1F;
//                current_terrain_pixel <= '0;
//            end 
//            else if (!blank) begin
//                if (terrain_h_cnt != last_terrain_h_cnt) begin
//                    current_terrain_pixel <= current_color;
//
//                    if (load_next_rle) begin
//                        f5_counter       <= rom_count_data;
//                        current_color    <= rom_color;
//                        terrain_rom_addr <= (terrain_rom_addr + 1'b1) & 11'h7FF;
//                        prefetch_phase   <= 1'b0;
//                    end else begin
//                        f5_counter       <= f5_counter + 1'b1;
//                    end
//                end
//            end else begin
//                current_terrain_pixel <= '0;
//                prefetch_phase        <= 1'b0;
//            end
//        end
//    end
//
//endmodule
`timescale 1ns / 1ps

module draw_terrain (
    input  logic        clk_12M,
    input  logic        rst_n,
    input  logic        blank,
    input  logic [8:0]  v_cnt,
    input  logic [6:0]  terrain_h_cnt,
    input  logic [7:0]  reg_scroll,
    output logic [2:0]  current_terrain_pixel
);

    logic [10:0] terrain_rom_addr;
    logic [7:0]  terrain_rom_data;

    j5 rom_terrain_low (
        .clk(clk_12M),
        .addr(terrain_rom_addr),
        .data(terrain_rom_data[3:0])
    );

    k5 rom_terrain_high (
        .clk(clk_12M),
        .addr(terrain_rom_addr),
        .data(terrain_rom_data[7:4])
    );

    logic [11:0] scroll_offset;
    logic [11:0] line_offset;
    logic [10:0] target_base_addr;

        always_comb begin
        scroll_offset    = {4'b0000, reg_scroll} << 4;
        line_offset      = {3'b000, 9'(v_cnt + 9'd1) >> 1} << 4;
        target_base_addr = 11'((scroll_offset + line_offset) & 12'h7FF);
    end


    logic [2:0] line_buffer [127:0];
    logic [6:0] write_ptr;
    logic [4:0] rle_len_cnt;
    logic [2:0] rle_color_reg;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_INIT,
        ST_READ_ROM,
        ST_DECODE_RLE
    } state_t;
    state_t state;

    logic blank_d1;
    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            blank_d1 <= 1'b1;
        end else begin
            blank_d1 <= blank;
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            terrain_rom_addr <= '0;
            write_ptr        <= '0;
            rle_len_cnt      <= '0;
            rle_color_reg    <= '0;
            for (int i = 0; i < 128; i++) line_buffer[i] <= 3'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (blank && !blank_d1) begin
                        terrain_rom_addr <= target_base_addr;
                        write_ptr        <= '0;
                        state            <= ST_INIT;
                    end
                end

                ST_INIT: begin
                    state <= ST_READ_ROM;
                end

                ST_READ_ROM: begin
                    rle_len_cnt   <= 5'd31 - terrain_rom_data[4:0];
                    rle_color_reg <= terrain_rom_data[7:5];
                    state         <= ST_DECODE_RLE;
                end

                ST_DECODE_RLE: begin
                    line_buffer[write_ptr] <= rle_color_reg;
                    if (write_ptr == 7'd127) begin
                        state <= ST_IDLE;
                    end else begin
                        write_ptr <= write_ptr + 1'b1;
                        if (rle_len_cnt == 5'd0) begin
                            terrain_rom_addr <= (terrain_rom_addr + 1'b1) & 11'h7FF;
                            state            <= ST_READ_ROM;
                        end else begin
                            rle_len_cnt <= rle_len_cnt - 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk_12M or negedge rst_n) begin
        if (!rst_n) begin
            current_terrain_pixel <= 3'd0;
        end else begin
            if (!blank) begin
                current_terrain_pixel <= line_buffer[terrain_h_cnt];
            end else begin
                current_terrain_pixel <= 3'd0;
            end
        end
    end

endmodule
