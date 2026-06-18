# Copilot instructions for awsome_automation

Purpose
- Provide succinct, repository-specific guidance for FIFO queue design verification in Verilog/SystemVerilog.

What was found
- **Project Type**: Hardware verification (Synchronous & Asynchronous FIFO designs)
- **Language**: Verilog (SystemVerilog for testbenches)
- **Structure**: 
  - `src/` — Verilog modules (sync_fifo.sv, async_fifo.sv)
  - `sim/` — Simulation testbenches and environment
  - `doc/` — Documentation and design notes

Build, test, and lint commands
- Simulation: `vlib work && vmap work ./work && vlog src/*.sv sim/*.sv && vsim -c -do "run; quit" <testbench_module>`
- Compile only: `vlog src/*.sv sim/*.sv`
- Interactive simulation: `vsim <testbench_module>` (opens GUI)
- Waveform viewing: `vsim -view results.wdb` or use ModelSim waveform viewer
- Single test: `vsim -c -do "run; quit" <testbench_module_name>`

High-level architecture (current)
- **Synchronous FIFO** (`src/sync_fifo.v`): Single clock domain, binary pointers, full/empty flags
- **Asynchronous FIFO** (`src/async_fifo.v`): Dual clock domains, Gray code CDC, metastability safe
- **Test Environment** (`sim/`): Testbenches with concurrent read/write, stimulus generation
- Key design pattern: Gray code for pointer synchronization across clock domains

Where Copilot should look first
- `src/` — FIFO module implementations
- `sim/` — Testbenches, coverage models, verification environment
- `IMPLEMENTATION_SUMMARY.md` — High-level design overview
- `TEST_VERIFICATION_REPORT.md` — Test results and coverage

Key conventions and heuristics for this repository
- FIFO designs follow standard CDC (Clock Domain Crossing) best practices
- Gray code is used for safe pointer synchronization across domains
- Full flag: MSB of write pointer differs, lower bits match with read pointer
- Empty flag: All bits of write pointer match read pointer
- Windows environment is current; scripts should be shell-compatible

Integration with existing docs / assistant configs
- README.md exists but has no actionable content to incorporate.
- No detected assistant config files (CLAUDE.md, .cursorrules, AGENTS.md, .windsurfrules, CONVENTIONS.md, etc.). If such files are added later, include their important rules here.

How to update this file
- When adding tests, CI, or build tooling, add the exact commands under "Build, test, and lint commands" (single-test examples too).
- If the repo adopts language-specific layouts (Python package, Node package, Terraform), add a short "High-level architecture (expanded)" section describing the layout and entrypoints.

Quick Copilot session checklist
1. Search for manifests and entrypoints (see "Where Copilot should look first").
2. If none found, ask the user what language/runtime they intend to use (do not scaffold without confirmation).
3. If scaffolding is requested, create minimal files and include tests/examples.

Notes for maintainers
- Keep this file up to date when adding build/test/lint scripts or changing the project structure.

(Generated on 2026-06-16)
