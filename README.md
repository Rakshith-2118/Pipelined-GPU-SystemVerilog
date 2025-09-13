# Pipelined GPU in SystemVerilog

This project is a complete, from-scratch design and implementation of a **4-stage, dual-core pipelined Graphics Processing Unit (GPU)** in SystemVerilog. It is based on a custom **Single Instruction, Multiple Thread (SIMT)** architecture designed for high-throughput parallel computation.

---

## 🚀 Key Features

* **4-Stage Pipelined Architecture**: Implements Fetch, Decode, Execute/Memory, and Write-Back stages to maximize instruction throughput.
* **Dual-Core SIMT Design**: Two parallel processing cores, each managing a block of threads with dedicated ALUs, LSUs, and Register Files.
* **Efficient Memory System**: Independent program memory channels per core to eliminate instruction fetch bottlenecks.
* **Hazard Management**: Load-store unit (LSU) based stalling mechanism ensures correct execution in the presence of memory hazards.

---

## 🏗️ Architecture Overview

* **Top-Level (pipelined\_gpu)**: Instantiates and connects all major components.
* **Dispatcher**: Assigns blocks of threads to the two cores.
* **Cores**: Each core executes instructions from its dedicated program memory through the 4-stage pipeline.
* **Data Memory Controller**: Multi-channel controller arbitrates access to the main data memory.
* **Load-Store Units (LSUs)**: Handle memory operations and stall the pipeline when required.
* **Pipeline Registers**: Implemented via `pipeline_reg.sv` to store intermediate state between stages.

---

## 📝 Instruction Set Architecture (ISA)

The GPU implements a **custom RISC-style ISA**:

| Mnemonic               | Description                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------- |
| **ADD, SUB, MUL, DIV** | Perform arithmetic operations on two source registers, store result in destination register |
| **LDR**                | Load data from memory at address in register into another register                          |
| **STR**                | Store data from a register into memory at address in another register                       |
| **CONST**              | Load 8-bit immediate value into destination register                                        |
| **CMP**                | Compare two source registers and set NZP (Negative, Zero, Positive) flags                   |
| **BRnzp**              | Conditional branch based on NZP flags                                                       |
| **RET**                | Halt execution of a thread                                                                  |

---

## 🧪 Verification

The provided testbench runs a sample program to:

* Validate correct pipeline execution.
* Check hazard handling.
* Verify memory and branching operations.

---

## 📜 License

This project is released under the **MIT License**. Feel free to use and modify for educational or research purposes.
