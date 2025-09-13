`default_nettype none
`timescale 1ns/1ns

// BLOCK DISPATCH
// > The GPU has one dispatch unit at the top level
// > Manages processing of threads and marks kernel execution as done
// > Sends off batches of threads in blocks to be executed by available compute cores
module dispatch #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
)
(
    input wire clk,
    input wire reset,

    // Kernel Metadata
    input wire [7:0] thread_count,

    // Core States
    input wire [NUM_CORES-1:0] core_done,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [7:0] core_block_id [NUM_CORES-1:0],
    output reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Kernel Execution
    output reg done
);
    // Calculate the total number of blocks based on total threads & threads per block
	 wire [31:0] temp_total = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
	 wire [7:0] total_blocks = temp_total[7:0];
    // Keep track of how many blocks have been processed
    reg [7:0] blocks_dispatched; // How many blocks have been sent to cores?
    reg [7:0] blocks_done; // How many blocks have finished processing?

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched = 0;
            blocks_done = 0;

            for (int i = 0; i < NUM_CORES; i++) begin
                core_reset[i] <= 1;
                core_block_id[i] <= 0;
                core_thread_count[i] <= THREADS_PER_BLOCK[2:0];
            end
        end
        else begin

            // If the last block has finished processing, mark this kernel as done executing
            if (blocks_done == total_blocks) begin 
                done <= 1;
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_reset[i]) begin 
                    core_reset[i] <= 0;

                    // If this core was just reset, check if there are more blocks to be dispatched
                    if (blocks_dispatched < total_blocks) begin 
								logic [31:0] threads_remaining;
								threads_remaining = thread_count - (blocks_dispatched * THREADS_PER_BLOCK);
								
                        core_block_id[i] <= blocks_dispatched;
                        core_thread_count[i] <= (blocks_dispatched == total_blocks - 1) 
                            ? threads_remaining[2:0]
                            : THREADS_PER_BLOCK[2:0];

                        blocks_dispatched = blocks_dispatched + 8'b1;
                    end
                end
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_done[i]) begin
                    // If a core just finished executing it's current block, reset it
                    core_reset[i] <= 1;
                    blocks_done = blocks_done + 8'b1;
                end
            end
        end
    end
endmodule