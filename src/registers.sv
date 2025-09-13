`default_nettype none
`timescale 1ns/1ns

// REGISTER FILE
// > Each thread within each core has it's own register file with 13 free registers and 3 read-only registers
// > Read-only registers hold the familiar %blockIdx, %blockDim, and %threadIdx values critical to SIMD
module registers #(
    parameter THREADS_PER_BLOCK = 4,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire enable, // If current block has less threads then block size, some registers will be inactive

    // Kernel Execution
    input wire [DATA_BITS-1:0] block_id,

    // Instruction Signals
    input wire [3:0] decoded_rd_address,
    input wire [3:0] decoded_rs_address,
    input wire [3:0] decoded_rt_address,

    // Control Signals
    input wire decoded_reg_write_enable,
    input wire [DATA_BITS-1:0] reg_write_data,
	 
    // Registers
    output wire [DATA_BITS-1:0] rs,
    output wire [DATA_BITS-1:0] rt
);

    // 16 registers per thread (13 free registers and 3 read-only registers)
    reg [DATA_BITS-1:0] register_file[15:0];
	 
	 assign rs = register_file[decoded_rs_address];
    assign rt = register_file[decoded_rt_address];
	 
	 always @(posedge clk) begin
        if (reset) begin
            // Initialize all registers
            for (integer i = 0; i < 16; i = i + 1) begin
                register_file[i] <= '0;
            end
            
            // Set read-only registers
            register_file[14] <= THREADS_PER_BLOCK[7:0];  // %blockDim
            register_file[15] <= THREAD_ID[7:0];          // %threadIdx
        end
        else if (enable) begin
            // Update block_id (read-only register 13)
            register_file[13] <= block_id;
            
            // Register write operation
            if (decoded_reg_write_enable && (decoded_rd_address < 13)) begin
                register_file[decoded_rd_address] <= reg_write_data;
            end
        end
    end
endmodule
