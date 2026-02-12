
`timescale 1ns / 1ps

module cache_controller_tb;

    // Test signals declaration
    logic clk;                    // System clock
    logic rst;                    // Reset signal
    logic read_req;              // Read request signal
    logic write_req;             // Write request signal
    logic [23:0] addr;           // Memory address
    logic evict, allocate;       // Cache control signals
    logic write_back;            // Write-back signal
    logic mem_ready;             // Memory ready signal

    cache_controller uut (
        .clk(clk),
        .rst(rst),
        .read_req(read_req),
        .write_req(write_req),
        .addr(addr),
        .mem_ready(mem_ready),
        .evict(evict),
        .allocate(allocate),
        .write_back(write_back)
    );

    // Enable waveform dumping for simulation analysis
    initial begin
        $dumpfile("dump.vcd");   // Create VCD file for waveform viewing
        $dumpvars;               // Dump all variables
    end

    
    always #5 clk = ~clk;

    // Helper task for clock synchronization
    // Waits for positive clock edge plus 1ns for signal stabilization
    task run_cycle();
        @(posedge clk);
        #1;
    endtask

    // Initial setup and reset sequence
    initial begin
        // Initialize all signals to zero
        clk = 0;
        rst = 0;
        read_req = 0;
        write_req = 0;
        addr = 0;
        mem_ready = 0;
        #10;                     // Wait 10ns
        rst = 1;                 // Release reset
        run_cycle();             // Wait for one clock cycle
    end

    // Main test sequence
    initial begin
        @(posedge rst);         // Wait for reset to complete

        // TEST 1: READ HIT
        // First access will miss and allocate, second access will hit
        addr = 24'h123456;      // Set test address
        read_req = 1;           // Assert read request
        run_cycle(); run_cycle(); run_cycle();
        mem_ready = 0; run_cycle();
        mem_ready = 1; run_cycle();
        read_req = 0; mem_ready = 0; run_cycle();

        // Second read to same address - should hit
        read_req = 1;
        run_cycle(); run_cycle();
        read_req = 0; run_cycle();

        // TEST 2: WRITE HIT
        // Write to same address - should hit in cache
        addr = 24'h123456;      // Same address as previous read
        write_req = 1;
        run_cycle(); run_cycle();
        write_req = 0; run_cycle();

        // TEST 3: READ MISS with dirty evict
        // New address causing eviction of dirty block
        addr = 24'h222222;
        read_req = 1;
        run_cycle(); run_cycle(); run_cycle();
        mem_ready = 1; run_cycle();
        read_req = 0; mem_ready = 0; run_cycle();

        // TEST 4: WRITE MISS
        // Write to new address causing miss
        addr = 24'h333333;
        write_req = 1;
        run_cycle(); run_cycle(); run_cycle();
        mem_ready = 1; run_cycle();
        write_req = 0; mem_ready = 0; run_cycle();

        // TEST 5: CLEAN EVICT / NO write_back
        // Read miss with clean block eviction
        addr = 24'h444444;
        read_req = 1;
        run_cycle(); run_cycle(); run_cycle();
        mem_ready = 1; run_cycle();
        read_req = 0; mem_ready = 0; run_cycle();

        // TEST 6: WRITE MISS to different index
        // Write miss targeting different cache set
        addr = 24'h555555;
        write_req = 1;
        run_cycle(); run_cycle(); run_cycle();
        mem_ready = 1; run_cycle();
        write_req = 0; mem_ready = 0; run_cycle();

        // Test completion
        $display("All tests complete.");
        $finish;             
    end
endmodule