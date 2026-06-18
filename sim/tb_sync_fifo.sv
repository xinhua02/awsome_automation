// Testbench for Synchronous FIFO

`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter DEPTH = 16;
    parameter WIDTH = 8;
    
    logic clk;
    logic rst_n;
    int error_count = 0;
    int warn_count = 0;
    
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
    // Expected data queue for verification
    logic [WIDTH-1:0] expected_q[$];
    
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

        // 1) Normal Operation: concurrent read/write stress testing
        $display("=== CASE 1: Concurrent Read/Write Stress ===");
        fork
            begin : writer
                repeat (256) begin
                    @(posedge clk);
                    if (!full) begin
                        wr_data = $urandom_range(0,255);
                        wr_en = 1;
                        expected_q.push_back(wr_data);
                    end else begin
                        // attempt write when full (error case check)
                        wr_en = 1;
                    end
                    @(posedge clk);
                    wr_en = 0;
                    // random idle cycles
                    repeat ($urandom_range(0,3)) @(posedge clk);
                end
            end
            begin : reader
                // stagger reader a few cycles
                repeat (5) @(posedge clk);
                repeat (256) begin
                    @(posedge clk);
                    logic [WIDTH-1:0] expected_val;
                    if (!empty) begin
                        rd_en = 1;
                        expected_val = expected_q.pop_front();
                    end else begin
                        rd_en = 0;
                    end
                    @(posedge clk);
                    if (rd_en) begin
                        if (rd_data !== expected_val) begin
                            error_count += 1;
                            $error("sync_fifo: Data mismatch at %0t - expected %0h got %0h", $time, expected_val, rd_data);
                        end
                    end
                    rd_en = 0;
                    // random idle cycles
                    repeat ($urandom_range(0,4)) @(posedge clk);
                end
            end
        join

        // 2) Random interval operations
        $display("=== CASE 2: Random Interval Operations ===");
        for (int i = 0; i < 64; i++) begin
            @(posedge clk);
            if ($urandom_range(0,1)) begin
                if (!full) begin wr_data = $urandom_range(0,255); wr_en = 1; end
            end else begin
                if (!empty) begin rd_en = 1; end
            end
            @(posedge clk);
            wr_en = 0; rd_en = 0;
        end

        // 3) Boundary Conditions: Fill to full and test Full flag & write-when-full detection
        $display("=== CASE 3: Boundary - Fill to Full and Write-when-Full ===");
        // Fill
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            if (!full) begin wr_data = i; wr_en = 1; end
            @(posedge clk); wr_en = 0;
        end
        @(posedge clk);
        if (!full) begin error_count += 1; $error("Expected FIFO to be full but Full flag is 0"); end
        // Attempt one extra write
        @(posedge clk);
        wr_data = 8'hFF; wr_en = 1;
        @(posedge clk);
        if (wr_en && full) begin warn_count += 1; $warning("Write attempted while FIFO full (detected as expected)"); end
        wr_en = 0;

        // 4) Empty flag assertion testing and read-when-empty detection
        $display("=== CASE 4: Boundary - Drain to Empty and Read-when-Empty ===");
        // Drain all
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            if (!empty) begin rd_en = 1; end
            @(posedge clk); rd_en = 0;
        end
        @(posedge clk);
        if (!empty) begin error_count += 1; $error("Expected FIFO to be empty but Empty flag is 0"); end
        // Attempt one extra read
        @(posedge clk);
        rd_en = 1;
        @(posedge clk);
        if (rd_en && empty) begin warn_count += 1; $warning("Read attempted while FIFO empty (detected as expected)"); end
        rd_en = 0;

        // 5) Error Cases already covered above (write-when-full/read-when-empty warnings)

        $display("=== All Sync FIFO Cases Complete ===");
        #20;
        // Write compact report for post-sim comparison
        integer fh;
        fh = $fopen("c:/Users/xinhua02/awsome_automation/awsome_automation/sim/sync_tb_report.txt", "w");
        if (fh == 0) begin
            $display("sync_fifo: FOPEN FAILED for sync_tb_report.txt (fh=%0d)", fh);
        end else begin
            $fdisplay(fh, "errors=%0d warnings=%0d", error_count, warn_count);
            $fclose(fh);
            $display("Testbench finished. Report written to sim/sync_tb_report.txt (fh=%0d)", fh);
        end
        $finish;
    end

    // Monitor: verify DUT-reported count matches expected queue size
    initial begin
        forever @(posedge clk) begin
            if (count !== expected_q.size()) begin
                error_count += 1;
                $error("sync_fifo: Count mismatch at %0t: count=%0d expected=%0d", $time, count, expected_q.size());
            end
        end
    end

endmodule
