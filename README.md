# DRRIP Cache Implementation

## Overview

This repository contains a Verilog implementation of the **Dynamic Re-Reference Interval Prediction (DRRIP)** cache replacement policy. DRRIP is an advanced cache management technique that combines **Static Re-Reference Interval Prediction (SRRIP)** and **Bimodal Insertion Policy (BIP)** with dynamic policy selection through **Set Dueling Monitors (SDMs)**.

## Features

- **Hybrid Replacement Policy**: Combines SRRIP and BIP for optimal cache performance
- **Set Dueling**: Automatically selects the best policy based on runtime performance
- **Configurable Parameters**: Adjustable cache size, associativity, and RRPV bits
- **Comprehensive Testbench**: Extensive testing with various cache access patterns
- **Debug Output**: Detailed logging for policy decisions and state transitions

## Architecture

### Core Components

1. **RRPV Table**: Stores Re-Reference Prediction Values for each cache block
2. **PSEL Counter**: Policy Selection counter for set dueling decisions
3. **BIP Counter**: Bimodal Insertion Policy counter for epsilon probability
4. **Victim Selection FSM**: State machine for managing victim selection process
5. **Set Assignment Logic**: Determines leader/follower sets for policy evaluation

### Cache Organization

- **Sets**: Configurable number of cache sets (default: 128)
- **Ways**: Configurable associativity (default: 16-way)
- **RRPV Bits**: Configurable prediction value width (default: 2 bits)
- **PSEL Bits**: Policy selection counter width (default: 10 bits)

### Policy Selection

The cache automatically selects between SRRIP and BIP using set dueling:

- **SRRIP Leader Sets**: Always use SRRIP policy (sets 0-1)
- **BIP Leader Sets**: Always use BIP policy (sets 2-3)
- **Follower Sets**: Use policy based on PSEL counter threshold

## Implementation Details

### RRPV Values

- **RRPV_MAX (3)**: Distant future re-reference
- **RRPV_LONG (2)**: Long re-reference interval
- **RRPV_NEAR (0)**: Near-immediate re-reference

### Hit Promotion

On cache hits, RRPV values are decremented (but not below 0) to promote frequently accessed blocks.

### Insertion Policy

- **SRRIP**: Always inserts new blocks with `RRPV_LONG`
- **BIP**: Inserts with `RRPV_LONG` (1/32 probability) or `RRPV_MAX` (31/32 probability)

### Victim Selection

1. **Search Phase**: Look for blocks with `RRPV_MAX`
2. **Aging Phase**: If no victim found, increment all RRPVs in the set
3. **Re-search**: Look for victim again after aging

### Set Dueling

The PSEL counter tracks policy performance:
- **SRRIP Leader Miss**: Decrements PSEL (favors SRRIP)
- **BIP Leader Miss**: Increments PSEL (favors BIP)
- **Follower Sets**: Use PSEL threshold to choose policy

## Files

- **`drrip.v`**: Main DRRIP cache implementation
- **`drrip_tb.v`**: Comprehensive testbench with various test scenarios
- **`README.md`**: This documentation file



### Customization

Modify the module parameters to adjust cache characteristics:

```verilog
drrip_cache #(
    .NUM_WAYS(8),        // 8-way associative
    .NUM_SETS(64),       // 64 sets
    .RRPV_BITS(3),       // 3-bit RRPV values
    .PSEL_BITS(12)       // 12-bit PSEL counter
) cache_instance (
    // port connections
);
```

## Test Scenarios

The testbench covers:

1. **SRRIP Leader Misses**: Tests policy selection and PSEL updates
2. **BIP Leader Misses**: Validates BIP policy and PSEL behavior
3. **Follower Set Access**: Tests dynamic policy selection
4. **Hit Promotion**: Verifies RRPV decrement on cache hits
5. **Victim Selection**: Tests aging mechanism and victim finding
6. **Policy Switching**: Demonstrates automatic policy adaptation

## Performance Characteristics

- **Latency**: Single-cycle hit response, multi-cycle miss handling
- **Area**: Minimal overhead for RRPV storage and control logic
- **Power**: Efficient state machine with minimal switching activity
- **Scalability**: Parameterized design supports various cache sizes

## Research Background

DRRIP was introduced in the paper "A Case for MLP-Aware Cache Replacement" and has been shown to provide significant improvements over traditional LRU policies, especially for workloads with mixed access patterns.

## Dependencies

- Verilog-2001 compatible simulator
- No external IP cores required
- Standard synthesis tools support
