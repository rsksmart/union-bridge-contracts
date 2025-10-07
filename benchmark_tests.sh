#!/bin/bash

# Benchmark script to run tests multiple times and collect metrics
# Usage: ./benchmark_tests.sh [number_of_runs]

NUM_RUNS=${1:-100}
OUTPUT_FILE="test_benchmark_$(date +%Y%m%d_%H%M%S).txt"
SUMMARY_FILE="test_summary_$(date +%Y%m%d_%H%M%S).txt"

echo "Running tests $NUM_RUNS times..."
echo "Results will be saved to: $OUTPUT_FILE"
echo "Summary will be saved to: $SUMMARY_FILE"
echo ""

# Initialize arrays to store metrics
declare -a total_times
declare -a cpu_times
declare -a test_counts

# Run tests multiple times
for i in $(seq 1 $NUM_RUNS); do
    echo "Run $i/$NUM_RUNS..."

    # Run the test and capture output
    output=$(bash test.sh 2>&1)

    # Extract the final summary line
    summary=$(echo "$output" | grep "Ran [0-9]* test suites")

    # Extract total time (e.g., "10.98s")
    total_time=$(echo "$summary" | grep -oE '[0-9]+\.[0-9]+s' | head -1 | sed 's/s//')

    # Extract CPU time (e.g., "82.32s CPU time")
    cpu_time=$(echo "$summary" | grep -oE '[0-9]+\.[0-9]+s CPU time' | grep -oE '[0-9]+\.[0-9]+')

    # Extract test count
    test_count=$(echo "$summary" | grep -oE '[0-9]+ total tests' | grep -oE '[0-9]+')

    # Store metrics
    total_times+=($total_time)
    cpu_times+=($cpu_time)
    test_counts+=($test_count)

    # Save full output to file
    echo "=== RUN $i ===" >> "$OUTPUT_FILE"
    echo "$output" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Print summary for this run
    echo "  Total: ${total_time}s, CPU: ${cpu_time}s, Tests: $test_count"
done

echo ""
echo "All runs completed!"
echo ""

# Calculate statistics
calculate_stats() {
    local arr=("$@")
    local sum=0
    local count=${#arr[@]}
    local min=${arr[0]}
    local max=${arr[0]}

    for val in "${arr[@]}"; do
        sum=$(echo "$sum + $val" | bc)
        if (( $(echo "$val < $min" | bc -l) )); then
            min=$val
        fi
        if (( $(echo "$val > $max" | bc -l) )); then
            max=$val
        fi
    done

    local avg=$(echo "scale=2; $sum / $count" | bc)

    # Calculate median (simple sort and pick middle)
    IFS=$'\n' sorted=($(sort -n <<<"${arr[*]}"))
    local median_idx=$((count / 2))
    local median=${sorted[$median_idx]}

    echo "$avg $min $max $median"
}

# Generate summary report
{
    echo "=========================================="
    echo "TEST BENCHMARK SUMMARY"
    echo "=========================================="
    echo "Date: $(date)"
    echo "Number of runs: $NUM_RUNS"
    echo "Total tests per run: ${test_counts[0]}"
    echo ""

    echo "TOTAL TIME (seconds):"
    echo "----------------------------------------"
    stats=($(calculate_stats "${total_times[@]}"))
    echo "  Average: ${stats[0]}s"
    echo "  Minimum: ${stats[1]}s"
    echo "  Maximum: ${stats[2]}s"
    echo "  Median:  ${stats[3]}s"
    echo ""

    echo "CPU TIME (seconds):"
    echo "----------------------------------------"
    stats=($(calculate_stats "${cpu_times[@]}"))
    echo "  Average: ${stats[0]}s"
    echo "  Minimum: ${stats[1]}s"
    echo "  Maximum: ${stats[2]}s"
    echo "  Median:  ${stats[3]}s"
    echo ""

    echo "RAW DATA:"
    echo "----------------------------------------"
    echo "Run | Total Time | CPU Time"
    echo "----+------------+---------"
    for i in $(seq 0 $((NUM_RUNS - 1))); do
        printf "%3d | %10.2fs | %8.2fs\n" $((i+1)) ${total_times[$i]} ${cpu_times[$i]}
    done

} | tee "$SUMMARY_FILE"

echo ""
echo "Benchmark complete!"
echo "Full output: $OUTPUT_FILE"
echo "Summary: $SUMMARY_FILE"
