# Pipelined-GPU-SystemVerilog
This project is a complete, from-scratch design and implementation of a 4-stage, dual-core pipelined Graphics Processing Unit (GPU) in SystemVerilog. It is built on a custom Single Instruction, Multiple Thread (SIMT) architecture designed for high-throughput parallel computation.

# Key Features
-> 4-Stage Pipelined Architecture: Implements Fetch, Decode, Execute/Memory, and Write-Back stages to maximize instruction throughput.
-> Dual-Core SIMT Design: Features two parallel processing cores, each capable of managing a block of threads with dedicated ALUs, LSUs, and Register Files.
-> Efficient Memory System: Designed with independent program memory channels per core to eliminate instruction fetch bottlenecks.
-> Hazard Management: Incorporates a load-store unit (LSU) based stalling mechanism to handle data hazards from memory operations, ensuring data integrity.

