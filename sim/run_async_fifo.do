#!/usr/bin/env tclsh
# QuestaSim simulation script for Asynchronous FIFO

# Create work library
vlib work
vmap work work

# Compile Verilog source files
vlog -sv +incdir+./src ./src/async_fifo.v
vlog -sv +incdir+./sim ./sim/tb_async_fifo.sv

# Elaborate and run simulation
vsim -c -do "run -all; quit" tb_async_fifo

exit
