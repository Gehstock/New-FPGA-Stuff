`timescale 1ns / 1ps

module Ambush_Audio (
    input  logic        clk_sys,         
    input  logic        reset,
    input  logic        io_en,           
    input  logic        io_write,        
    input  logic        io_read,         
    input  logic [7:0]  io_addr,         
    input  logic [7:0]  io_data_in,      
    output logic [7:0]  io_data_out,     
    input  logic [7:0]  I_BUTTONS,       
    input  logic [7:0]  I_JOYSTICK,      
    output logic [8:0] audio
);

    logic [3:0] audio_clk_div;
    logic       cen_audio;
	 logic ay1_sel, ay2_sel;
    logic port_data_sel;
    logic ay1_bdir, ay1_bc1;
    logic ay2_bdir, ay2_bc1;
	 logic [7:0] ay1_da_out, ay2_da_out;
	 logic [7:0] ay1_audio_mono, ay2_audio_mono;
	 	 
	 assign ay1_sel = io_en && (io_addr[7:1] == 7'b0000000); 
    assign ay2_sel = io_en && (io_addr[7:1] == 7'b1000000); 
    assign port_data_sel = io_addr[0]; 
    assign ay1_bdir = ay1_sel && io_write;
    assign ay1_bc1  = ay1_sel && (io_read || (!port_data_sel && io_write));
    assign ay2_bdir = ay2_sel && io_write;
    assign ay2_bc1  = ay2_sel && (io_read || (!port_data_sel && io_write));
	 assign audio = {1'b0, ay1_audio_mono} + {1'b0, ay2_audio_mono};

    always_ff @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            audio_clk_div <= 4'd0;
            cen_audio     <= 1'b0;
        end else if (audio_clk_div == 4'd11) begin
            audio_clk_div <= 4'd0;
            cen_audio     <= 1'b1;
        end else begin
            audio_clk_div <= audio_clk_div + 4'd1;
            cen_audio     <= 1'b0;
        end
    end

    always_comb begin
        io_data_out = 8'hFF; 
        if (ay1_sel && io_read) begin
            io_data_out = ay1_da_out;
        end else if (ay2_sel && io_read) begin
            io_data_out = ay2_da_out;
        end
    end

    YM2149 ay1 (
        .CLK        ( clk_sys ),
        .ENA        ( cen_audio ),
        .RESET_L    ( ~reset ),
        .I_DA       ( io_data_in ),
        .O_DA       ( ay1_da_out ),
        .I_BDIR     ( ay1_bdir ),
        .I_BC1      ( ay1_bc1 ),
        .I_BC2      ( 1'b1 ),
        .I_A8       ( 1'b1 ),
        .I_A9_L     ( 1'b0 ),
        .I_SEL_L    ( 1'b1 ),
        .I_STEREO   ( 1'b0 ),
        .O_AUDIO    ( ay1_audio_mono ), 
        .I_IOA      ( I_BUTTONS ),
        .I_IOB      ( 8'hFF )
    );

    YM2149 ay2 (
        .CLK        ( clk_sys ),
        .ENA        ( cen_audio ),
        .RESET_L    ( ~reset ),
        .I_DA       ( io_data_in ),
        .O_DA       ( ay2_da_out ),
        .I_BDIR     ( ay2_bdir ),
        .I_BC1      ( ay2_bc1 ),
        .I_BC2      ( 1'b1 ),
        .I_A8       ( 1'b1 ),
        .I_A9_L     ( 1'b0 ),
        .I_SEL_L    ( 1'b1 ),
        .I_STEREO   ( 1'b0 ),
        .O_AUDIO    ( ay2_audio_mono ), 
        .I_IOA      ( I_JOYSTICK ),
        .I_IOB      ( 8'hFF )
    );

endmodule
