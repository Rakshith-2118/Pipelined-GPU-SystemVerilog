`default_nettype none
`timescale 1ns/1ns

module nab
(input wire nzp_en, input wire reset, input wire clk, input wire [7:0] rs_d, input wire [7:0] rt_d, 
input wire [7:0] pr1_pc, output reg [2:0] nzp_val, output wire [7:0] nab_out1,
input wire [7:0] imm_8bit, output wire [7:0] nab_out2);

always @(posedge clk)
begin
    if (reset == 1) begin
        nzp_val <= 3'b000;
    end
    else begin
        if(nzp_en) begin
            nzp_val <= {(rs_d < rt_d),(rs_d == rt_d),(rs_d > rt_d)};
        end
        else    
        begin
            nzp_val <= nzp_val;
        end
    end
end
    assign nab_out1 = pr1_pc + 8'b00000001;
    assign nab_out2 = imm_8bit;

endmodule