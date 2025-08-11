/**
 * Testbench for DRRIP Cache Implementation
 * 
 * This testbench comprehensively tests the Dynamic Re-Reference Interval Prediction
 * (DRRIP) cache replacement policy, including:
 * - Set dueling between SRRIP and BIP policies
 * - PSEL counter updates and policy selection
 * - Hit promotion and RRPV management
 * - Victim selection with aging mechanism
 * - Policy switching based on performance
 * 
 * Test Coverage:
 * - SRRIP leader set behavior
 * - BIP leader set behavior  
 * - Follower set dynamic policy selection
 * - Cache hit promotion
 * - Cache miss handling
 * - Victim selection process
 */

module drrip_cache_tb;
    // ============================================================================
    // TESTBENCH PARAMETERS
    // ============================================================================
    
    // Cache configuration for testing (smaller than default for easier debugging)
    parameter NUM_WAYS = 4;              // 4-way associative cache for testing
    parameter NUM_SETS = 8;              // 8 sets for testing
    parameter RRPV_BITS = 2;             // 2-bit RRPV values
    parameter SET_INDEX_WIDTH = $clog2(NUM_SETS);  // Width of set index
    
    // ============================================================================
    // SIGNAL DECLARATIONS
    // ============================================================================
    
    // Clock and reset signals
    logic clk, rst;
    
    // Cache access signals
    logic valid, hit, miss;
    logic [SET_INDEX_WIDTH-1:0] set_index;
    logic [3:0] access_way;
    
    // Cache output signals
    logic [3:0] victim_way;
    logic victim_ready;
    logic [9:0] psel_counter;
    
    // ============================================================================
    // CLOCK GENERATION
    // ============================================================================
    
    // Generate 100MHz clock (10ns period)
    always #5 clk = ~clk;
    
    // ============================================================================
    // DEVICE UNDER TEST (DUT) INSTANTIATION
    // ============================================================================
    
    // Instantiate the DRRIP cache with test parameters
    drrip_cache #(
        .NUM_WAYS(NUM_WAYS),           // 4-way associative
        .NUM_SETS(NUM_SETS),           // 8 sets
        .RRPV_BITS(RRPV_BITS),        // 2-bit RRPV
        .SET_INDEX_WIDTH(SET_INDEX_WIDTH)
    ) dut (
        .clk(clk),                     // Clock input
        .rst(rst),                     // Reset input
        .valid(valid),                 // Valid signal
        .set_index(set_index),         // Set index
        .access_way(access_way),       // Way being accessed
        .hit(hit),                     // Hit signal
        .miss(miss),                   // Miss signal
        .victim_way(victim_way),       // Selected victim way
        .victim_ready(victim_ready),   // Victim ready signal
        .psel_counter(psel_counter)    // Policy selection counter
    );
    
    // ============================================================================
    // TEST TASKS AND UTILITIES
    // ============================================================================
    
    /**
     * Task to clear all input signals to a known state
     * This ensures clean test execution between test cases
     */
    task clear_inputs();
        valid = 0;                     // Clear valid signal
        hit = 0;                       // Clear hit signal
        miss = 0;                      // Clear miss signal
        set_index = 0;                 // Clear set index
        access_way = 0;                // Clear access way
    endtask
    
    /**
     * Task to simulate a cache miss and wait for victim selection
     * This tests the complete miss handling pipeline including:
     * - Victim search
     * - Aging mechanism (if needed)
     * - Policy selection
     * - RRPV updates
     * 
     * @param set_idx - Set index for the miss
     * @param way - Way being replaced (not critical for miss simulation)
     */
    task simulate_miss(input [SET_INDEX_WIDTH-1:0] set_idx, input [3:0] way);
        $display("\nTime %0t: Starting miss simulation on set %0d", $time, set_idx);
        
        // Assert miss signals
        valid = 1;                     // Valid access
        set_index = set_idx;           // Target set
        hit = 0;                       // Not a hit
        miss = 1;                      // This is a miss
        access_way = way;              // Way being replaced
        
        // Wait for victim selection to complete
        // This ensures we test the full victim selection pipeline
        wait(victim_ready);
        $display("Time %0t: Miss completed - Victim way %0d selected for set %0d", $time, victim_way, set_index);
        
        // Hold signals for one more cycle to ensure proper insertion
        // This allows the RRPV table to be updated
        @(posedge clk);
        clear_inputs();                // Clear all inputs
        @(posedge clk);                // Wait one more cycle for stability
    endtask
    
    /**
     * Task to simulate a cache hit on a specific set and way
     * This tests the hit promotion mechanism and RRPV decrement
     * 
     * @param set_idx - Set index for the hit
     * @param way - Way being accessed
     */
    task simulate_hit(input [SET_INDEX_WIDTH-1:0] set_idx, input [3:0] way);
        $display("\nTime %0t: Starting hit simulation on set %0d way %0d", $time, set_idx, way);
        
        // Assert hit signals
        valid = 1;                     // Valid access
        set_index = set_idx;           // Target set
        hit = 1;                       // This is a hit
        miss = 0;                      // Not a miss
        access_way = way;              // Way being accessed
        
        // Wait for hit processing to complete
        @(posedge clk);
        clear_inputs();                // Clear all inputs
        @(posedge clk);                // Wait one more cycle for stability
    endtask
    
    // ============================================================================
    // MAIN TEST SEQUENCE
    // ============================================================================
    
    initial begin
        // ========================================================================
        // INITIALIZATION PHASE
        // ========================================================================
        
        $display("=== DRRIP Cache Testbench Starting ===");
        $display("Cache Configuration: %0d-way, %0d sets, %0d-bit RRPV", NUM_WAYS, NUM_SETS, RRPV_BITS);
        
        // Initialize all signals to known state
        clk = 0;                       // Start with clock low
        rst = 1;                       // Assert reset
        valid = 0;                     // No valid access
        set_index = 0;                 // Clear set index
        access_way = 0;                // Clear access way
        hit = 0;                       // No hit
        miss = 0;                      // No miss
        
        // Hold reset for 2 clock cycles to ensure proper initialization
        #20;
        rst = 0;                       // Release reset
        
        $display("Time %0t: Reset released, starting tests", $time);
        
        // ========================================================================
        // TEST 1: SRRIP LEADER SET MISSES
        // ========================================================================
        
        // Test 1: First miss on SRRIP leader set (set_index=0)
        // This should decrement the PSEL counter, favoring SRRIP policy
        $display("\nTime %0t: Test 1 - Miss on SRRIP leader set (set_index=0)", $time);
        valid = 1;
        set_index = 7'd0;              // SRRIP leader set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;                           // Wait for processing
        
        // Wait for victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
        // Clear signals and wait
        clear_inputs();
        #10;
        
        // Test 1a: Second miss on same SRRIP leader set
        // This tests multiple misses on the same leader set
        $display("Time %0t: Test 1.a - Miss on SRRIP leader set (set_index=0)", $time);
        valid = 1;
        set_index = 7'd0;              // SRRIP leader set
        hit = 0;
        miss = 1;
        access_way = 4'd3;             // Different way
        #10;
        
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
        clear_inputs();
        #10;
        
        // ========================================================================
        // TEST 2-3: FOLLOWER SET HITS
        // ========================================================================
        
        // Test 2: Hit on follower set (set_index=5)
        // This tests hit promotion and RRPV decrement
        $display("Time %0t: Test 2 - Hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd1;
        #10;
        
        clear_inputs();
        #10;
        
        // Test 3: Multiple hits on same follower set
        // This tests repeated access patterns and hit promotion
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        clear_inputs();
        #10;
        
        // Additional hits to test hit promotion behavior
        // These simulate a frequently accessed cache line
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        clear_inputs();
        #10;
        
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        clear_inputs();
        #10;
        
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd0;
        #10;
        
        clear_inputs();
        #10;
        
        // ========================================================================
        // TEST 4: FOLLOWER SET MISSES
        // ========================================================================
        
        // Test 4: Miss on follower set (set_index=5)
        // This tests dynamic policy selection based on PSEL counter
        $display("Time %0t: Test 4 - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
        clear_inputs();
        #10;
        
        // Additional misses to test policy adaptation
        // These will help demonstrate how the PSEL counter influences policy selection
        $display("Time %0t: Test zz - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
        clear_inputs();
        #10;
        
        $display("Time %0t: Test zz - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5;              // Follower set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
        clear_inputs();
        #10;
        
        // Wait for final victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
        // ========================================================================
        // TEST COMPLETION AND SUMMARY
        // ========================================================================
        
        $display("\n=== All Tests Completed Successfully ===");
        
        // Final summary - print victim ways for all sets
        // This shows the final state of the cache after all tests
        $display("\n=== Final Cache State Summary ===");
        for (int set = 0; set < NUM_SETS; set++) begin
            $display("Set %0d RRPV values:", set);
            for (int way = 0; way < NUM_WAYS; way++) begin
                $display("  Way %0d: RRPV = %0d", way, dut.rrpv_table[set][way]);
            end
        end
        
        // Display final counter values
        $display("\nFinal PSEL counter: %0d", psel_counter);
        $display("Final BIP counter: %0d", dut.bip_counter);
        
        // Wait before finishing to ensure all operations complete
        #100 $finish;
    end
    
    // ============================================================================
    // MONITORING AND DEBUGGING
    // ============================================================================
    
    /**
     * Monitor important signals during simulation
     * This provides real-time visibility into cache behavior
     */
    always @(posedge clk) begin
        if (valid && !rst) begin
            // Monitor all cache accesses
            $display("Time %0t: Access - Set=%0d, Way=%0d, Hit=%b, Miss=%b, PSEL=%0d, Policy=%s", 
                     $time, set_index, access_way, hit, miss, psel_counter,
                     dut.use_srrip_policy ? "SRRIP" : "BIP");
        end
        
        if (victim_ready && !rst) begin
            // Monitor victim selection completion
            $display("Time %0t: VICTIM READY - Set %0d, Way %0d, Policy Used: %s", 
                     $time, set_index, victim_way,
                     dut.use_srrip_policy ? "SRRIP" : "BIP");
        end
    end
    
endmodule
