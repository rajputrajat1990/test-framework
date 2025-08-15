#!/bin/bash

# Sprint 4: Execute Test Suite Script
# Executes a specific test suite based on the execution plan

set -euo pipefail

# Default values
TEST_SUITE=""
EXECUTION_PLAN_FILE="test-execution-plan.json"
RESULTS_DIR="test-results"
VERBOSE=false
DRY_RUN=false
PARALLEL=false
MAX_RETRIES=2
TIMEOUT="45m"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Execute a specific test suite based on the execution plan.

Options:
    -s, --suite SUITE       Test suite to execute (required)
    -p, --plan FILE         Test execution plan file (default: $EXECUTION_PLAN_FILE)
    -r, --results-dir DIR   Results directory (default: $RESULTS_DIR)
    -t, --timeout DURATION  Test timeout duration (default: $TIMEOUT)
    --parallel              Enable parallel execution within test group
    --max-retries COUNT     Maximum retry attempts (default: $MAX_RETRIES)
    --dry-run               Show what would be executed without running
    -v, --verbose           Enable verbose output
    --help                  Show this help message

Test Suites:
    terraform_validation         - Validate Terraform configurations
    flink_transformation_tests   - Flink SQL transformation tests
    streaming_tests             - Streaming data flow tests
    performance_validation_tests - Performance and load tests
    connector_tests             - Connector functionality tests
    e2e_basic_flow             - End-to-end basic data flow
    e2e_flink_flow            - End-to-end Flink transformation flow

Examples:
    $0 --suite terraform_validation --verbose
    $0 --suite flink_transformation_tests --parallel --timeout 60m
    $0 --suite e2e_flink_flow --dry-run
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--suite)
                TEST_SUITE="$2"
                shift 2
                ;;
            -p|--plan)
                EXECUTION_PLAN_FILE="$2"
                shift 2
                ;;
            -r|--results-dir)
                RESULTS_DIR="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$TEST_SUITE" ]]; then
        echo "Error: Test suite is required" >&2
        usage >&2
        exit 1
    fi
}

# Log message based on verbose flag
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$BLUE" "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Create results directory if it doesn't exist
setup_results_dir() {
    log "Setting up results directory: $RESULTS_DIR"
    
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR/logs"
    mkdir -p "$RESULTS_DIR/artifacts"
    mkdir -p "$RESULTS_DIR/junit"
}

# Execute Terraform validation tests
execute_terraform_validation() {
    local results_file="$RESULTS_DIR/terraform-validation-results.json"
    local log_file="$RESULTS_DIR/logs/terraform-validation.log"
    
    print_color "$YELLOW" "🔧 Executing Terraform validation tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute terraform validation"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== Terraform Format Check ==="
        if timeout "$TIMEOUT" terraform fmt -check -recursive; then
            echo "✅ Terraform format check passed"
        else
            echo "❌ Terraform format check failed"
            exit_code=1
        fi
        
        echo -e "\n=== Terraform Validation ==="
        if timeout "$TIMEOUT" terraform validate; then
            echo "✅ Terraform validation passed"
        else
            echo "❌ Terraform validation failed"
            exit_code=1
        fi
        
        echo -e "\n=== Terraform Plan ==="
        if timeout "$TIMEOUT" terraform plan -detailed-exitcode; then
            echo "✅ Terraform plan completed successfully"
        else
            local plan_exit=$?
            if [[ $plan_exit -eq 2 ]]; then
                echo "✅ Terraform plan completed with changes"
            else
                echo "❌ Terraform plan failed"
                exit_code=1
            fi
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "terraform_validation",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file"
}
EOF
    
    return $exit_code
}

# Execute Flink transformation tests
execute_flink_transformation_tests() {
    local results_file="$RESULTS_DIR/flink-transformation-results.json"
    local log_file="$RESULTS_DIR/logs/flink-transformation.log"
    
    print_color "$YELLOW" "🌊 Executing Flink transformation tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute Flink transformation tests"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== Flink Streaming Tests ==="
        if timeout "$TIMEOUT" terraform test -filter="*.tftest.hcl" terraform/tests/flink/streaming-tests.tftest.hcl; then
            echo "✅ Flink streaming tests passed"
        else
            echo "❌ Flink streaming tests failed"
            exit_code=1
        fi
        
        echo -e "\n=== Flink Transformation Validation ==="
        if timeout "$TIMEOUT" terraform test -filter="*.tftest.hcl" terraform/tests/flink/transformation-validation.tftest.hcl; then
            echo "✅ Flink transformation validation passed"
        else
            echo "❌ Flink transformation validation failed"
            exit_code=1
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "flink_transformation_tests",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file",
    "test_files": [
        "terraform/tests/flink/streaming-tests.tftest.hcl",
        "terraform/tests/flink/transformation-validation.tftest.hcl"
    ]
}
EOF
    
    return $exit_code
}

