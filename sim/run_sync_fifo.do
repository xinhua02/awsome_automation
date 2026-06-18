vlib work
vmap work work
vlog -sv +incdir=../src ../src/sync_fifo.sv
vlog -sv fifo_assertions.sv
vlog -sv tb_sync_fifo.sv
vsim -c tb_sync_fifo -do "run -all; exit"
