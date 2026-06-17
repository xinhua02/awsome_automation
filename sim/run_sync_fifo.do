#!/usr/bin/env tclsh
# QuestaSim simulation script for Synchronous FIFO

# Create work library
vlib work
vmap work work

# Compile Verilog source files
vlog -sv +incdir+./src ./src/sync_fifo.v
vlog -sv +incdir+./sim ./sim/tb_sync_fifo.sv

# Elaborate and run simulation
vsim -c -do "run -all; quit" tb_sync_fifo

exit
