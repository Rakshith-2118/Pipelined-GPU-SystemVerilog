`default_nettype none
`timescale 1ns/1ns

module pipelined_gpu_tb;
  // Clock & reset
  logic clk;
  logic reset;

  // Device Control Register interface
  logic        dcr_write_en;
  logic [7:0]  device_control_data;

  // Done signal from GPU
  wire done;

  // --- Data Memory Interface ---
  parameter DATA_ADDR_BITS = 8;
  parameter DATA_DATA_BITS = 8;
  parameter NUM_CHANNELS   = 4;

  logic [NUM_CHANNELS-1:0]              data_read_ready;
  logic [NUM_CHANNELS-1:0]              data_read_valid;
  logic [DATA_ADDR_BITS-1:0]            data_read_address [NUM_CHANNELS-1:0];
  logic [DATA_DATA_BITS-1:0]            data_read_data    [NUM_CHANNELS-1:0];

  logic [NUM_CHANNELS-1:0]              data_write_valid;
  logic [DATA_ADDR_BITS-1:0]            data_write_address[NUM_CHANNELS-1:0];
  logic [DATA_DATA_BITS-1:0]            data_write_data   [NUM_CHANNELS-1:0];
  logic [NUM_CHANNELS-1:0]              data_write_ready;

  // Simple data memory
  logic [DATA_DATA_BITS-1:0] mem_model [0:(1<<DATA_ADDR_BITS)-1];

  // Always ready
  initial begin
    data_read_ready  = {NUM_CHANNELS{1'b1}};
    data_write_ready = {NUM_CHANNELS{1'b1}};
  end

  // Read response
  genvar i;
  generate
    for (i = 0; i < NUM_CHANNELS; i++) begin : MEM_READ
      always_ff @(posedge clk) begin
        if (data_read_valid[i]) begin
          data_read_data[i] <= mem_model[data_read_address[i]];
        end
      end
    end
  endgenerate

  // Capture writes
  generate
    for (i = 0; i < NUM_CHANNELS; i++) begin : MEM_WRITE
      always_ff @(posedge clk) begin
        if (data_write_valid[i]) begin
          mem_model[data_write_address[i]] <= data_write_data[i];
          $display("[%0t] CH%0d W: A=0x%0h D=0x%0h", $time, i, data_write_address[i], data_write_data[i]);
        end
      end
    end
  endgenerate

  // Instantiate pipelined GPU
  pipelined_gpu #(
    .PROGRAM_MEM_ADDR_BITS (8),
    .PROGRAM_MEM_DATA_BITS (16),
    .DATA_MEM_ADDR_BITS (DATA_ADDR_BITS),
    .DATA_MEM_DATA_BITS (DATA_DATA_BITS),
    .DATA_MEM_NUM_CHANNELS(NUM_CHANNELS),
	 .NUM_CORES(2),
	 .THREADS_PER_BLOCK(4)
  ) dut
  (
    .clk                      (clk),
    .reset                    (reset),
    .device_control_write_en  (dcr_write_en),
    .device_control_data      (device_control_data),
    .done                     (done),
    // Data memory ports
    .data_mem_read_valid(data_read_valid),
    .data_mem_read_address(data_read_address),
    .data_mem_read_data(data_read_data),
    .data_mem_read_ready(data_read_ready),
    .data_mem_write_valid(data_write_valid),
    .data_mem_write_address(data_write_address),
    .data_mem_write_data(data_write_data),
    .data_mem_write_ready(data_write_ready)
  );

  // Clock generation (50ns period)
  initial clk = 0;
  always #25 clk = ~clk;

  // Test sequence
  initial begin
    // Initialize
    reset = 1;
    dcr_write_en = 0;
    device_control_data = 0;
    // Wait a few cycles
    repeat (4) @(posedge clk);
    reset = 0;

    // Configure thread count (example: 8 threads)
    @(posedge clk);
    dcr_write_en = 1;
    device_control_data = 8'd8;
    @(posedge clk);
    dcr_write_en = 0;

    // Wait for completion
    wait (done);
    $display("GPU done at %0t", $time);

    // Dump first 16 words of data memory
    $display("Data Mem[0..15]:");
    for (int addr = 0; addr < 16; addr++) begin
      $display("[%0d] = 0x%0h", addr, mem_model[addr]);
    end

    $finish;
  end
endmodule