# Execute streaming tests
execute_streaming_tests() {
    local results_file="$RESULTS_DIR/streaming-tests-results.json"
    local log_file="$RESULTS_DIR/logs/streaming-tests.log"
    
    print_color "$YELLOW" "🌊 Executing streaming tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute streaming tests"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== Streaming Data Flow Tests ==="
        if timeout "$TIMEOUT" terraform test terraform/tests/flink/streaming-tests.tftest.hcl; then
            echo "✅ Streaming data flow tests passed"
        else
            echo "❌ Streaming data flow tests failed"
            exit_code=1
        fi
        
        echo -e "\n=== Stream Processing Validation ==="
        if [[ -f "scripts/test-stream-processing.sh" ]]; then
            if timeout "$TIMEOUT" bash scripts/test-stream-processing.sh; then
                echo "✅ Stream processing validation passed"
            else
                echo "❌ Stream processing validation failed"
                exit_code=1
            fi
        else
            echo "⚠️ Stream processing validation script not found, skipping"
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "streaming_tests",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file"
}
EOF
    
    return $exit_code
}

# Execute performance validation tests
execute_performance_validation_tests() {
    local results_file="$RESULTS_DIR/performance-validation-results.json"
    local log_file="$RESULTS_DIR/logs/performance-validation.log"
    
    print_color "$YELLOW" "⚡ Executing performance validation tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute performance validation tests"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== Flink Performance Tests ==="
        if timeout "$TIMEOUT" terraform test -var="enable_performance_validation=true" terraform/tests/flink/; then
            echo "✅ Flink performance tests passed"
        else
            echo "❌ Flink performance tests failed"
            exit_code=1
        fi
        
        echo -e "\n=== Performance Benchmarking ==="
        if [[ -f "scripts/run-performance-benchmark.sh" ]]; then
            if timeout "$TIMEOUT" bash scripts/run-performance-benchmark.sh; then
                echo "✅ Performance benchmarking completed"
            else
                echo "❌ Performance benchmarking failed"
                exit_code=1
            fi
        else
            echo "⚠️ Performance benchmark script not found, skipping"
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "performance_validation_tests",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file"
}
EOF
    
    return $exit_code
}

# Execute connector tests
execute_connector_tests() {
    local results_file="$RESULTS_DIR/connector-tests-results.json"
    local log_file="$RESULTS_DIR/logs/connector-tests.log"
    
    print_color "$YELLOW" "🔌 Executing connector tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute connector tests"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== SMT Connector Tests ==="
        if timeout "$TIMEOUT" terraform test terraform/tests/sprint3/smt-transformation.tftest.hcl; then
            echo "✅ SMT connector tests passed"
        else
            echo "❌ SMT connector tests failed"
            exit_code=1
        fi
        
        echo -e "\n=== Schema Registry Tests ==="
        if timeout "$TIMEOUT" terraform test terraform/tests/sprint3/data-format-validation.tftest.hcl; then
            echo "✅ Schema registry tests passed"
        else
            echo "❌ Schema registry tests failed"
            exit_code=1
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "connector_tests",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file"
}
EOF
    
    return $exit_code
}

# Execute end-to-end Flink flow tests
execute_e2e_flink_flow() {
    local results_file="$RESULTS_DIR/e2e-flink-flow-results.json"
    local log_file="$RESULTS_DIR/logs/e2e-flink-flow.log"
    
    print_color "$YELLOW" "🔄 Executing end-to-end Flink flow tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$BLUE" "[DRY RUN] Would execute end-to-end Flink flow tests"
        return 0
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    {
        echo "=== Complete Flink Transformation Chain ==="
        if timeout "$TIMEOUT" terraform test -var="test_scenarios=[\"user_enrichment\",\"event_aggregation\",\"windowed_analytics\"]" terraform/tests/flink/; then
            echo "✅ Complete Flink transformation chain passed"
        else
            echo "❌ Complete Flink transformation chain failed"
            exit_code=1
        fi
        
        echo -e "\n=== Data Accuracy Validation ==="
        if [[ -f "scripts/validate-flink-accuracy.sh" ]]; then
            if timeout "$TIMEOUT" bash scripts/validate-flink-accuracy.sh; then
                echo "✅ Data accuracy validation passed"
            else
                echo "❌ Data accuracy validation failed"
                exit_code=1
            fi
        else
            echo "⚠️ Data accuracy validation script not found, skipping"
        fi
        
    } 2>&1 | tee "$log_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create results JSON
    cat > "$results_file" << EOF
{
    "test_suite": "e2e_flink_flow",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "log_file": "$log_file"
}
EOF
    
    return $exit_code
}

