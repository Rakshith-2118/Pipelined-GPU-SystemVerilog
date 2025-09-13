`default_nettype none
`timescale 1ns/1ns

// ARITHMETIC-LOGIC UNIT
// > Executes computations on register values
// > In this minimal implementation, the ALU supports the 4 basic arithmetic operations
// > Each thread in each core has it's own ALU
// > ADD, SUB, MUL, DIV instructions are all executed here

module alu (
    input wire reset,
    input wire enable,
    input wire [1:0] decoded_alu_arithmetic_mux,
    input wire [7:0] rs,
    input wire [7:0] rt,
    output reg [7:0] alu_out
);
    localparam ADD = 2'b00,
               SUB = 2'b01,
               MUL = 2'b10,
               DIV = 2'b11;

    always @(*) begin
        if (reset) begin
            alu_out = 8'b0;
        end else if (enable) begin
            case (decoded_alu_arithmetic_mux)
                ADD: alu_out = rs + rt;
                SUB: alu_out = rs - rt;
                MUL: alu_out = rs * rt;
                DIV: alu_out = (rt == 0) ? 8'b0 : rs / rt; // Division by zero protection
                default: alu_out = 8'b0;
            endcase
        end else begin
            alu_out = 8'b0;
        end
    end
endmodule
