# AGENTS.md — Agent guidance for awsome_automation

Purpose
- Short, actionable instructions for AI coding agents working on this repo.

Where to look first
- [src/](src/) — FIFO implementations (`sync_fifo.sv`, `async_fifo.sv`)
- [sim/](sim/) — Testbenches and simulation scripts
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) — Design overview
- [TEST_VERIFICATION_REPORT.md](TEST_VERIFICATION_REPORT.md) — Test outcomes and coverage
- [doc/](doc/) — Design notes and coding conventions

Build & test (most useful commands)
- Simulation (full):
  - `cd sim && ./regression_runner.ps1 -DutCoverageThreshold 100`
- Compile only: `vlog src/*.sv sim/*.sv`
- Interactive simulation: `vsim <testbench_module>`
- Waveform viewing: `vsim -view results.wdb`
- Single test (non-GUI): `vsim -c <testbench_module_name> -do "run -all; exit"`

High-level architecture
- Synchronous FIFO: single clock domain, binary pointers, full/empty logic
- Asynchronous FIFO: dual clock domains, Gray-code pointers, CDC synchronization
- Test environment: `sim/` contains testbenches, scripts, and helper assertions

Key repo conventions
- Prefer Gray code for cross-clock pointer synchronization
- Full/empty flag logic based on write/read pointer comparisons
- Tests and scripts assume Windows-friendly shell commands (PowerShell / batch)

Link, don’t embed
- Do not copy long documentation into this file. Link to the authoritative sources in `doc/`, `IMPLEMENTATION_SUMMARY.md`, and `TEST_VERIFICATION_REPORT.md`.

When to update this file
- Add exact CI or regression commands when CI is added
- Add language-specific build steps if non-Verilog components are introduced

Quick session checklist
1. Run the single-test command for the testbench you're working on
2. Inspect `sim/` testbenches for stimulus patterns
3. Consult `doc/VerilogCodingStyle.md` for style rules
4. If adding tests, update `TEST_VERIFICATION_REPORT.md` with expected pass criteria

Next suggested agent customizations
- `skill:modelsim-runner` — wrapper to run common ModelSim workflows and parse results
- `hook:verify-on-commit` — lightweight CI hook to run fast smoke tests

(Generated 2026-06-18)