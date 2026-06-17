# FIFO Design Documentation

## Overview

This project implements two FIFO (First-In-First-Out) queue designs in Verilog:
1. **Synchronous FIFO** - Single clock domain
2. **Asynchronous FIFO** - Dual clock domain with Clock Domain Crossing (CDC)

## Synchronous FIFO (sync_fifo.v)

### Features
- Single clock domain operation
- Configurable depth (power of 2 recommended) and data width
- Empty and full flags
- Real-time FIFO count
- Simultaneous read/write support

### Architecture
- **Pointers**: Binary read and write pointers with extra MSB for empty/full detection
- **Memory**: Array-based storage
- **Control Logic**: 
  - Empty: `wr_ptr == rd_ptr`
  - Full: MSBs differ but lower bits match
  - Count: difference between write and read pointers

### Parameters
```verilog
DEPTH = 16      // Number of storage locations (power of 2 recommended)
WIDTH = 8       // Data width in bits
```

### Interface Signals
| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| clk | I | 1 | System clock |
| rst_n | I | 1 | Active-low reset |
| wr_data | I | WIDTH | Data to write |
| wr_en | I | 1 | Write enable |
| full | O | 1 | FIFO full flag |
| rd_data | O | WIDTH | Data to read |
| rd_en | I | 1 | Read enable |
| empty | O | 1 | FIFO empty flag |
| count | O | DEPTH | Current number of items |

### Timing
- Write operation: Data written on rising clock edge when `wr_en=1` and `full=0`
- Read operation: Data available combinatorially, pointer advanced on rising clock edge when `rd_en=1` and `empty=0`

---

## Asynchronous FIFO (async_fifo.v)

### Features
- Dual independent clock domains (write and read)
- Safe Clock Domain Crossing (CDC) using Gray code synchronizers
- Configurable depth and data width
- Empty and full flags (synchronized to respective clock domains)
- Handles metastability with 2-stage synchronizer FFs

### Architecture

#### Components:

1. **Gray Code Converter**
   - Converts binary pointers to Gray code
   - Advantage: Only 1 bit changes per increment, safe for CDC

2. **Gray Code Decoder**
   - Converts Gray code back to binary for comparison
   - Used to compare pointers across domains

3. **CDC Synchronizer (cdc_sync)**
   - 2-stage flip-flop chain in destination clock domain
   - Eliminates metastability after 2 clock cycles
   - Configurable number of stages (default: 2)

4. **Main FIFO Logic**
   - Separate read and write pointer logic per clock domain
   - Gray-coded pointers synchronized across domains
   - Full/empty flags based on synchronized pointers

### Parameters
```verilog
DEPTH = 16      // Number of storage locations (power of 2)
WIDTH = 8       // Data width in bits
```

### Clock Domain Separation

**Write Clock Domain:**
- wr_ptr, wr_ptr_gray: Local pointer and Gray version
- rd_ptr_gray_sync: Synchronized read pointer (from rd_clk domain)
- full: Based on synchronized rd_ptr

**Read Clock Domain:**
- rd_ptr, rd_ptr_gray: Local pointer and Gray version
- wr_ptr_gray_sync: Synchronized write pointer (from wr_clk domain)
- empty: Based on synchronized wr_ptr

### CDC Metastability Handling
- Synchronization delay: 2 clock cycles in destination domain
- Recommended setup: Allow 10+ destination clock cycles before assuming stable CDC status
- Gray code ensures maximum 1 bit change per clock, preventing multiple bit transitions

### Interface Signals

| Signal | Domain | Dir | Width | Description |
|--------|--------|-----|-------|-------------|
| wr_clk | Write | I | 1 | Write clock |
| wr_rst_n | Write | I | 1 | Write domain reset (active-low) |
| wr_data | Write | I | WIDTH | Data to write |
| wr_en | Write | I | 1 | Write enable |
| full | Write | O | 1 | FIFO full (write domain) |
| rd_clk | Read | I | 1 | Read clock |
| rd_rst_n | Read | I | 1 | Read domain reset (active-low) |
| rd_data | Read | O | WIDTH | Data to read |
| rd_en | Read | I | 1 | Read enable |
| empty | Read | O | 1 | FIFO empty (read domain) |

### Timing Considerations
- After reset, allow 2-3 read clock cycles before accessing full flag in write domain
- After reset, allow 2-3 write clock cycles before accessing empty flag in read domain
- CDC provides stable flags after synchronization delay
- Data valid immediately after read (combinatorial from memory)

---

## Implementation Notes

### Synchronous FIFO Use Cases
- Same clock domain communication
- High-speed, single-frequency systems
- Simpler control logic
- Lower latency (no CDC delay)

### Asynchronous FIFO Use Cases
- Multi-clock domain communication (e.g., USB, PCIe bridges)
- Clock domain isolation
- Power management (different clock domains)
- Safe metastability handling

### Design Best Practices
1. Always assert resets at power-up
2. For async FIFO, independently reset each clock domain
3. Monitor full/empty flags before read/write operations
4. Test with realistic clock frequency relationships
5. Verify CDC timing with simulation (minimum 500ns for validation)

---

## Simulation

### Sync FIFO Test (tb_sync_fifo.sv)
- Basic write/read operations
- FIFO fill/empty tests
- Simultaneous read/write stress test
- Edge case handling

### Async FIFO Test (tb_async_fifo.sv)
- Cross-domain write/read with different clock frequencies
- CDC synchronization verification
- Stress test with multiple simultaneous operations
- Metastability resilience validation
- Real-time monitoring for protocol violations

