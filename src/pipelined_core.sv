`default_nettype none
`timescale 1ns/1ns

module pipelined_core #
(
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 16,
    parameter THREADS_PER_BLOCK = 4
)
(
	// Setup
	input wire clk,
	input wire reset,
	input wire [$clog2(THREADS_PER_BLOCK):0] thread_count,
	input wire [7:0] block_id,
	output wire done,
	
	// Instructions
	input wire [PROGRAM_MEM_DATA_BITS-1:0] mem_instruction,
	output wire [PROGRAM_MEM_ADDR_BITS-1:0] pmem_address,
	
	//Data Memory Controller
	output reg mem_read_valid [THREADS_PER_BLOCK-1:0],
   output reg [7:0] mem_read_address [THREADS_PER_BLOCK-1:0],
   input wire mem_read_ready [THREADS_PER_BLOCK-1:0],
   input wire [7:0] mem_read_data [THREADS_PER_BLOCK-1:0],
   output reg mem_write_valid [THREADS_PER_BLOCK-1:0],
   output reg [7:0] mem_write_address [THREADS_PER_BLOCK-1:0],
   output reg [7:0] mem_write_data [THREADS_PER_BLOCK-1:0],
   input wire mem_write_ready [THREADS_PER_BLOCK-1:0]
	
);
	//Fetcher related
	reg [PROGRAM_MEM_ADDR_BITS-1:0] current_pc;
	wire [PROGRAM_MEM_ADDR_BITS-1:0] next_pc;
	wire [PROGRAM_MEM_DATA_BITS-1:0] fetched_instruction;
	wire [PROGRAM_MEM_DATA_BITS-1:0] stored_instruction;
	
	// Decoder and NAB
	reg [PROGRAM_MEM_DATA_BITS-1:0] stg2_instruction;
	reg [PROGRAM_MEM_ADDR_BITS-1:0] stg2_pc;
	wire decoded_reg_write_enable;
	wire decoded_mem_read_enable;
	wire decoded_mem_write_enable;
	wire decoded_nzp_enable;
	wire [1:0] decoded_reg_input_mux;
	wire [1:0] decoded_alu_select;
	wire decoded_next_address;
	wire decoded_ret;
	
	wire stg3_reg_write_enable [THREADS_PER_BLOCK-1:0];
	wire stg4_reg_write_enable [THREADS_PER_BLOCK-1:0];
	wire stg3_mem_read_enable [THREADS_PER_BLOCK-1:0];
	wire stg3_mem_write_enable [THREADS_PER_BLOCK-1:0];
	wire stg3_nzp_enable;
	wire [1:0] stg3_reg_input_mux [THREADS_PER_BLOCK-1:0];
	wire [1:0] stg3_alu_select [THREADS_PER_BLOCK-1:0];
	
	wire [7:0] decoded_immediate;
	wire [3:0] decoded_rs_address;
	wire [3:0] decoded_rt_address;
	wire [3:0] decoded_rd_address;
	wire [2:0] decoded_nzp_instr;
	reg [2:0] nzp_stored;
	
	wire [7:0] stg3_immediate [THREADS_PER_BLOCK-1:0];
	wire [3:0] stg3_rd_address [THREADS_PER_BLOCK-1:0];
	
	wire [PROGRAM_MEM_ADDR_BITS-1:0] incr_pc;
	wire [PROGRAM_MEM_ADDR_BITS-1:0] branch_pc;
	
	//LSU related
	wire any_lsu_waiting;
	wire [7:0] lsu_out_array [THREADS_PER_BLOCK-1:0];
	wire [THREADS_PER_BLOCK-1:0] lsu_waiting;
	
	//RF related
	wire [7:0] stg3_output [THREADS_PER_BLOCK-1:0];
	wire [3:0] stg4_rd_address [THREADS_PER_BLOCK-1:0];
	wire [7:0] reg_input_data [THREADS_PER_BLOCK-1:0];
	wire [7:0] rs_array [THREADS_PER_BLOCK-1:0];
	wire [7:0] rt_array [THREADS_PER_BLOCK-1:0];

	//ALU related
	wire [7:0] alu_in_1 [THREADS_PER_BLOCK-1:0];
	wire [7:0] alu_in_2 [THREADS_PER_BLOCK-1:0];
	wire [7:0] alu_out_array [THREADS_PER_BLOCK-1:0];
	
	fetcher #
	(
		.PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
		.PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS)
	) fetcher_inst
	(
		.reset(reset),
		.current_pc(current_pc),
		.mem_read_data(mem_instruction),
		.instruction(fetched_instruction),
		.mem_read_address(pmem_address)
	);
	
	pipeline_reg #
	(
		.REGISTER_WIDTH(PROGRAM_MEM_ADDR_BITS + PROGRAM_MEM_DATA_BITS)
	) pr_1
	(
		.clk(clk),
		.reset(reset),
		.any_lsu_waiting(any_lsu_waiting),
		.reg_input({current_pc, stored_instruction}),
      .reg_output({stg2_pc, stg2_instruction})
	);
	
	nab nab_inst
	(
		.nzp_en(decoded_nzp_enable),
		.reset(reset),
		.clk(clk),
		.rs_d(rs_array[0]),
		.rt_d(rt_array[0]),
		.pr1_pc(stg2_pc),
		.nzp_val(nzp_stored),
		.nab_out1(incr_pc),
		.imm_8bit(decoded_immediate),
		.nab_out2(branch_pc)
	);
	
	decoder decoder_inst
	(
		.reset(reset),
		.instruction(stg2_instruction),
		.nzp_stored(nzp_stored),
		.decoded_reg_write_enable(decoded_reg_write_enable),
		.decoded_mem_read_enable(decoded_mem_read_enable),
		.decoded_mem_write_enable(decoded_mem_write_enable),
		.decoded_nzp_write_enable(decoded_nzp_enable),
		.decoded_reg_input_mux(decoded_reg_input_mux),
		.decoded_alu_arithmetic_mux(decoded_alu_select),
		.decoded_next_address(decoded_next_address),
		.decoded_ret(decoded_ret)
	);
	
	
	genvar j;
	generate
		for (j = 0; j < THREADS_PER_BLOCK; j = j + 1) begin : threads
			registers #
			(
				 .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
				 .THREAD_ID(j),
				 .DATA_BITS(DATA_MEM_DATA_BITS)
         ) register_inst
			(
				 .clk(clk),
				 .reset(reset),
				 .enable(j < thread_count),
				 .block_id(block_id),
				 .decoded_reg_write_enable(stg4_reg_write_enable[j]),
				 .decoded_rd_address(stg4_rd_address[j]),
				 .decoded_rs_address(decoded_rs_address),
				 .decoded_rt_address(decoded_rt_address),
				 .reg_write_data(reg_input_data[j]),
				 .rs(rs_array[j]),
				 .rt(rt_array[j])
         );
			
			pipeline_reg #
			(
				.REGISTER_WIDTH(35)
			) pr_2
			(
				.clk(clk),
				.reset(reset),
				.any_lsu_waiting(any_lsu_waiting),
				.reg_input({
                    decoded_immediate, 
                    rs_array[j], 
                    rt_array[j], 
                    decoded_reg_input_mux, 
                    decoded_alu_select, 
                    decoded_reg_write_enable, 
                    decoded_mem_read_enable, 
                    decoded_mem_write_enable, 
                    decoded_rd_address
                }),
                .reg_output({
                    stg3_immediate[j], 
                    alu_in_1[j], 
                    alu_in_2[j], 
                    stg3_reg_input_mux[j], 
                    stg3_alu_select[j], 
                    stg3_reg_write_enable[j], 
                    stg3_mem_read_enable[j], 
                    stg3_mem_write_enable[j], 
                    stg3_rd_address[j]
                })
			);
		
			alu alu_inst
			(
				.reset(reset),
				.enable(j < thread_count),
				.decoded_alu_arithmetic_mux(stg3_alu_select[j]),
				.rs(alu_in_1[j]),
				.rt(alu_in_2[j]),
				.alu_out(alu_out_array[j])
			);
			
			lsu lsu_inst
			(
				.clk(clk),
				.reset(reset),
				.enable(j < thread_count),
				.decoded_mem_read_enable(stg3_mem_read_enable[j]),
				.decoded_mem_write_enable(stg3_mem_write_enable[j]),
				.rs(alu_in_1[j]),
				.rt(alu_in_2[j]),
				.mem_read_valid(mem_read_valid[j]),
				.mem_read_address(mem_read_address[j]),
				.mem_read_ready(mem_read_ready[j]),
				.mem_read_data(mem_read_data[j]),
				.mem_write_valid(mem_write_valid[j]),
				.mem_write_address(mem_write_address[j]),
				.mem_write_data(mem_write_data[j]),
				.mem_write_ready(mem_write_ready[j]),
				.lsu_out(lsu_out_array[j]),
				.lsu_waiting(lsu_waiting[j])
			);
			
			assign stg3_output[j] = 
				 (stg3_reg_input_mux[j] == 2'b00) ? alu_out_array[j] :
				 (stg3_reg_input_mux[j] == 2'b01) ? lsu_out_array[j] :
				 stg3_immediate[j];
			
			pipeline_reg #
			(
				.REGISTER_WIDTH(13)
			) pr_3
			(
				.clk(clk),
				.reset(reset),
				.any_lsu_waiting(any_lsu_waiting),
				.reg_input({
					  stg3_output[j], 
					  stg3_rd_address[j], 
					  stg3_reg_write_enable[j]
				 }),
				 .reg_output({
					  reg_input_data[j], 
					  stg4_rd_address[j], 
					  stg4_reg_write_enable[j]
				 })
			);
		end
	endgenerate
	
	assign stored_instruction = decoded_next_address ? 16'b0 : fetched_instruction;
	assign next_pc = decoded_next_address ? branch_pc : incr_pc;
	assign any_lsu_waiting = |lsu_waiting;
	
	always @(posedge clk) begin
		if (reset) begin
			current_pc <= 0;
		end 
		else if (decoded_ret) begin
			current_pc <= current_pc;
			done <= 1;
		end
		else begin
			current_pc <= next_pc;
		end
	end	
endmodule