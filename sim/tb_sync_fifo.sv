// Testbench for Synchronous FIFO

`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter DEPTH = 16;
    parameter WIDTH = 8;
    
    logic clk;
    logic rst_n;
    
    // Write interface
    logic [WIDTH-1:0] wr_data;
    logic wr_en;
    logic full;
    
    // Read interface
    logic [WIDTH-1:0] rd_data;
    logic rd_en;
    logic empty;
    
    // Status
    logic [DEPTH-1:0] count;
    
    // Instantiate sync FIFO
    sync_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .full(full),
        .rd_data(rd_data),
        .rd_en(rd_en),
        .empty(empty),
        .count(count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end
    
    // Test sequence
    initial begin
        // Reset
        rst_n = 0;
        wr_data = 0;
        wr_en = 0;
        rd_en = 0;
        #20 rst_n = 1;
        
        $display("=== TEST 1: Write and Read Single Element ===");
        #10;
        // Write one element
        wr_data = 8'hAA;
        wr_en = 1;
        #10;
        wr_en = 0;
        #10;
        // Read one element
        rd_en = 1;
        #10;
        $display("Written: 0xAA, Read: 0x%02X", rd_data);
        rd_en = 0;
        #10;
        
        $display("=== TEST 2: Fill FIFO ===");
        #10;
        for (int i = 0; i < DEPTH; i++) begin
            if (!full) begin
                wr_data = 8'h10 + i;
                wr_en = 1;
                #10;
            end
        end
        wr_en = 0;
        #10;
        $display("FIFO Full: %b, Count: %d", full, count);
        
        $display("=== TEST 3: Read All Elements ===");
        #10;
        for (int i = 0; i < DEPTH; i++) begin
            if (!empty) begin
                rd_en = 1;
                #10;
                $display("Element %d: 0x%02X", i, rd_data);
            end
        end
        rd_en = 0;
        #10;
        $display("FIFO Empty: %b", empty);
        
        $display("=== TEST 4: Simultaneous Read/Write ===");
        #10;
        for (int i = 0; i < 8; i++) begin
            wr_data = 8'hB0 + i;
            wr_en = 1;
            if (i > 0) rd_en = 1;
            #10;
            if (i > 0) $display("Write: 0x%02X, Read: 0x%02X", wr_data, rd_data);
        end
        wr_en = 0;
        
        // Read remaining elements
        for (int i = 0; i < 4; i++) begin
            rd_en = 1;
            #10;
            $display("Read: 0x%02X", rd_data);
        end
        rd_en = 0;
        
        $display("=== TEST 5: Edge Case - Empty FIFO Read ===");
        #10;
        $display("Attempting to read from empty FIFO...");
        rd_en = 1;
        #10;
        $display("Read data (should be undefined): 0x%02X, Empty: %b", rd_data, empty);
        rd_en = 0;
        
        #50;
        $display("=== All Tests Complete ===");
        $finish;
    end

endmodule
