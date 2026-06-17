// Asynchronous FIFO - Dual clock domain with CDC (Clock Domain Crossing)
// Uses Gray code for safe synchronization across clock domains

module gray_converter #(
    parameter WIDTH = 4
) (
    input  logic [WIDTH-1:0] binary,
    output logic [WIDTH-1:0] gray
);
    assign gray = binary ^ (binary >> 1);
endmodule

module gray_decoder #(
    parameter WIDTH = 4
) (
    input  logic [WIDTH-1:0] gray,
    output logic [WIDTH-1:0] binary
);
    logic [WIDTH-1:0] temp;
    
    always_comb begin
        temp[WIDTH-1] = gray[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) begin
            temp[i] = temp[i+1] ^ gray[i];
        end
        binary = temp;
    end
endmodule

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

module async_fifo #(
    parameter DEPTH = 16,           // FIFO depth (power of 2)
    parameter WIDTH = 8             // Data width in bits
) (
    // Write clock domain
    input  logic                wr_clk,
    input  logic                wr_rst_n,
    input  logic [WIDTH-1:0]    wr_data,
    input  logic                wr_en,
    output logic                full,
    
    // Read clock domain
    input  logic                rd_clk,
    input  logic                rd_rst_n,
    output logic [WIDTH-1:0]    rd_data,
    input  logic                rd_en,
    output logic                empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    // Memory array
    logic [WIDTH-1:0] mem [DEPTH];
    
    // Write-domain pointers and Gray code
    logic [ADDR_WIDTH:0] wr_ptr, wr_ptr_gray, wr_ptr_gray_sync;
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync, rd_ptr_gray_decoded;
    
    // Read-domain pointers and Gray code
    logic [ADDR_WIDTH:0] rd_ptr, rd_ptr_gray, wr_ptr_gray_sync_rd;
    logic [ADDR_WIDTH:0] wr_ptr_gray_decoded;
    
    // Memory write address and read address
    logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    
    assign wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    assign rd_addr = rd_ptr[ADDR_WIDTH-1:0];
    
    // Convert binary pointers to Gray code
    gray_converter #(.WIDTH(ADDR_WIDTH+1)) wr_gray_conv (
        .binary(wr_ptr),
        .gray(wr_ptr_gray)
    );
    
    gray_converter #(.WIDTH(ADDR_WIDTH+1)) rd_gray_conv (
        .binary(rd_ptr),
        .gray(rd_ptr_gray)
    );
    
    // Synchronize Gray-coded pointers across clock domains
    cdc_sync #(.WIDTH(ADDR_WIDTH+1), .STAGES(2)) wr_to_rd_sync (
        .src_clk(wr_clk),
        .dst_clk(rd_clk),
        .rst_n(rd_rst_n),
        .src_data(wr_ptr_gray),
        .dst_data(wr_ptr_gray_sync_rd)
    );
    
    cdc_sync #(.WIDTH(ADDR_WIDTH+1), .STAGES(2)) rd_to_wr_sync (
        .src_clk(rd_clk),
        .dst_clk(wr_clk),
        .rst_n(wr_rst_n),
        .src_data(rd_ptr_gray),
        .dst_data(rd_ptr_gray_sync)
    );
    
    // Decode synchronized Gray pointers
    gray_decoder #(.WIDTH(ADDR_WIDTH+1)) rd_decode (
        .gray(rd_ptr_gray_sync),
        .binary(rd_ptr_gray_decoded)
    );
    
    gray_decoder #(.WIDTH(ADDR_WIDTH+1)) wr_decode (
        .gray(wr_ptr_gray_sync_rd),
        .binary(wr_ptr_gray_decoded)
    );
    
    // Empty flag (read domain): empty when synchronized write pointer equals read pointer
    assign empty = (rd_ptr == wr_ptr_gray_decoded);
    
    // Full flag (write domain): full when synchronized read pointer indicates no space
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr_gray_decoded[ADDR_WIDTH]) && 
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr_gray_decoded[ADDR_WIDTH-1:0]);
    
    // Read data from memory
    assign rd_data = mem[rd_addr];
    
    // Write logic (write clock domain)
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read logic (read clock domain)
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule
