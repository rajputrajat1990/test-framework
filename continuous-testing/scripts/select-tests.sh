#!/bin/bash

# Sprint 4: Select Tests Script
# Smart test selection based on change analysis and configuration

set -euo pipefail

# Default values
CHANGE_ANALYSIS_FILE="change-analysis.json"
TEST_SELECTION_CONFIG="continuous-testing/config/test-selection.yaml"
OUTPUT_FILE="test-execution-plan.json"
MODE="smart"
BRANCH_NAME="${CI_COMMIT_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')}"
VERBOSE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

Select tests to run based on code change analysis.

Options:
    -i, --input FILE       Change analysis input file (default: $CHANGE_ANALYSIS_FILE)
    -c, --config FILE      Test selection configuration file (default: $TEST_SELECTION_CONFIG)
    -o, --output FILE      Output file for test execution plan (default: $OUTPUT_FILE)
    -m, --mode MODE        Selection mode: smart|full|minimal|targeted (default: $MODE)
    -b, --branch BRANCH    Branch name for branch-specific configuration (default: auto-detect)
    -v, --verbose          Enable verbose output
    --help                 Show this help message

Examples:
    $0 --input analysis.json --mode smart
    $0 --mode full --verbose
    $0 --branch feature/new-flink-job --mode targeted
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                CHANGE_ANALYSIS_FILE="$2"
                shift 2
                ;;
            -c|--config)
                TEST_SELECTION_CONFIG="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -b|--branch)
                BRANCH_NAME="$2"
                shift 2
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
}

# Log message based on verbose flag
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$BLUE" "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Check if required files exist
check_required_files() {
    if [[ ! -f "$CHANGE_ANALYSIS_FILE" ]]; then
        print_color "$RED" "❌ Change analysis file not found: $CHANGE_ANALYSIS_FILE"
        exit 1
    fi
    
    if [[ ! -f "$TEST_SELECTION_CONFIG" ]]; then
        print_color "$RED" "❌ Test selection config file not found: $TEST_SELECTION_CONFIG"
        exit 1
    fi
}

# Load configuration for the current branch
load_branch_config() {
    local branch_name="$1"
    
    log "Loading configuration for branch: $branch_name"
    
    # Determine branch pattern
    local branch_pattern="feature/*"  # default
    
    if [[ "$branch_name" =~ ^main$ ]]; then
        branch_pattern="main"
    elif [[ "$branch_name" =~ ^develop$ ]]; then
        branch_pattern="develop"
    elif [[ "$branch_name" =~ ^release/ ]]; then
        branch_pattern="release/*"
    elif [[ "$branch_name" =~ ^hotfix/ ]]; then
        branch_pattern="hotfix/*"
    elif [[ "$branch_name" =~ ^feature/ ]]; then
        branch_pattern="feature/*"
    fi
    
    log "Branch pattern: $branch_pattern"
    
    # Extract branch configuration using yq (if available) or default values
    if command -v yq >/dev/null 2>&1; then
        local config
        config=$(yq eval ".branch_configs.\"$branch_pattern\" // .branch_configs.\"feature/*\"" "$TEST_SELECTION_CONFIG")
        echo "$config"
    else
        # Fallback configuration in JSON format
        case "$branch_pattern" in
            "main")
                echo '{"test_selection_mode": "comprehensive", "required_coverage": 90, "allow_test_skipping": false, "max_execution_time": "90m"}'
                ;;
            "develop")
                echo '{"test_selection_mode": "smart", "required_coverage": 80, "allow_test_skipping": true, "max_execution_time": "60m"}'
                ;;
            "hotfix/*")
                echo '{"test_selection_mode": "targeted", "required_coverage": 95, "allow_test_skipping": false, "max_execution_time": "30m"}'
                ;;
            "release/*")
                echo '{"test_selection_mode": "comprehensive", "required_coverage": 95, "allow_test_skipping": false, "max_execution_time": "120m"}'
                ;;
            *)
                echo '{"test_selection_mode": "smart", "required_coverage": 70, "allow_test_skipping": true, "max_execution_time": "45m"}'
                ;;
        esac
    fi
}

