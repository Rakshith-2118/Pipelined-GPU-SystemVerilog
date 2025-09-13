`default_nettype none
`timescale 1ns/1ns

// GPU
// > Built to use an external async memory with multi-channel read/write
// > Assumes that the program is loaded into program memory, data into data memory, and threads into
//   the device control register before the start signal is triggered
// > Has memory controllers to interface between external memory and its multiple cores
// > Configurable number of cores and thread capacity per core
module pipelined_gpu #(
    parameter DATA_MEM_ADDR_BITS = 8,        // Number of bits in data memory address (256 rows)
    parameter DATA_MEM_DATA_BITS = 8,        // Number of bits in data memory value (8 bit data)
    parameter DATA_MEM_NUM_CHANNELS = 4,     // Number of concurrent channels for sending requests to data memory
    parameter PROGRAM_MEM_ADDR_BITS = 8,     // Number of bits in program memory address (256 rows)
    parameter PROGRAM_MEM_DATA_BITS = 16,    // Number of bits in program memory value (16 bit instruction)
    parameter NUM_CORES = 2,                 // Number of cores to include in this GPU
    parameter THREADS_PER_BLOCK = 4          // Number of threads to handle per block (determines the compute resources of each core)
) 
(
    input wire clk,
    input wire reset,

    // Kernel Execution
    output wire done,

    // Device Control Register
    input wire device_control_write_enable,
    input wire [7:0] device_control_data,

    // Data Memory
    output wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid,
    output wire [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0],
    input wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready,
    input wire [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0],
    output wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid,
    output wire [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0],
    output wire [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0],
    input wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready
);
    // Control
    wire [7:0] thread_count;
	 wire [PROGRAM_MEM_DATA_BITS-1:0] instruction [NUM_CORES-1:0];
	 wire [PROGRAM_MEM_ADDR_BITS-1:0] instruction_addr [NUM_CORES-1:0];

    // Compute Core State
    reg [NUM_CORES-1:0] core_reset;
    reg [NUM_CORES-1:0] core_done;
    reg [7:0] core_block_id [NUM_CORES-1:0];
    reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0];

    // LSU <> Data Memory Controller Channels
    localparam NUM_LSUS = NUM_CORES * THREADS_PER_BLOCK;
    reg [NUM_LSUS-1:0] lsu_read_valid;
    reg [DATA_MEM_ADDR_BITS-1:0] lsu_read_address [NUM_LSUS-1:0];
    reg [NUM_LSUS-1:0] lsu_read_ready;
    reg [DATA_MEM_DATA_BITS-1:0] lsu_read_data [NUM_LSUS-1:0];
    reg [NUM_LSUS-1:0] lsu_write_valid;
    reg [DATA_MEM_ADDR_BITS-1:0] lsu_write_address [NUM_LSUS-1:0];
    reg [DATA_MEM_DATA_BITS-1:0] lsu_write_data [NUM_LSUS-1:0];
    reg [NUM_LSUS-1:0] lsu_write_ready;
    
    // Device Control Register
    dcr dcr_instance (
        .clk(clk),
        .reset(reset),

        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .thread_count(thread_count)
    );

    // Data Memory Controller
    controller #(
        .ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_BITS(DATA_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_LSUS),
        .NUM_CHANNELS(DATA_MEM_NUM_CHANNELS)
    ) data_memory_controller (
        .clk(clk),
        .reset(reset),

        .consumer_read_valid(lsu_read_valid),
        .consumer_read_address(lsu_read_address),
        .consumer_read_ready(lsu_read_ready),
        .consumer_read_data(lsu_read_data),
        .consumer_write_valid(lsu_write_valid),
        .consumer_write_address(lsu_write_address),
        .consumer_write_data(lsu_write_data),
        .consumer_write_ready(lsu_write_ready),

        .mem_read_valid(data_mem_read_valid),
        .mem_read_address(data_mem_read_address),
        .mem_read_ready(data_mem_read_ready),
        .mem_read_data(data_mem_read_data),
        .mem_write_valid(data_mem_write_valid),
        .mem_write_address(data_mem_write_address),
        .mem_write_data(data_mem_write_data),
        .mem_write_ready(data_mem_write_ready)
    );

    // Dispatcher
    dispatch #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dispatch_instance (
        .clk(clk),
        .reset(reset),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .done(done)
    );

    // Compute Cores
    genvar j;
    generate
        for (j = 0; j < NUM_CORES; j = j + 1) begin : cores
            // EDA: We create separate signals here to pass to cores because of a requirement
            // by the OpenLane EDA flow (uses Verilog 2005) that prevents slicing the top-level signals
            reg core_lsu_read_valid [THREADS_PER_BLOCK-1:0] ;
            reg [DATA_MEM_ADDR_BITS-1:0] core_lsu_read_address [THREADS_PER_BLOCK-1:0];
            reg core_lsu_read_ready [THREADS_PER_BLOCK-1:0] ;
            reg [DATA_MEM_DATA_BITS-1:0] core_lsu_read_data [THREADS_PER_BLOCK-1:0];
            reg core_lsu_write_valid [THREADS_PER_BLOCK-1:0];
            reg [DATA_MEM_ADDR_BITS-1:0] core_lsu_write_address [THREADS_PER_BLOCK-1:0];
            reg [DATA_MEM_DATA_BITS-1:0] core_lsu_write_data [THREADS_PER_BLOCK-1:0];
            reg core_lsu_write_ready [THREADS_PER_BLOCK-1:0];

            // Pass through signals between LSUs and data memory controller
            genvar k;
            for (k = 0; k < THREADS_PER_BLOCK; k = k + 1) begin : lsu_control
                localparam lsu_index = j * THREADS_PER_BLOCK + k;
                always @(posedge clk) begin 
                    lsu_read_valid[lsu_index] <= core_lsu_read_valid[k];
                    lsu_read_address[lsu_index] <= core_lsu_read_address[k];

                    lsu_write_valid[lsu_index] <= core_lsu_write_valid[k];
                    lsu_write_address[lsu_index] <= core_lsu_write_address[k];
                    lsu_write_data[lsu_index] <= core_lsu_write_data[k];
                    
                    core_lsu_read_ready[k] <= lsu_read_ready[lsu_index];
                    core_lsu_read_data[k] <= lsu_read_data[lsu_index];
                    core_lsu_write_ready[k] <= lsu_write_ready[lsu_index];
                end
            end

            // Compute Core
            pipelined_core #(
                .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
                .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
                .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
                .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) core_instance (
                .clk(clk),
                .reset(core_reset[j]),
                .done(core_done[j]),
                .block_id(core_block_id[j]),
                .thread_count(core_thread_count[j]),
                
                .mem_instruction(instruction[j]),
					 .pmem_address(instruction_addr[j]),

                .mem_read_valid(core_lsu_read_valid),
                .mem_read_address(core_lsu_read_address),
                .mem_read_ready(core_lsu_read_ready),
                .mem_read_data(core_lsu_read_data),
                .mem_write_valid(core_lsu_write_valid),
                .mem_write_address(core_lsu_write_address),
                .mem_write_data(core_lsu_write_data),
                .mem_write_ready(core_lsu_write_ready)
            );
        end
    endgenerate
	 
	 // Program Memory
	 program_mem #
	 (
		  .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
		  .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS)
	 ) program_mem_inst
	 (
		  .pmem1(instruction_addr[0]),
		  .pmem2(instruction_addr[1]),
		  .pmem1_data(instruction[0]),
		  .pmem2_data(instruction[1])
	 );
	 
endmodule