# FIFO Implementation Summary

## Overview

This repository contains complete synchronous and asynchronous FIFO implementations in SystemVerilog, together with testbenches, regression scripts, and verification documentation.

## Current Status

- Implementation: complete
- Regression: passing (sync + async)
- Primary regression entrypoint: `sim/regression_runner.ps1`
- Recommended sign-off gate: DUT-only coverage threshold (`-DutCoverageThreshold 100`)

## Deliverables

### 1. Synchronous FIFO (`src/sync_fifo.sv`)

- Single clock domain
- Parameterized depth and width
- Full and empty flags
- Real-time element count output
- Binary pointer implementation with extra MSB for full/empty disambiguation

Key conditions:

- Empty: `wr_ptr == rd_ptr`
- Full: write/read lower bits equal and MSBs differ

### 2. Asynchronous FIFO (`src/async_fifo.sv`)

- Independent write/read clock domains
- Gray-coded pointer CDC
- 2-stage synchronizers (`src/cdc_sync.sv`)
- Gray conversion helpers (`src/gray_converter.sv`, `src/gray_decoder.sv`)
- Domain-local full/empty status generation

CDC path summary:

```text
Write domain              Read domain
   wr_ptr                    rd_ptr
      -> gray                   -> gray
      -> sync to rd             -> sync to wr
      -> decode                 -> decode
      -> full decision          -> empty decision
```

### 3. Verification Environment

Synchronous testbench: `sim/tb_sync_fifo.sv`

- Concurrent read/write stress
- Random interval operations
- Full/empty boundary tests
- Protocol-violation warning checks

Asynchronous testbench: `sim/tb_async_fifo.sv`

- Dual-clock concurrent stress
- CDC behavior checks
- Boundary and protocol checks
- Metastability-oriented reset/timing stress

### 4. Documentation Set

- `README.md`: quick start, architecture, and commands
- `TEST_VERIFICATION_REPORT.md`: latest review and verification evidence
- `doc/FIFO_DESIGN.md`: design-level module behavior and interfaces

## Design Snapshot

### Synchronous FIFO

| Aspect | Details |
| ------ | ------- |
| Pointer width | `$clog2(DEPTH) + 1` |
| Empty condition | `wr_ptr == rd_ptr` |
| Full condition | MSB differs, lower bits match |
| Throughput | Up to 1 read + 1 write per cycle |
| Read data path | Combinational data output |

### Asynchronous FIFO

| Aspect | Details |
| ------ | ------- |
| Pointer encoding | Gray code across CDC boundaries |
| Synchronizer depth | 2 stages (default) |
| Typical CDC latency | ~2-3 destination clocks |
| Clocking | Independent write/read domains |

## File Layout (Key Files)

```text
src/
   sync_fifo.sv
   async_fifo.sv
   cdc_sync.sv
   gray_converter.sv
   gray_decoder.sv

sim/
   tb_sync_fifo.sv
   tb_async_fifo.sv
   run_sync_fifo.do
   run_async_fifo.do
   regression_runner.ps1
```

## Verified Commands

From `sim/`:

```powershell
./regression_runner.ps1
./regression_runner.ps1 -DutCoverageThreshold 100
```

Manual runs:

```powershell
vlib work
vmap work ./work
vlog -sv +incdir=../src ../src/*.sv fifo_assertions.sv tb_sync_fifo.sv
vsim -c tb_sync_fifo -do "run -all; exit"

vlib work
vmap work ./work
vlog -sv +incdir=../src ../src/*.sv fifo_assertions.sv tb_async_fifo.sv
vsim -c tb_async_fifo -do "run -all; exit"
```

## Notes

- Protocol-violation warnings are intentionally exercised by tests.
- Coverage artifacts are generated under `sim/coverage/` for each regression run with coverage enabled.
- Current sign-off recommendation is DUT-only gating (`-DutCoverageThreshold 100`) to avoid TB-only metric noise.

---

Last updated: 2026-06-18
Status: implementation and regression complete