# Get test categories based on change analysis
get_affected_test_categories() {
    local change_analysis="$1"
    
    log "Extracting affected test categories from change analysis"
    
    # Extract test categories from change analysis
    local test_categories
    test_categories=$(echo "$change_analysis" | jq -r '.test_categories[]?' 2>/dev/null || echo "")
    
    if [[ -z "$test_categories" ]]; then
        # Fallback: analyze file changes to determine categories
        local terraform_files flink_files ci_files
        terraform_files=$(echo "$change_analysis" | jq -r '.file_analysis.file_counts.terraform // 0')
        flink_files=$(echo "$change_analysis" | jq -r '.file_analysis.file_counts.flink_sql // 0')
        ci_files=$(echo "$change_analysis" | jq -r '.file_analysis.file_counts.ci // 0')
        
        local categories=()
        
        if [[ "$terraform_files" -gt 0 ]]; then
            categories+=("terraform_validation" "basic_validation")
        fi
        
        if [[ "$flink_files" -gt 0 ]]; then
            categories+=("flink_transformation_tests" "streaming_tests")
        fi
        
        if [[ "$ci_files" -gt 0 ]]; then
            categories+=("pipeline_tests" "ci_cd_validation")
        fi
        
        # If no specific changes, include basic validation
        if [[ ${#categories[@]} -eq 0 ]]; then
            categories+=("basic_validation")
        fi
        
        printf '%s\n' "${categories[@]}"
    else
        echo "$test_categories"
    fi
}

# Calculate test priorities based on multiple factors
calculate_test_priorities() {
    local test_categories="$1"
    local change_analysis="$2"
    
    log "Calculating test priorities"
    
    local impact_level
    impact_level=$(echo "$change_analysis" | jq -r '.impact_analysis.impact_level')
    
    # Define priority mappings
    declare -A priority_map=(
        ["basic_validation"]=100
        ["terraform_validation"]=95
        ["security_tests"]=90
        ["flink_transformation_tests"]=85
        ["streaming_tests"]=80
        ["performance_tests"]=75
        ["connector_tests"]=70
        ["smt_tests"]=65
        ["schema_tests"]=60
        ["e2e_basic_flow"]=55
        ["integration_tests"]=50
        ["script_validation_tests"]=40
        ["documentation_tests"]=30
    )
    
    # Adjust priorities based on impact level
    local impact_multiplier=1.0
    case "$impact_level" in
        "high") impact_multiplier=1.2 ;;
        "medium") impact_multiplier=1.0 ;;
        "low") impact_multiplier=0.8 ;;
    esac
    
    # Create priority list
    local priority_list=()
    while IFS= read -r category; do
        [[ -z "$category" ]] && continue
        
        local base_priority=${priority_map[$category]:-50}
        local adjusted_priority
        adjusted_priority=$(printf "%.0f" $(echo "$base_priority * $impact_multiplier" | bc -l 2>/dev/null || echo "$base_priority"))
        
        priority_list+=("{\"test_category\": \"$category\", \"priority\": $adjusted_priority}")
    done <<< "$test_categories"
    
    # Convert to JSON array and sort by priority
    printf '%s\n' "${priority_list[@]}" | jq -s '. | sort_by(-.priority)'
}

