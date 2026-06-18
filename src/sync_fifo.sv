// Synchronous FIFO - Single clock domain
// FIFO depth and data width are configurable via parameters

module sync_fifo #(
  parameter DEPTH = 16,           // FIFO depth (power of 2 recommended)
  parameter WIDTH = 8             // Data width in bits
) (
  input  logic                clk,
  input  logic                rst_n,

  // Write interface
  input  logic [WIDTH-1:0]    wr_data,
  input  logic                wr_en,
  output logic                full,

  // Read interface
  output logic [WIDTH-1:0]    rd_data,
  input  logic                rd_en,
  output logic                empty,

  // Status
  output logic [DEPTH-1:0]    count
);

  // Calculate address width
  localparam ADDR_WIDTH = $clog2(DEPTH);
  
  // Memory array
  logic [WIDTH-1:0] mem [DEPTH];
  
  // Read and write pointers
  logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;  // Extra bit for empty/full detection
  logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
  
  // Current count
  logic [ADDR_WIDTH:0] fifo_count;
  
  // Assign addresses (lower bits of pointers)
  assign wr_addr = wr_ptr[ADDR_WIDTH-1:0];
  assign rd_addr = rd_ptr[ADDR_WIDTH-1:0];
  
  // Empty and full flags
  assign empty = (wr_ptr == rd_ptr);
  assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
  
  // Calculate count
  assign fifo_count = wr_ptr - rd_ptr;
  assign count = fifo_count[ADDR_WIDTH-1:0];
  
  // Read data
  assign rd_data = mem[rd_addr];
  
  // Write logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
    end else if (wr_en && !full) begin
      mem[wr_addr] <= wr_data;
      wr_ptr <= wr_ptr + 1;
    end
  end
  
  // Read logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr <= '0;
    end else if (rd_en && !empty) begin
      rd_ptr <= rd_ptr + 1;
    end
  end

endmodule
