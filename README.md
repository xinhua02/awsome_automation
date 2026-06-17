# FIFO Queue Designs - Synchronous & Asynchronous

A comprehensive hardware verification project implementing **Synchronous** and **Asynchronous FIFO (First-In-First-Out)** queue designs in Verilog with SystemVerilog testbenches.

## 🎯 Project Overview

This project provides production-ready FIFO implementations with:
- **Synchronous FIFO**: Single clock domain, optimal for same-clock scenarios
- **Asynchronous FIFO**: Dual clock domains with safe Clock Domain Crossing (CDC) using Gray code synchronization
- **Full Test Suite**: Comprehensive verification covering normal operations, edge cases, stress tests, and protocol violations
- **Documentation**: Detailed design specs, timing analysis, and implementation notes

---

## 📁 Directory Structure

```
awsome_automation/
├── src/
│   ├── sync_fifo.v         # Single clock domain FIFO
│   └── async_fifo.v        # Dual clock domain FIFO with CDC
├── sim/
│   ├── tb_sync_fifo.sv     # Synchronous FIFO testbench
│   ├── tb_async_fifo.sv    # Asynchronous FIFO testbench
│   ├── run_sync_fifo.do    # QuestaSim script (sync)
│   └── run_async_fifo.do   # QuestaSim script (async)
├── doc/
│   └── FIFO_DESIGN.md      # Detailed technical documentation
├── IMPLEMENTATION_SUMMARY.md
├── TEST_VERIFICATION_REPORT.md
└── README.md               # This file
```

---

## ⚙️ Features

### Synchronous FIFO (`src/sync_fifo.v`)
- **Single Clock Domain**: Simplified for same-clock operations
- **Configurable**: Adjustable depth (power of 2) and data width
- **Full/Empty Detection**: Real-time status flags
- **Concurrent Operations**: Simultaneous read/write in one cycle
- **Pointer Implementation**: Binary pointers with MSB-based full detection
  - Empty: `write_ptr == read_ptr`
  - Full: MSB differs, lower bits match

| Feature | Value |
|---------|-------|
| Pointer Width | ADDR_WIDTH + 1 |
| Read Latency | 0 cycles (combinatorial) |
| Write Latency | 1 cycle |
| Throughput | 1 read + 1 write per cycle |

### Asynchronous FIFO (`src/async_fifo.v`)
- **Dual Clock Domains**: Independent write and read clocks
- **CDC Safe**: Gray code pointers with 2-stage flip-flop synchronizers
- **Metastability Free**: Meets worst-case timing requirements
- **Per-Domain Flags**: Full/empty signals in each clock domain

| Feature | Value |
|---------|-------|
| Encoding | Gray code (1-bit change per cycle) |
| Sync Depth | 2-stage flip-flop chain |
| CDC Latency | ~2-3 destination clocks |
| Independent Clocks | ✓ Yes (async operation) |
| Reset | Per-domain support |

**CDC Architecture:**
```
Write Domain              Read Domain
   wr_ptr                    rd_ptr
     ↓ (Gray)                  ↓ (Gray)
  wr_ptr_gray            rd_ptr_gray
     ↓ (CDC Sync)            ↓ (CDC Sync)
  [2 D-FFs] ────────→    [2 D-FFs]
     ↓ (Decode)              ↓ (Decode)
  rd_ptr_sync            wr_ptr_sync
     ↓                        ↓
  full_flag              empty_flag
```

---

## 🚀 Quick Start

### Prerequisites
- QuestaSim 2021.1+ (or ModelSim/Vivado simulator)
- Verilog/SystemVerilog knowledge
- Windows or Linux environment

### Setup & Simulation

1. **Compile and run synchronous FIFO tests:**
   ```bash
   cd sim
   vlib work
   vlog ../src/sync_fifo.v tb_sync_fifo.sv
   vsim -c -do "run; quit" tb_sync_fifo
   ```

2. **Compile and run asynchronous FIFO tests:**
   ```bash
   vlog ../src/async_fifo.v tb_async_fifo.sv
   vsim -c -do "run; quit" tb_async_fifo
   ```

3. **Interactive waveform viewing:**
   ```bash
   vsim tb_sync_fifo
   # Use GUI to add signals and run simulation
   ```

4. **View waveforms:**
   ```bash
   vsim -view results.wdb
   ```

---

## 🧪 Test Coverage

### Synchronous FIFO Tests
- ✅ Single element write/read operations
- ✅ Fill to capacity and drain
- ✅ Concurrent read/write stress (256 operations)
- ✅ Pointer wraparound at boundary
- ✅ Empty/full flag assertions
- ✅ Protocol violations (read from empty, write to full)

