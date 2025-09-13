`default_nettype none
`timescale 1ns/1ns

// INSTRUCTION FETCHER
// > Retrieves the instruction at the current PC from global data memory
// > Each core has it's own fetcher
module fetcher #(
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 16
) ( 
	 input wire reset,
    // Execution State
    input wire[7:0] current_pc,

    // Program Memory
    output wire [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address,
    input wire[PROGRAM_MEM_DATA_BITS-1:0] mem_read_data,

    // Fetcher Output
    output wire [PROGRAM_MEM_DATA_BITS-1:0] instruction
);

	assign mem_read_address = reset ? 8'b0 : current_pc;
   assign instruction = reset ? 16'b0 : mem_read_data;
endmodule