# Build test dependency graph
build_dependency_graph() {
    local prioritized_tests="$1"
    
    log "Building test dependency graph"
    
    # Define test dependencies (simplified version)
    declare -A dependencies=(
        ["basic_validation"]=""
        ["terraform_validation"]="basic_validation"
        ["compute_pool_tests"]="terraform_validation"
        ["topic_tests"]="terraform_validation"
        ["flink_job_creation_tests"]="compute_pool_tests,topic_tests"
        ["flink_transformation_tests"]="flink_job_creation_tests"
        ["streaming_tests"]="flink_transformation_tests"
        ["performance_validation_tests"]="streaming_tests"
        ["connector_tests"]="topic_tests,rbac_tests"
        ["smt_tests"]="connector_tests"
        ["schema_tests"]="topic_tests"
        ["rbac_tests"]="terraform_validation"
        ["e2e_basic_flow"]="connector_tests,topic_tests"
        ["e2e_flink_flow"]="flink_transformation_tests,performance_validation_tests"
    )
    
    # Create dependency-aware execution plan
    local execution_groups=()
    local current_group=()
    local processed_tests=()
    
    # Process tests in priority order, grouping by dependencies
    while IFS= read -r test_info; do
        [[ -z "$test_info" ]] && continue
        
        local test_name
        test_name=$(echo "$test_info" | jq -r '.test_category')
        
        local deps="${dependencies[$test_name]:-}"
        local can_run_now=true
        
        # Check if dependencies are satisfied
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep in "${dep_array[@]}"; do
                if [[ ! " ${processed_tests[*]} " =~ " ${dep} " ]]; then
                    can_run_now=false
                    break
                fi
            done
        fi
        
        if [[ "$can_run_now" == "true" ]]; then
            current_group+=("$test_info")
            processed_tests+=("$test_name")
        else
            # Start new group if current group is not empty
            if [[ ${#current_group[@]} -gt 0 ]]; then
                execution_groups+=($(printf '%s\n' "${current_group[@]}" | jq -s .))
                current_group=("$test_info")
                processed_tests+=("$test_name")
            fi
        fi
    done <<< "$(echo "$prioritized_tests" | jq -r '.[] | @json')"
    
    # Add remaining tests in current group
    if [[ ${#current_group[@]} -gt 0 ]]; then
        execution_groups+=($(printf '%s\n' "${current_group[@]}" | jq -s .))
    fi
    
    # Convert to final format
    printf '%s\n' "${execution_groups[@]}" | jq -s .
}

# Apply test selection mode logic
apply_selection_mode() {
    local test_plan="$1"
    local mode="$2"
    local branch_config="$3"
    
    log "Applying test selection mode: $mode"
    
    case "$mode" in
        "full"|"comprehensive")
            # Include all tests
            echo "$test_plan"
            ;;
        "minimal")
            # Only critical tests
            echo "$test_plan" | jq '[.[] | map(select(.priority >= 90))]'
            ;;
        "targeted")
            # High and medium priority tests
            echo "$test_plan" | jq '[.[] | map(select(.priority >= 70))]'
            ;;
        "smart")
            # Apply smart filtering based on branch config
            local allow_skipping
            allow_skipping=$(echo "$branch_config" | jq -r '.allow_test_skipping // false')
            
            if [[ "$allow_skipping" == "true" ]]; then
                # Skip low priority tests
                echo "$test_plan" | jq '[.[] | map(select(.priority >= 50))]'
            else
                # Include all tests
                echo "$test_plan"
            fi
            ;;
        *)
            # Default to smart mode
            apply_selection_mode "$test_plan" "smart" "$branch_config"
            ;;
    esac
}

# Estimate execution time for test plan
estimate_execution_time() {
    local test_plan="$1"
    
    log "Estimating execution time for test plan"
    
    # Define estimated durations (in minutes)
    declare -A durations=(
        ["basic_validation"]=2
        ["terraform_validation"]=3
        ["compute_pool_tests"]=8
        ["topic_tests"]=5
        ["flink_job_creation_tests"]=10
        ["flink_transformation_tests"]=15
        ["streaming_tests"]=12
        ["performance_validation_tests"]=20
        ["connector_tests"]=8
        ["smt_tests"]=10
        ["schema_tests"]=6
        ["rbac_tests"]=7
        ["e2e_basic_flow"]=15
        ["e2e_flink_flow"]=25
        ["integration_tests"]=10
        ["script_validation_tests"]=5
    )
    
    local total_time=0
    local max_parallel_time=0
    
    # Calculate total and parallel execution time
    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        
        local group_max_time=0
        local group_total_time=0
        
        while IFS= read -r test_info; do
            [[ -z "$test_info" ]] && continue
            
            local test_name
            test_name=$(echo "$test_info" | jq -r '.test_category')
            local test_duration=${durations[$test_name]:-5}
            
            group_total_time=$((group_total_time + test_duration))
            if [[ $test_duration -gt $group_max_time ]]; then
                group_max_time=$test_duration
            fi
        done <<< "$(echo "$group" | jq -r '.[] | @json')"
        
        total_time=$((total_time + group_total_time))
        max_parallel_time=$((max_parallel_time + group_max_time))
    done <<< "$(echo "$test_plan" | jq -r '.[] | @json')"
    
    echo "{\"total_sequential_time\": ${total_time}, \"estimated_parallel_time\": ${max_parallel_time}}"
}

# Generate final test execution plan
generate_execution_plan() {
    local test_plan="$1"
    local branch_config="$2"
    local change_analysis="$3"
    local time_estimate="$4"
    
    log "Generating final test execution plan"
    
    # Extract configuration values
    local max_execution_time
    max_execution_time=$(echo "$branch_config" | jq -r '.max_execution_time // "60m"')
    
    local required_coverage
    required_coverage=$(echo "$branch_config" | jq -r '.required_coverage // 80')
    
    # Get total test count
    local total_tests
    total_tests=$(echo "$test_plan" | jq '[.[] | length] | add')
    
    # Create execution plan
    cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "mode": "$MODE",
    "branch": "$BRANCH_NAME",
    "total_tests": $total_tests,
    "execution_groups": $test_plan,
    "time_estimates": $time_estimate,
    "configuration": {
        "max_execution_time": "$max_execution_time",
        "required_coverage": $required_coverage,
        "parallel_limit": $(echo "$branch_config" | jq -r '.parallel_limit // 5'),
        "allow_test_skipping": $(echo "$branch_config" | jq -r '.allow_test_skipping // false')
    },
    "change_summary": {
        "impact_level": $(echo "$change_analysis" | jq -r '.impact_analysis.impact_level'),
        "changed_files_count": $(echo "$change_analysis" | jq -r '.changed_files_count'),
        "affected_categories": $(echo "$change_analysis" | jq -r '.test_categories | length')
    },
    "execution_strategy": {
        "parallel_execution": true,
        "fail_fast": $([ "$BRANCH_NAME" = "main" ] && echo "false" || echo "true"),
        "retry_failed": true,
        "max_retries": 2
    }
}
EOF
}