### Asynchronous FIFO Tests
- ✅ Cross-domain communication (100 MHz write, 150 MHz read)
- ✅ Gray code pointer synchronization
- ✅ CDC settling time verification
- ✅ Concurrent stress tests (512 operations)
- ✅ Metastability resilience
- ✅ Data integrity across clock domains
- ✅ Independent reset per domain

---

## 📊 Design Specifications

### Synchronous FIFO Parameters
```verilog
parameter ADDR_WIDTH = 4,      // Log2 of depth (default: depth = 16)
parameter DATA_WIDTH = 8,      // Data width in bits
parameter DEPTH = 1 << ADDR_WIDTH
```

### Asynchronous FIFO Parameters
```verilog
parameter ADDR_WIDTH = 4,
parameter DATA_WIDTH = 8,
parameter CDC_STAGES = 2       // Synchronizer stages
```

### Interface Signals

**Synchronous FIFO:**
```verilog
input  clk                     // Clock
input  rst_n                   // Active-low reset
input  wr_en                   // Write enable
input  rd_en                   // Read enable
input  [DATA_WIDTH-1:0] wr_data
output [DATA_WIDTH-1:0] rd_data
output full                    // FIFO full flag
output empty                   // FIFO empty flag
output [ADDR_WIDTH:0] count    // Number of elements
```

**Asynchronous FIFO:**
```verilog
// Write clock domain
input  wr_clk, wr_rst_n
input  wr_en
input  [DATA_WIDTH-1:0] wr_data
output wr_full
output [ADDR_WIDTH:0] wr_count

// Read clock domain
input  rd_clk, rd_rst_n
input  rd_en
output [DATA_WIDTH-1:0] rd_data
output rd_empty
output [ADDR_WIDTH:0] rd_count
```

---

## 🔍 Key Implementation Details

### Gray Code for CDC Safety
Gray code ensures only **one bit changes per cycle**, making it safe for synchronization:
- **Binary to Gray**: `gray = binary ^ (binary >> 1)`
- **Gray to Binary**: Iterative XOR from MSB downward
- **CDC Application**: Pointers encoded in Gray before crossing clock domains

### Metastability Elimination
- 2-stage flip-flop synchronizer chains in both clock domains
- Meets setup/hold timing requirements
- Typical resolution: 2 destination clock cycles
- Covers worst-case metastability scenarios

### Full Detection Strategy
- **Sync FIFO**: Direct pointer comparison in same clock domain
- **Async FIFO**: Synchronized pointers compared in each domain
  - Full when: `wr_ptr_gray[MSB] != rd_ptr_sync[MSB]` AND lower bits match

---

## 📈 Performance Characteristics

| Metric | Sync FIFO | Async FIFO |
|--------|-----------|-----------|
| Area Overhead | Low | Medium (Gray converters, CDC) |
| Power | Clock activity dependent | Similar + CDC activity |
| Speed | Clock-limited | CDC overhead (~3-5 clocks) |
| Clock Domains | 1 | 2 (independent) |
| Typical Throughput | 1 read + 1 write/cycle | Domain-dependent |

---

## 📚 Documentation

- **`IMPLEMENTATION_SUMMARY.md`** - Overview of all modules and test cases
- **`TEST_VERIFICATION_REPORT.md`** - Detailed test results and coverage
- **`doc/FIFO_DESIGN.md`** - Technical specifications and timing

---

## 🛠️ Development & Testing

### Build & Test Commands
```bash
# Setup work library
vlib work
vmap work ./work

# Compile all sources
vlog src/*.v sim/*.v

# Run synchronous FIFO simulation
vsim -c -do "run; quit" tb_sync_fifo

# Run asynchronous FIFO simulation
vsim -c -do "run; quit" tb_async_fifo

# Interactive GUI
vsim tb_sync_fifo
```

### Using QuestaSim Scripts
```bash
vsim -do sim/run_sync_fifo.do
vsim -do sim/run_async_fifo.do
```

---

## ✅ Implementation Status

- ✅ **Synchronous FIFO** - Complete & tested
- ✅ **Asynchronous FIFO with CDC** - Complete & tested
- ✅ **Full Test Suite** - All test cases passing
- ✅ **Documentation** - Comprehensive specs included

---

## 📝 License & Attribution

This project is maintained as an educational and reference implementation for FIFO design patterns and Clock Domain Crossing verification.

---

## 🤝 Contributing

For improvements or issues:
1. Review existing documentation
2. Check `TEST_VERIFICATION_REPORT.md` for current coverage
3. Add test cases for new scenarios
4. Update documentation with design rationale

---

**Last Updated**: 2026-06-17  
**Simulator**: QuestaSim 2021.1+  
**Status**: Ready for production use
