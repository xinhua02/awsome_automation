vlib work
vmap work work
vlog -sv +incdir=../src ../src/gray_converter.sv ../src/gray_decoder.sv ../src/cdc_sync.sv ../src/async_fifo.sv
vlog -sv fifo_assertions.sv
vlog -sv tb_async_fifo.sv
vsim -c tb_async_fifo -do "run -all; exit"
