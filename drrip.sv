/**
 * DRRIP Cache Implementation
 * 
 * This module implements the Dynamic Re-Reference Interval Prediction (DRRIP) cache
 * replacement policy, which combines SRRIP and BIP policies with dynamic selection
 * through Set Dueling Monitors (SDMs).
 * 
 * Key Features:
 * - Hybrid replacement policy (SRRIP + BIP)
 * - Automatic policy selection via set dueling
 * - Configurable cache parameters
 * - Efficient victim selection with aging mechanism
 */

module drrip_cache #(
    parameter NUM_WAYS = 16,           // Number of ways in the cache (associativity)
    parameter NUM_SETS = 128,          // Number of cache sets
    parameter RRPV_BITS = 2,           // Bits for Re-Reference Prediction Value
    parameter SET_INDEX_WIDTH = $clog2(NUM_SETS),  // Width of set index
    parameter PSEL_BITS = 10,          // Bits for Policy Selection counter
    parameter SDM_SETS = 32            // Number of sets for each SDM (Set Dueling Monitor)
)(
    input logic clk,                   // Clock signal
    input logic rst,                   // Reset signal (active high)
    input logic valid,                 // Valid signal for current access
    input logic [SET_INDEX_WIDTH-1:0] set_index,  // Current set being accessed
    input logic [3:0] access_way,      // Way being accessed (hit) or replaced (miss)
    input logic hit,                   // Cache hit signal
    input logic miss,                  // Cache miss signal

    output logic [3:0] victim_way,     // Selected victim way for replacement
    output logic victim_ready,         // Victim selection is complete
    output logic [PSEL_BITS-1:0] psel_counter  // Policy selection counter value
);

    // ============================================================================
    // CONSTANTS AND PARAMETERS
    // ============================================================================
    
    // RRPV (Re-Reference Prediction Value) constants based on paper
    localparam RRPV_MAX = (1 << RRPV_BITS) - 1;           // 3 for 2-bit RRPV (distant future)
    localparam RRPV_LONG = RRPV_MAX - 1;                  // 2 for 2-bit RRPV (long re-reference)
    localparam RRPV_NEAR = 0;                             // 0 (near-immediate re-reference)
    
    // PSEL (Policy Selection) counter constants
    localparam PSEL_MAX = (1 << PSEL_BITS) - 1;          // 1023 for 10-bit counter
    localparam PSEL_MID = PSEL_MAX / 2;                   // 511 (threshold for policy selection)
    
    // BIP (Bimodal Insertion Policy) constants
    localparam BIP_EPSILON = 32;                          // 1/32 probability as mentioned in paper

    // ============================================================================
    // STORAGE ELEMENTS
    // ============================================================================
    
    // RRPV storage for each cache block - indexed by [set][way]
    logic [RRPV_BITS-1:0] rrpv_table [NUM_SETS-1:0][NUM_WAYS-1:0];
    
    // PSEL counter for set dueling - tracks which policy is performing better
    logic [PSEL_BITS-1:0] psel_reg;
    assign psel_counter = psel_reg;
    
    // BIP counter for bimodal insertion - implements epsilon probability (1/32)
    logic [5:0] bip_counter;
    
    // ============================================================================
    // SET DUELING LOGIC
    // ============================================================================
    
    // Set assignment signals for Set Dueling Monitors (SDMs)
    logic is_srrip_leader, is_bip_leader, is_follower;    // Set type identification
    logic use_srrip_policy;                               // Final policy selection
    logic [RRPV_BITS-1:0] old_rrpv;                      // Temporary storage for aging
    
    // ============================================================================
    // VICTIM SELECTION STATE MACHINE
    // ============================================================================
    
    // FSM states for managing victim selection process
    typedef enum logic [2:0] {
        IDLE,           // Waiting for miss request
        SEARCH_VICTIM,  // Looking for victim with RRPV_MAX
        AGE_ALL,        // Aging all blocks when no victim found
        VICTIM_FOUND    // Victim selected and ready
    } victim_state_t;
    
    victim_state_t victim_state, victim_next_state;        // Current and next state
    
    // Internal signals for victim selection - registered to hold search results
    logic victim_found_reg, victim_found_comb;             // Victim found flags
    logic [3:0] selected_victim_way_reg, selected_victim_way_comb;  // Selected victim way
    
    // PSEL update control - prevents multiple updates per miss transaction
    logic psel_updated;

    // ============================================================================
    // SET ASSIGNMENT FOR SET DUELING
    // ============================================================================
    
    // Set assignment logic determines which sets use which policies
    // In a real implementation, this would use a hash function of set_index
    always_comb begin
        // Simple assignment for demonstration - in real implementation would use hash
        is_srrip_leader = (set_index == 0 || set_index == 1);    // Sets 0-1 always use SRRIP
        is_bip_leader = (set_index == 2 || set_index == 3);      // Sets 2-3 always use BIP
        is_follower = (set_index >= 4);                          // Sets 4+ follow PSEL counter
        
        // Policy selection based on set type and PSEL counter
        if (is_srrip_leader)
            use_srrip_policy = 1'b1;                             // SRRIP leader always uses SRRIP
        else if (is_bip_leader)
            use_srrip_policy = 1'b0;                             // BIP leader always uses BIP
        else
            use_srrip_policy = (psel_reg >= PSEL_MID);           // Follower uses PSEL threshold
    end
    
    // ============================================================================
    // PSEL COUNTER UPDATE LOGIC
    // ============================================================================
    
    // PSEL counter tracks policy performance and updates only for leader sets
    always_ff @(posedge clk) begin
        if (rst) begin
            psel_reg <= PSEL_MID;                               // Initialize to middle value
            psel_updated <= 1'b0;                               // Reset update flag
        end else if (valid && miss && !psel_updated) begin      // Only update once per miss transaction
            // SRRIP leader set miss decrements PSEL (favors SRRIP when PSEL is low)
            if (is_srrip_leader && psel_reg > 0) begin
                psel_reg <= psel_reg - 1;
                psel_updated <= 1'b1;                           // Mark as updated
                $display("Time %0t: PSEL decremented to %0d (SRRIP leader miss)", $time, psel_reg - 1);
            end
            // BIP leader set miss increments PSEL (favors BIP when PSEL is high)  
            else if (is_bip_leader && psel_reg < PSEL_MAX) begin
                psel_reg <= psel_reg + 1;
                psel_updated <= 1'b1;                           // Mark as updated
                $display("Time %0t: PSEL incremented to %0d (BIP leader miss)", $time, psel_reg + 1);
            end
        end else if (!valid || !miss) begin
            // Reset the update flag when the miss transaction is complete
            psel_updated <= 1'b0;
        end
    end
    
    // ============================================================================
    // BIP COUNTER FOR EPSILON PROBABILITY
    // ============================================================================
    
    // BIP counter implements the epsilon probability (1/32) for BIP insertion
    always_ff @(posedge clk) begin
        if (rst) begin
            bip_counter <= 0;                                   // Initialize counter
        end else if (valid && miss && !use_srrip_policy && victim_state == VICTIM_FOUND) begin
            // Only update when actually inserting a block using BIP policy
            bip_counter <= (bip_counter + 1) % BIP_EPSILON;    // Wrap around at 32
        end
    end
    
    // ============================================================================
    // RRPV UPDATE LOGIC (HIT PROMOTION AND INSERTION)
    // ============================================================================
    
    // This block handles RRPV updates for hits, misses, and aging
    always_ff @(posedge clk) begin
        if (rst) begin
            // Initialize all RRPV values to distant future (RRPV_MAX)
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    rrpv_table[i][j] <= RRPV_MAX;
                end
            end
        end else if (valid && hit) begin
            // HIT PROMOTION: Decrement RRPV to promote frequently accessed blocks
            // This implements SRRIP-FP (Frequency-based Promotion) from the paper
            if (rrpv_table[set_index][access_way] > 0) begin
                rrpv_table[set_index][access_way] <= rrpv_table[set_index][access_way] - 1;
                $display("Time %0t: Hit on Set %0d Way %0d, RRPV decremented to %0d", $time, set_index, access_way, rrpv_table[set_index][access_way] - 1);
            end else begin
                $display("Time %0t: Hit on Set %0d Way %0d, RRPV already at minimum (0)", $time, set_index, access_way);
            end
        end else if (victim_state == VICTIM_FOUND && miss && valid) begin
            // INSERTION POLICY: Insert new block based on selected policy
            if (use_srrip_policy) begin
                // SRRIP: Always insert with long re-reference interval
                rrpv_table[set_index][selected_victim_way_reg] <= RRPV_LONG;
                $display("Time %0t: SRRIP insertion - Set %0d Way %0d, RRPV set to %0d", $time, set_index, selected_victim_way_reg, RRPV_LONG);
            end else begin
                // BIP: Insert with distant (probability 31/32) or long (probability 1/32)
                if (bip_counter == 0) begin
                    rrpv_table[set_index][selected_victim_way_reg] <= RRPV_LONG;
                    $display("Time %0t: BIP insertion (1/32) - Set %0d Way %0d, RRPV set to %0d", $time, set_index, selected_victim_way_reg, RRPV_LONG);
                end else begin
                    rrpv_table[set_index][selected_victim_way_reg] <= RRPV_MAX;
                    $display("Time %0t: BIP insertion (31/32) - Set %0d Way %0d, RRPV set to %0d", $time, set_index, selected_victim_way_reg, RRPV_MAX);
                end
            end
        end else if (victim_state == AGE_ALL) begin
            // AGING MECHANISM: Increment all RRPVs when no victim is found
            // This ensures eventual victim selection even in pathological cases
            $display("Time %0t: *** AGING START *** for set %0d", $time, set_index);
            $display("Time %0t: Before aging - Set %0d: [%0d,%0d,%0d,%0d]", $time, set_index, 
                     rrpv_table[set_index][0], rrpv_table[set_index][1], 
                     rrpv_table[set_index][2], rrpv_table[set_index][3]);
            for (int i = 0; i < NUM_WAYS; i++) begin
                if (rrpv_table[set_index][i] < RRPV_MAX) begin
                    old_rrpv = rrpv_table[set_index][i];
                    rrpv_table[set_index][i] <= old_rrpv + 1;
                    $display("  Way %0d: RRPV %0d -> %0d", i, old_rrpv, old_rrpv + 1);
                end else begin
                    $display("  Way %0d: RRPV %0d (already at max)", i, rrpv_table[set_index][i]);
                end
            end
        end
    end
    
    // ============================================================================
    // VICTIM SEARCH LOGIC (COMBINATIONAL)
    // ============================================================================
    
    // Combinational logic to find victim blocks with RRPV_MAX
    always_comb begin
        victim_found_comb = 1'b0;                             // Default: no victim found
        selected_victim_way_comb = 4'b0;                      // Default victim way
        
        // Search for first block with RRPV_MAX (distant re-reference)
        // This implements the core victim selection algorithm
        for (int i = 0; i < NUM_WAYS; i++) begin
            if (rrpv_table[set_index][i] == RRPV_MAX && !victim_found_comb) begin
                victim_found_comb = 1'b1;                      // Victim found
                selected_victim_way_comb = i[3:0];             // Record victim way
                break;                                          // Stop at first victim
            end
        end
    end
    
    // ============================================================================
    // VICTIM SEARCH RESULTS REGISTRATION
    // ============================================================================
    
    // Register the victim search results at the appropriate time
    always_ff @(posedge clk) begin
        if (rst) begin
            victim_found_reg <= 1'b0;                          // Reset flags
            selected_victim_way_reg <= 4'b0;                   // Reset victim way
        end else if (victim_state == SEARCH_VICTIM) begin
            // Capture search results when in SEARCH_VICTIM state
            victim_found_reg <= victim_found_comb;
            selected_victim_way_reg <= selected_victim_way_comb;
            $display("Time %0t: VICTIM SEARCH in set %0d - Current RRPVs: [%0d,%0d,%0d,%0d], victim_found=%b, selected_way=%0d", 
                     $time, set_index, 
                     rrpv_table[set_index][0], rrpv_table[set_index][1], 
                     rrpv_table[set_index][2], rrpv_table[set_index][3],
                     victim_found_comb, selected_victim_way_comb);
        end else if (victim_state == AGE_ALL) begin
            // After aging, capture the updated search results
            // This ensures we get the correct victim after aging
            victim_found_reg <= victim_found_comb;
            selected_victim_way_reg <= selected_victim_way_comb;
            $display("Time %0t: POST-AGING SEARCH in set %0d - Updated RRPVs: [%0d,%0d,%0d,%0d], victim_found=%b, selected_way=%0d", 
                     $time, set_index, 
                     rrpv_table[set_index][0], rrpv_table[set_index][1], 
                     rrpv_table[set_index][2], rrpv_table[set_index][3],
                     victim_found_comb, selected_victim_way_comb);
        end
    end
    
    // ============================================================================
    // VICTIM SELECTION STATE MACHINE
    // ============================================================================
    
    // State machine for managing the victim selection process
    always_ff @(posedge clk) begin
        if (rst) begin
            victim_state <= IDLE;                              // Reset to idle state
        end else begin
            victim_state <= victim_next_state;                 // Update state
            $display("Time %0t: FSM transition: %s -> %s", $time, victim_state.name(), victim_next_state.name());
        end
    end
    
    // ============================================================================
    // FSM NEXT STATE LOGIC
    // ============================================================================
    
    // Combinational logic for state transitions
    always_comb begin
        case (victim_state)
            IDLE: begin
                // Wait for miss request to start victim selection
                if (valid && miss)
                    victim_next_state = SEARCH_VICTIM;
                else
                    victim_next_state = IDLE;
            end
            
            SEARCH_VICTIM: begin
                // Search for victim - if none found, need to age all blocks
                if (!victim_found_comb)
                    victim_next_state = AGE_ALL;
                else
                    victim_next_state = VICTIM_FOUND;
            end
            
            AGE_ALL: begin
                // After aging, search again for victim
                // This ensures we find a victim after aging
                victim_next_state = SEARCH_VICTIM;
            end
            
            VICTIM_FOUND: begin
                // Victim found, return to idle for next request
                victim_next_state = IDLE;
            end
            
            default: victim_next_state = IDLE;                 // Safety default
        endcase
    end
    
    // ============================================================================
    // OUTPUT ASSIGNMENTS
    // ============================================================================
    
    // Output logic for victim way and ready signal
    always_ff @(posedge clk) begin
        if (rst) begin
            victim_way <= 4'b0;                               // Reset victim way
            victim_ready <= 1'b0;                             // Reset ready signal
        end else begin
            case (victim_state)
                VICTIM_FOUND: begin
                    // Output selected victim when ready
                    victim_way <= selected_victim_way_reg;
                    victim_ready <= 1'b1;
                    $display("Time %0t: VICTIM READY - Way %0d selected for set %0d", $time, selected_victim_way_reg, set_index);
                end
                default: begin
                    victim_ready <= 1'b0;                     // Not ready in other states
                end
            endcase
        end
    end

endmodule
