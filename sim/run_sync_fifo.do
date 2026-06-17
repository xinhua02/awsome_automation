vlib work
vmap work work
vlog -sv +incdir=../src ../src/sync_fifo.v
vlog -sv tb_sync_fifo.sv
vsim -c tb_sync_fifo -do "run -all; exit"
