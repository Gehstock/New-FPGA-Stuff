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
    output logic [1:0]   mob_color,
    output logic [1:0]   mob_data
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

    logic [2:0]  pipe1_sprite_x_offset;
    logic        pipe1_mob_active_zone;
    logic [1:0]  pipe1_mob_color;
    logic        pipe1_hcnt0;

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
        active_mob_idx  = 4'd0;
        sprite_x_offset = 3'd0;
        sprite_y_offset = 3'd0;
        
        for (int i = 0; i < 16; i++) begin
            logic [7:0] eff_y;
            logic [8:0] comp_x;
            
            eff_y = 8'd248 - mob_y[i];
            comp_x = 9'(Hcnt[8:1]) - 9'(mob_x[i]);
            
            if ((comp_x < 9'd8) && (Hcnt[8:1] < 8'd248) && (Vcnt >= eff_y) && (Vcnt < eff_y + 8)) begin
                mob_active_zone = 1'b1;
                active_mob_idx  = i[3:0];
                sprite_x_offset = comp_x[2:0];
                sprite_y_offset = Vcnt - eff_y;
                break;
            end
        end
    end

    logic [2:0] eff_sprite_y_offset;
    assign eff_sprite_y_offset = mob_pic[active_mob_idx][7] ? ~sprite_y_offset : sprite_y_offset;

    assign sprite_rom0_addr = { 1'b0, ~H256n, mob_pic[active_mob_idx][5:0], eff_sprite_y_offset };
    assign sprite_rom1_addr = { 1'b1, ~H256n, mob_pic[active_mob_idx][5:0], eff_sprite_y_offset };

    E6 E6_sprite_rom ( 
        .clk    ( Clk12 ), 
        .addr_a ( sprite_rom0_addr ), 
        .data_a ( sprite_rom0_data ), 
        .addr_b ( sprite_rom1_addr ),
        .data_b ( sprite_rom1_data )
    );

    always_ff @(posedge Clk12 or posedge Reset) begin
        if (Reset) begin
            pipe1_sprite_x_offset <= 3'd0;
            pipe1_mob_active_zone <= 1'b0;
            pipe1_mob_color       <= 2'b00;
            pipe1_hcnt0           <= 1'b0;
        end else begin
            pipe1_sprite_x_offset <= sprite_x_offset;
            pipe1_mob_active_zone <= mob_active_zone;
            pipe1_hcnt0           <= Hcnt[0];
            pipe1_mob_color       <= { (Vcnt[7] ^ 1'b1), Hcnt[8] };
        end
    end

    logic [7:0] sprite_bit_select;
    logic        sprite_bit_rom0;
    logic        sprite_bit_rom1;

    always_comb begin
        sprite_bit_select = 8'h80 >> {pipe1_sprite_x_offset[2:1], pipe1_hcnt0};
        
        sprite_bit_rom0 = |(sprite_rom0_data & sprite_bit_select);
        sprite_bit_rom1 = |(sprite_rom1_data & sprite_bit_select);
        
        if (pipe1_mob_active_zone && (sprite_bit_rom0 || sprite_bit_rom1)) begin
            mob_pixel = 1'b1;
            mob_color = pipe1_mob_color;
            mob_data  = { sprite_bit_rom1, sprite_bit_rom0 };
        end else begin
            mob_pixel = 1'b0;
            mob_color = 2'b00;
            mob_data  = 2'b00;
        end
    end

endmodule
