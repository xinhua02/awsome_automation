// Simple CDC synchronizer for multi-bit buses (STAGES flip-flop pipeline)
module cdc_sync #(
  parameter WIDTH = 4,
  parameter STAGES = 2
) (
  input  logic                src_clk,
  input  logic                dst_clk,
  input  logic                rst_n,
  input  logic [WIDTH-1:0]    src_data,
  output logic [WIDTH-1:0]    dst_data
);
  logic [WIDTH-1:0] sync_ff [STAGES];
  
  // Synchronization in destination clock domain
  always_ff @(posedge dst_clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < STAGES; i++) begin
        sync_ff[i] <= '0;
      end
    end else begin
      sync_ff[0] <= src_data;
      for (int i = 1; i < STAGES; i++) begin
        sync_ff[i] <= sync_ff[i-1];
      end
    end
  end
  
  assign dst_data = sync_ff[STAGES-1];
endmodule
