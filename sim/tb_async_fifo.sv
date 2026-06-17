// Testbench for Asynchronous FIFO

`timescale 1ns / 1ps

module tb_async_fifo;

    parameter DEPTH = 16;
    parameter WIDTH = 8;
    
    logic wr_clk, wr_rst_n;
    logic rd_clk, rd_rst_n;
    
    // Write interface
    logic [WIDTH-1:0] wr_data;
    logic wr_en;
    logic full;
    
    // Read interface
    logic [WIDTH-1:0] rd_data;
    logic rd_en;
    logic empty;
    
    // Instantiate async FIFO
    async_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) dut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .full(full),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_data(rd_data),
        .rd_en(rd_en),
        .empty(empty)
    );
    
    // Clock generation with different frequencies
    // Write clock: 100 MHz
    initial begin
        wr_clk = 0;
        forever #5 wr_clk = ~wr_clk;
    end
    
    // Read clock: 150 MHz (faster clock domain)
    initial begin
        rd_clk = 0;
        forever #3.33 rd_clk = ~rd_clk;
    end
    
    // Test sequence
    initial begin
        // Initialize
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_data = 0;
        wr_en = 0;
        rd_en = 0;

        #100;
        wr_rst_n = 1;
        rd_rst_n = 1;

        // 1) Normal Operation: concurrent read/write stress testing
        $display("=== CASE 1: Concurrent Read/Write Stress (async) ===");
        fork
            begin : wr_proc
                repeat (512) begin
                    @(posedge wr_clk);
                    if (!full) begin
                        wr_data = $urandom_range(0,255);
                        wr_en = 1;
                    end else begin
                        // Attempt write when full
                        wr_en = 1;
                    end
                    @(posedge wr_clk); wr_en = 0;
                    repeat ($urandom_range(0,2)) @(posedge wr_clk);
                end
            end
            begin : rd_proc
                // small startup delay
                repeat (10) @(posedge rd_clk);
                repeat (512) begin
                    @(posedge rd_clk);
                    if (!empty) begin rd_en = 1; end else rd_en = 0;
                    @(posedge rd_clk); rd_en = 0;
                    repeat ($urandom_range(0,3)) @(posedge rd_clk);
                end
            end
        join

        // 2) Random interval operations
        $display("=== CASE 2: Random Interval Operations ===");
        for (int i = 0; i < 128; i++) begin
            if ($urandom_range(0,1)) begin
                @(posedge wr_clk);
                if (!full) begin wr_data = $urandom_range(0,255); wr_en = 1; end
                @(posedge wr_clk); wr_en = 0;
            end else begin
                @(posedge rd_clk);
                if (!empty) begin rd_en = 1; end
                @(posedge rd_clk); rd_en = 0;
            end
        end

        // 3) Boundary Conditions: Fill to full and test Full flag & write-when-full
        $display("=== CASE 3: Boundary - Fill to Full and Write-when-Full ===");
        // Fill
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge wr_clk);
            if (!full) begin wr_data = i; wr_en = 1; end
            @(posedge wr_clk); wr_en = 0;
        end
        @(posedge wr_clk);
        if (!full) $error("Expected FIFO to be full but Full flag is 0 (async)");
        // Attempt extra write across clock boundary to exercise CDC
        @(posedge wr_clk); wr_data = 8'hEE; wr_en = 1; #1; // small delay near edge
        @(posedge wr_clk); if (wr_en && full) $warning("Async: write attempted while FIFO full (expected)"); wr_en = 0;

        // 4) Empty flag assertion testing and read-when-empty detection
        $display("=== CASE 4: Boundary - Drain to Empty and Read-when-Empty ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge rd_clk);
            if (!empty) begin rd_en = 1; end
            @(posedge rd_clk); rd_en = 0;
        end
        @(posedge rd_clk);
        if (!empty) $error("Expected FIFO to be empty but Empty flag is 0 (async)");
        // Attempt extra read
        @(posedge rd_clk); rd_en = 1; #1; // near-edge event
        @(posedge rd_clk); if (rd_en && empty) $warning("Async: read attempted while FIFO empty (expected)"); rd_en = 0;

        // 5) Metastability injection: create near-synchronous toggles and asynchronous resets
        $display("=== CASE 5: Metastability Injection ===");
        // Perform rapid phase shifts and asynchronous reset pulses
        repeat (50) begin
            // random short bursts on write side
            @(posedge wr_clk);
            if (!full) begin wr_data = $urandom_range(0,255); wr_en = 1; end
            #($urandom_range(0,3)); // small non-clock aligned delay
            @(posedge wr_clk); wr_en = 0;

            // occasionally toggle read reset asynchronously
            if ($urandom_range(0,20) == 0) begin
                rd_rst_n = 0; #3; rd_rst_n = 1; // asynchronous reset pulse
                $display("Injected async rd reset at time %0t", $time);
            end
        end
        #200;

        // 6 & 7) Error Cases: write-when-full and read-when-empty are monitored by warnings
        $display("=== All Async FIFO Cases Complete ===");
        #100;
        $finish;
    end

    // Monitor for potential issues
    initial begin
        forever begin
            @(posedge wr_clk);
            if (wr_en && full) begin
                $warning("Write attempted while FIFO is full!");
            end
        end
    end

    initial begin
        forever begin
            @(posedge rd_clk);
            if (rd_en && empty) begin
                $warning("Read attempted while FIFO is empty!");
            end
        end
    end

endmodule
