`default_nettype none
`timescale 1ns / 1ns

module pipeline_reg #(parameter REGISTER_WIDTH = 8)
(
    input wire clk, 
    input wire reset,
    input wire any_lsu_waiting,
    input wire [REGISTER_WIDTH-1:0] reg_input,
    output reg [REGISTER_WIDTH-1:0] reg_output  
);

always @(posedge clk) begin
    if (reset) begin
        reg_output <= 0;
    end
    else if (any_lsu_waiting) begin
        reg_output <= reg_output;
    end
    else begin
        reg_output <= reg_input;
    end
end
endmodule