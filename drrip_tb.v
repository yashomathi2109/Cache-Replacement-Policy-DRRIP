// Testbench for DRRIP Cache
module drrip_cache_tb;
    parameter NUM_WAYS = 4;
    parameter NUM_SETS = 8;
    parameter RRPV_BITS = 2;
    parameter SET_INDEX_WIDTH = $clog2(NUM_SETS);
    
    logic clk, rst, valid, hit, miss;
    logic [SET_INDEX_WIDTH-1:0] set_index;
    logic [3:0] access_way;
    logic [3:0] victim_way;
    logic victim_ready;
    logic [9:0] psel_counter;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // DUT instantiation
    drrip_cache #(
        .NUM_WAYS(NUM_WAYS),
        .NUM_SETS(NUM_SETS),
        .RRPV_BITS(RRPV_BITS),
        .SET_INDEX_WIDTH(SET_INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .set_index(set_index),
        .access_way(access_way),
        .hit(hit),
        .miss(miss),
        .victim_way(victim_way),
        .victim_ready(victim_ready),
        .psel_counter(psel_counter)
    );
    
    // Task to clear all input signals
    task clear_inputs();
        valid = 0;
        hit = 0;
        miss = 0;
        set_index = 0;
        access_way = 0;
    endtask
    
    // Task to simulate a cache miss
    task simulate_miss(input [SET_INDEX_WIDTH-1:0] set_idx, input [3:0] way);
        $display("\nTime %0t: Starting miss simulation on set %0d", $time, set_idx);
        valid = 1;
        set_index = set_idx;
        hit = 0;
        miss = 1;
        access_way = way;
        
        // Wait for victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Miss completed - Victim way %0d selected for set %0d", $time, victim_way, set_index);
        
        // Hold signals for one more cycle to ensure proper insertion
        @(posedge clk);
        clear_inputs();
        @(posedge clk);
    endtask
    
    // Task to simulate a cache hit
    task simulate_hit(input [SET_INDEX_WIDTH-1:0] set_idx, input [3:0] way);
        $display("\nTime %0t: Starting hit simulation on set %0d way %0d", $time, set_idx, way);
        valid = 1;
        set_index = set_idx;
        hit = 1;
        miss = 0;
        access_way = way;
        
        @(posedge clk);
        clear_inputs();
        @(posedge clk);
    endtask
    
    // Test sequence - MATCHING YOUR ORIGINAL TEST CASES
    initial begin
        clk = 0;
        rst = 1;
        valid = 0;
        set_index = 0;
        access_way = 0;
        hit = 0;
        miss = 0;
        
        #20;
        rst = 0;
        
        // Test 1: Miss on SRRIP leader set (set_index=0)
        $display("Time %0t: Test 1 - Miss on SRRIP leader set (set_index=0)", $time);
        valid = 1;
        set_index = 7'd0; // SRRIP leader
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
        // Wait for victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
        // Clear signals
        valid = 0;
        hit = 0;
        miss = 0;
        #10;
        
       // Test 1a: Miss on SRRIP leader set (set_index=0)
        $display("Time %0t: Test 1.a - Miss on SRRIP leader set (set_index=0)", $time);
        valid = 1;
        set_index = 7'd0; // SRRIP leader
        hit = 0;
        miss = 1;
        access_way = 4'd3;
        #10;
        
        // Wait for victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
        // Clear signals
        valid = 0;
        hit = 0;
        miss = 0;
        #10;
      
        // Test 2: Hit on follower set (set_index=5)
        $display("Time %0t: Test 2 - Hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd1;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
        
        // Test 3: Another hit on follower set (set_index=5)
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
      // Test 3: Another hit on follower set (set_index=5)
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
      // Test 3: Another hit on follower set (set_index=5)
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
      $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd2;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
      
      // Test 3: Another hit on follower set (set_index=5)
        $display("Time %0t: Test 3 - Another hit on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 1;
        miss = 0;
        access_way = 4'd0;
        #10;
        
        // Clear signals
        valid = 0;
        hit = 0;
        #10;
        
        // Test 4: Miss on follower set (set_index=5)
        $display("Time %0t: Test 4 - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 0;
        miss =1;
        access_way = 4'd0;
        #10;
      
         // Clear signals
        valid = 0;
        hit = 0;
        miss = 0;
        #10;
        
      // Test zz: Miss on follower set (set_index=5)
      $display("Time %0t: Test zz - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
         // Clear signals
        valid = 0;
        hit = 0;
        miss = 0;
        #10;
      
         
      // Test zz: Miss on follower set (set_index=5)
      $display("Time %0t: Test zz - Miss on follower set (set_index=5)", $time);
        valid = 1;
        set_index = 7'd5; // Follower set
        hit = 0;
        miss = 1;
        access_way = 4'd0;
        #10;
        
         // Clear signals
        valid = 0;
        hit = 0;
        miss = 0;
        #10;
      
        // Wait for victim selection to complete
        wait(victim_ready);
        $display("Time %0t: Victim found at way %0d for set %0d", $time, victim_way, set_index);
        
     
      
        
        $display("Test completed");
        
        // Final summary - print victim ways for all sets
        $display("\n=== Final Cache State Summary ===");
        for (int set = 0; set < NUM_SETS; set++) begin
            $display("Set %0d RRPV values:", set);
            for (int way = 0; way < NUM_WAYS; way++) begin
                $display("  Way %0d: RRPV = %0d", way, dut.rrpv_table[set][way]);
            end
        end
        
        $display("\nFinal PSEL counter: %0d", psel_counter);
        $display("Final BIP counter: %0d", dut.bip_counter);
        
        #100 $finish;
    end
    
    // Monitor important signals
    always @(posedge clk) begin
        if (valid && !rst) begin
            $display("Time %0t: Access - Set=%0d, Way=%0d, Hit=%b, Miss=%b, PSEL=%0d, Policy=%s", 
                     $time, set_index, access_way, hit, miss, psel_counter,
                     dut.use_srrip_policy ? "SRRIP" : "BIP");
        end
        
        if (victim_ready && !rst) begin
            $display("Time %0t: VICTIM READY - Set %0d, Way %0d, Policy Used: %s", 
                     $time, set_index, victim_way,
                     dut.use_srrip_policy ? "SRRIP" : "BIP");
        end
    end
    
endmodule
