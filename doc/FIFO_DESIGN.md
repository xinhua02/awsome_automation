# FIFO Design Documentation

## Overview

This project includes two FIFO designs:

1. Synchronous FIFO: single clock domain
2. Asynchronous FIFO: dual clock domain with CDC support

## Synchronous FIFO (`src/sync_fifo.sv`)

### Synchronous Features

- Single clock domain operation
- Parameterized depth and width
- `empty` and `full` status flags
- Real-time `count` output
- Concurrent read/write support

### Architecture

- Pointers: binary read/write pointers with extra MSB for full/empty disambiguation
- Storage: memory array
- Control logic:
  - Empty condition: `wr_ptr == rd_ptr`
  - Full condition: pointer lower bits equal and MSBs differ
  - Count: `wr_ptr - rd_ptr`

### Synchronous Parameters

```verilog
parameter DEPTH = 16;
parameter WIDTH = 8;
```

### Synchronous Interface Signals

| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | I | 1 | System clock |
| rst_n | I | 1 | Active-low reset |
| wr_data | I | WIDTH | Data input |
| wr_en | I | 1 | Write enable |
| full | O | 1 | FIFO full flag |
| rd_data | O | WIDTH | Data output |
| rd_en | I | 1 | Read enable |
| empty | O | 1 | FIFO empty flag |
| count | O | `$clog2(DEPTH)+1` | Number of stored entries |

### Timing

- Write: on rising edge when `wr_en && !full`
- Read pointer advance: on rising edge when `rd_en && !empty`
- Read data path: combinational from current read address

## Asynchronous FIFO (`src/async_fifo.sv`)

### Asynchronous Features

- Independent write/read clocks
- Gray-code pointer CDC
- Configurable depth and width
- Domain-local full/empty flag generation
- 2-stage synchronizer-based metastability mitigation

### Architecture Components

1. Gray converter (`gray_converter.sv`): binary pointer to Gray code
2. Gray decoder (`gray_decoder.sv`): synchronized Gray code back to binary
3. CDC synchronizer (`cdc_sync.sv`): pointer transfer between domains
4. Domain logic: local pointer increment and full/empty decisions

### Asynchronous Parameters

```verilog
parameter DEPTH = 16;
parameter WIDTH = 8;
```

### Domain Separation

Write domain:

- Local state: `wr_ptr`, `wr_ptr_gray`
- Remote view: synchronized/decode read pointer
- Output: `full`

Read domain:

- Local state: `rd_ptr`, `rd_ptr_gray`
- Remote view: synchronized/decode write pointer
- Output: `empty`

### CDC Behavior Notes

- Synchronization latency is typically 2-3 destination clocks
- Gray coding constrains pointer transitions to one bit at a time
- Flags settle after synchronizer delay

### Asynchronous Interface Signals

| Signal | Domain | Dir | Width | Description |
| ------ | ------ | --- | ----- | ----------- |
| wr_clk | Write | I | 1 | Write clock |
| wr_rst_n | Write | I | 1 | Write reset, active-low |
| wr_data | Write | I | WIDTH | Write data |
| wr_en | Write | I | 1 | Write enable |
| full | Write | O | 1 | FIFO full flag |
| rd_clk | Read | I | 1 | Read clock |
| rd_rst_n | Read | I | 1 | Read reset, active-low |
| rd_data | Read | O | WIDTH | Read data |
| rd_en | Read | I | 1 | Read enable |
| empty | Read | O | 1 | FIFO empty flag |

### Timing Considerations

- Allow synchronizer settling after reset before relying on cross-domain flags
- `full` and `empty` are domain-valid and include CDC delay effects

## Implementation Guidance

### Synchronous FIFO Use Cases

- Same-domain buffering
- Low-overhead control paths
- Minimal CDC complexity

### Asynchronous FIFO Use Cases

- Multi-clock interfaces
- Throughput decoupling between producer and consumer domains
- Robust CDC boundary crossing

### Best Practices

1. Assert/reset domains cleanly at startup
2. Gate writes with `!full` and reads with `!empty`
3. Verify behavior with realistic clock ratios
4. Include stress tests with concurrent activity and reset events

## Simulation

### Sync Testbench (`sim/tb_sync_fifo.sv`)

- Basic and stress read/write sequences
- Boundary checks (full and empty)
- Protocol-violation warning checks

### Async Testbench (`sim/tb_async_fifo.sv`)

- Dual-clock stress sequences
- CDC synchronization verification
- Boundary and metastability-oriented scenarios