# Main function
main() {
    parse_args "$@"
    
    print_color "$GREEN" "🎯 Starting test selection..."
    print_color "$BLUE" "Selection mode: $MODE"
    print_color "$BLUE" "Branch: $BRANCH_NAME"
    print_color "$BLUE" "Input file: $CHANGE_ANALYSIS_FILE"
    print_color "$BLUE" "Output file: $OUTPUT_FILE"
    
    # Check required files
    check_required_files
    
    # Load change analysis
    local change_analysis
    change_analysis=$(cat "$CHANGE_ANALYSIS_FILE")
    
    # Load branch configuration
    local branch_config
    branch_config=$(load_branch_config "$BRANCH_NAME")
    
    # Get affected test categories
    local test_categories
    test_categories=$(get_affected_test_categories "$change_analysis")
    
    if [[ -z "$test_categories" ]]; then
        print_color "$YELLOW" "⚠️  No test categories identified"
        # Create minimal execution plan
        cat > "$OUTPUT_FILE" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "mode": "$MODE",
    "branch": "$BRANCH_NAME",
    "total_tests": 0,
    "execution_groups": [],
    "time_estimates": {"total_sequential_time": 0, "estimated_parallel_time": 0},
    "configuration": $(echo "$branch_config"),
    "change_summary": {
        "impact_level": "none",
        "changed_files_count": 0,
        "affected_categories": 0
    },
    "execution_strategy": {
        "parallel_execution": false,
        "fail_fast": false,
        "retry_failed": false,
        "max_retries": 0
    }
}
EOF
        print_color "$GREEN" "✅ Test selection complete (no tests needed)"
        exit 0
    fi
    
    # Calculate test priorities
    local prioritized_tests
    prioritized_tests=$(calculate_test_priorities "$test_categories" "$change_analysis")
    
    # Build dependency graph and execution plan
    local test_plan
    test_plan=$(build_dependency_graph "$prioritized_tests")
    
    # Apply selection mode filtering
    test_plan=$(apply_selection_mode "$test_plan" "$MODE" "$branch_config")
    
    # Estimate execution time
    local time_estimate
    time_estimate=$(estimate_execution_time "$test_plan")
    
    # Generate final execution plan
    local execution_plan
    execution_plan=$(generate_execution_plan "$test_plan" "$branch_config" "$change_analysis" "$time_estimate")
    
    # Save execution plan
    echo "$execution_plan" > "$OUTPUT_FILE"
    
    # Print summary
    local total_tests
    total_tests=$(echo "$execution_plan" | jq -r '.total_tests')
    
    local estimated_time
    estimated_time=$(echo "$time_estimate" | jq -r '.estimated_parallel_time')
    
    print_color "$GREEN" "✅ Test selection complete!"
    print_color "$BLUE" "   Selected tests: $total_tests"
    print_color "$BLUE" "   Estimated time: ${estimated_time}m"
    print_color "$BLUE" "   Output saved to: $OUTPUT_FILE"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$YELLOW" "📋 Execution Plan:"
        jq -C . "$OUTPUT_FILE"
    fi
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_color "$RED" "❌ Missing required dependencies: ${missing_deps[*]}"
        print_color "$YELLOW" "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Run dependency check and main function
check_dependencies
main "$@"
