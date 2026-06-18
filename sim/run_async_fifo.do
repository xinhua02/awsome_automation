vlib work
vmap work work
vlog -sv +incdir=../src ../src/async_fifo.v
vlog -sv fifo_assertions.sv
vlog -sv tb_async_fifo.sv
vsim -c tb_async_fifo -do "run -all; exit"
