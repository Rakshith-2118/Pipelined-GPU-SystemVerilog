`timescale 1ns / 1ns
`default_nettype none 

module program_mem #
(
	 parameter PROGRAM_MEM_DATA_BITS = 16,
    parameter PROGRAM_MEM_ADDR_BITS = 8
)
(
    input wire [PROGRAM_MEM_ADDR_BITS-1:0] pmem1,
    input wire [PROGRAM_MEM_ADDR_BITS-1:0] pmem2,
    output reg [PROGRAM_MEM_DATA_BITS-1:0] pmem1_data,
    output reg [PROGRAM_MEM_DATA_BITS-1:0] pmem2_data
);

    reg [PROGRAM_MEM_DATA_BITS-1:0] pmem_data [(2**(PROGRAM_MEM_ADDR_BITS)-1):0];
    
    initial begin
		  $readmemh("program.mem", pmem_data);
	 end
    always@(*)
    begin
        pmem1_data <= pmem_data[pmem1];
        pmem2_data <= pmem_data[pmem2];
    end 
endmodule