# Execute test suite with retry logic
execute_with_retry() {
    local test_function="$1"
    local attempt=1
    local exit_code=1
    
    while [[ $attempt -le $((MAX_RETRIES + 1)) ]]; do
        if [[ $attempt -gt 1 ]]; then
            print_color "$YELLOW" "🔄 Retry attempt $((attempt - 1))/$MAX_RETRIES"
            sleep 10  # Brief delay between retries
        fi
        
        if $test_function; then
            exit_code=0
            break
        fi
        
        attempt=$((attempt + 1))
    done
    
    return $exit_code
}

# Generate JUnit XML report
generate_junit_report() {
    local test_suite="$1"
    local exit_code="$2"
    local duration="$3"
    
    local junit_file="$RESULTS_DIR/junit/junit-$test_suite.xml"
    local test_status="$([ $exit_code -eq 0 ] && echo "success" || echo "failure")"
    local failure_message=""
    
    if [[ $exit_code -ne 0 ]]; then
        failure_message='<failure message="Test suite failed" type="TestFailure">Test suite execution failed</failure>'
    fi
    
    cat > "$junit_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="$test_suite" tests="1" failures="$([ $exit_code -eq 0 ] && echo "0" || echo "1")" time="$duration">
    <testcase name="$test_suite" classname="TestSuite" time="$duration">
        $failure_message
    </testcase>
</testsuite>
EOF
    
    log "JUnit report generated: $junit_file"
}

# Main execution function
main() {
    parse_args "$@"
    
    print_color "$GREEN" "🚀 Starting test suite execution..."
    print_color "$BLUE" "Test suite: $TEST_SUITE"
    print_color "$BLUE" "Timeout: $TIMEOUT"
    print_color "$BLUE" "Max retries: $MAX_RETRIES"
    print_color "$BLUE" "Results directory: $RESULTS_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_color "$YELLOW" "🏃 Running in DRY RUN mode"
    fi
    
    # Setup results directory
    setup_results_dir
    
    # Record start time
    local overall_start_time=$(date +%s)
    local exit_code=0
    
    # Execute the specified test suite
    case "$TEST_SUITE" in
        "terraform_validation")
            execute_with_retry execute_terraform_validation
            exit_code=$?
            ;;
        "flink_transformation_tests")
            execute_with_retry execute_flink_transformation_tests
            exit_code=$?
            ;;
        "streaming_tests")
            execute_with_retry execute_streaming_tests
            exit_code=$?
            ;;
        "performance_validation_tests")
            execute_with_retry execute_performance_validation_tests
            exit_code=$?
            ;;
        "connector_tests")
            execute_with_retry execute_connector_tests
            exit_code=$?
            ;;
        "e2e_flink_flow")
            execute_with_retry execute_e2e_flink_flow
            exit_code=$?
            ;;
        *)
            print_color "$RED" "❌ Unknown test suite: $TEST_SUITE"
            print_color "$YELLOW" "Available test suites:"
            print_color "$YELLOW" "  - terraform_validation"
            print_color "$YELLOW" "  - flink_transformation_tests"
            print_color "$YELLOW" "  - streaming_tests"
            print_color "$YELLOW" "  - performance_validation_tests"
            print_color "$YELLOW" "  - connector_tests"
            print_color "$YELLOW" "  - e2e_flink_flow"
            exit 1
            ;;
    esac
    
    # Calculate total duration
    local overall_end_time=$(date +%s)
    local total_duration=$((overall_end_time - overall_start_time))
    
    # Generate JUnit report
    generate_junit_report "$TEST_SUITE" "$exit_code" "$total_duration"
    
    # Print final status
    if [[ $exit_code -eq 0 ]]; then
        print_color "$GREEN" "✅ Test suite '$TEST_SUITE' completed successfully!"
    else
        print_color "$RED" "❌ Test suite '$TEST_SUITE' failed!"
    fi
    
    print_color "$BLUE" "Total execution time: ${total_duration}s"
    print_color "$BLUE" "Results saved in: $RESULTS_DIR"
    
    exit $exit_code
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v terraform >/dev/null 2>&1; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v timeout >/dev/null 2>&1; then
        missing_deps+=("timeout")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_color "$RED" "❌ Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Run dependency check and main function
check_dependencies
main "$@"
