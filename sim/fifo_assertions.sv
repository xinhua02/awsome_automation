// Small SVA assertions bound into FIFO modules to catch obvious protocol bugs
`timescale 1ns/1ps

// Assertions for synchronous FIFO
module fifo_asserts_sync (
  input logic clk,
  input logic full,
  input logic empty
);
  // sample on FIFO clock; ensure full and empty are not both asserted
  property sync_no_both_flags;
    @(posedge clk) !(full && empty);
  endproperty
  assert property (sync_no_both_flags) else $error("sync_fifo: full && empty asserted simultaneously at %0t", $time);
endmodule

// Assertions for asynchronous FIFO
module fifo_asserts_async (
  input logic wr_clk,
  input logic rd_clk,
  input logic full,
  input logic empty
);
  // On write clock domain, full and empty should not both be true
  property async_no_both_flags_wr;
    @(posedge wr_clk) !(full && empty);
  endproperty
  assert property (async_no_both_flags_wr) else $error("async_fifo (wr_clk): full && empty both true at %0t", $time);

  // On read clock domain, full and empty should not both be true
  property async_no_both_flags_rd;
    @(posedge rd_clk) !(full && empty);
  endproperty
  assert property (async_no_both_flags_rd) else $error("async_fifo (rd_clk): full && empty both true at %0t", $time);
endmodule

// Bind the assertions into the corresponding FIFO modules with explicit port mapping
bind sync_fifo fifo_asserts_sync u_fifo_asserts_sync(.clk(clk), .full(full), .empty(empty));
bind async_fifo fifo_asserts_async u_fifo_asserts_async(.wr_clk(wr_clk), .rd_clk(rd_clk), .full(full), .empty(empty));
