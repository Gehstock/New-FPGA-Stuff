module warlords_sprites (
    input  logic         Clk12,
    input  logic         Reset,
    input  logic [11:0]  Hcnt,
    input  logic [7:0]   Vcnt,
    input  logic [23:0]  Ab,
    input  logic [7:0]   DbOut,
    input  logic         Pf_n,
    input  logic         Write_n,
    input  logic         H256n,
    input  logic [7:0]   Pf_rom0_out,
    input  logic [7:0]   Pf_rom1_out,
    output logic         mob_pixel,
    output logic [1:0]   mob_color
);

    logic [7:0]  mob_x[0:15];
    logic [7:0]  mob_y[0:15];
    logic [7:0]  mob_pic[0:15];
    logic [7:0]  mob_attr[0:15];
    logic        mob_active_zone;
    logic [3:0]  active_mob_idx;
    logic [2:0]  sprite_x_offset;
    logic [2:0]  sprite_y_offset;

    logic [10:0] sprite_rom0_addr;
    logic [10:0] sprite_rom1_addr;
    logic [7:0]  sprite_rom0_data;
    logic [7:0]  sprite_rom1_data;
    logic [7:0]  sprite_bit_select;
    logic        sprite_bit_rom0;
    logic        sprite_bit_rom1;

    logic [3:0]  r_active_mob_idx;
    logic [2:0]  r_sprite_x_offset;
    logic        r_mob_active_zone;
    logic        r_hcnt0;
    logic [1:0]  r_mob_color;

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            for (int i=0; i<16; i++) begin
                mob_x[i]    <= 8'd0;
                mob_y[i]    <= 8'd0;
                mob_pic[i]  <= 8'd0;
                mob_attr[i] <= 8'd0;
            end
        end else if (!Write_n && !Pf_n && (Ab[9:6] == 4'hF)) begin
            case(Ab[5:4])
                2'b00: mob_pic[Ab[3:0]]  <= DbOut;
                2'b01: mob_y[Ab[3:0]]    <= DbOut;
                2'b10: mob_x[Ab[3:0]]    <= DbOut;
                2'b11: mob_attr[Ab[3:0]] <= DbOut;
            endcase
        end
    end

    always_comb begin
        mob_active_zone = 1'b0;
        active_mob_idx = 4'd0;
        sprite_x_offset = 3'd0;
        sprite_y_offset = 3'd0;
        for (int i = 0; i < 16; i++) begin
            if ((Hcnt[8:1] >= mob_x[i]) && (Hcnt[8:1] < mob_x[i] + 8) &&
                (Vcnt >= mob_y[i]) && (Vcnt < mob_y[i] + 8)) begin
                mob_active_zone = 1'b1;
                active_mob_idx = i[3:0];
                sprite_x_offset = Hcnt[8:1] - mob_x[i];
                sprite_y_offset = Vcnt - mob_y[i];
                break;
            end
        end
    end

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            r_active_mob_idx  <= 4'd0;
            r_sprite_x_offset <= 3'd0;
            r_mob_active_zone <= 1'b0;
            r_hcnt0           <= 1'b0;
            r_mob_color       <= 2'b00;
        end else begin
            r_active_mob_idx  <= active_mob_idx;
            r_sprite_x_offset <= sprite_x_offset;
            r_mob_active_zone <= mob_active_zone;
            r_hcnt0           <= Hcnt[0];
            r_mob_color       <= mob_attr[active_mob_idx][1:0];
        end
    end

    assign sprite_rom0_addr = { 1'b0, ~H256n, mob_pic[active_mob_idx][5:0], sprite_y_offset };
    assign sprite_rom1_addr = { 1'b1, ~H256n, mob_pic[active_mob_idx][5:0], sprite_y_offset };

    E6 E6_sprite_rom ( 
        .clk(Clk12), 
        .addr_a(sprite_rom0_addr), 
        .data_a(sprite_rom0_data),
        .addr_b(sprite_rom1_addr),
        .data_b(sprite_rom1_data)
    );

    always_comb begin
        sprite_bit_select = 8'h80 >> {r_sprite_x_offset[2:1], r_hcnt0};
        sprite_bit_rom0 = |(sprite_rom0_data & sprite_bit_select);
        sprite_bit_rom1 = |(sprite_rom1_data & sprite_bit_select);
        
        if (r_mob_active_zone && (sprite_bit_rom0 || sprite_bit_rom1)) begin
            mob_pixel = 1'b1;
            mob_color = r_mob_color;
        end else begin
            mob_pixel = 1'b0;
            mob_color = 2'b00;
        end
    end

endmodule

