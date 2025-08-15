#!/bin/bash

# Sprint 4: Analyze Code Changes Script
# Analyzes code changes to determine which tests should be run

set -euo pipefail

# Default values
OUTPUT_FILE="change-analysis.json"
VERBOSE=false
BASE_REF="main"
HEAD_REF="HEAD"
ANALYSIS_MODE="smart"

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

Analyze code changes to determine which tests should be run.

Options:
    -o, --output FILE       Output file for analysis results (default: $OUTPUT_FILE)
    -b, --base REF         Base reference for comparison (default: $BASE_REF)
    -h, --head REF         Head reference for comparison (default: $HEAD_REF)
    -m, --mode MODE        Analysis mode: smart|full|minimal (default: $ANALYSIS_MODE)
    -v, --verbose          Enable verbose output
    --help                 Show this help message

Examples:
    $0 --output analysis.json --base main --head feature-branch
    $0 --mode full --verbose
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -b|--base)
                BASE_REF="$2"
                shift 2
                ;;
            -h|--head)
                HEAD_REF="$2"
                shift 2
                ;;
            -m|--mode)
                ANALYSIS_MODE="$2"
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

# Get changed files between two git references
get_changed_files() {
    local base_ref=$1
    local head_ref=$2
    
    log "Getting changed files between $base_ref and $head_ref"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_color "$RED" "Error: Not in a git repository"
        exit 1
    fi
    
    # Get the list of changed files
    local changed_files
    if [[ "$base_ref" == "$head_ref" ]]; then
        # Compare with previous commit if base and head are the same
        changed_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
    else
        # Compare between different references
        changed_files=$(git diff --name-only "$base_ref"..."$head_ref" 2>/dev/null || echo "")
    fi
    
    echo "$changed_files"
}

# Analyze file changes and categorize them
analyze_file_changes() {
    local changed_files="$1"
    
    log "Analyzing file changes"
    
    # Initialize counters
    local terraform_files=0
    local flink_sql_files=0
    local script_files=0
    local config_files=0
    local test_files=0
    local doc_files=0
    local ci_files=0
    
    # Initialize arrays for different file types
    local terraform_changes=()
    local flink_changes=()
    local script_changes=()
    local config_changes=()
    local test_changes=()
    local ci_changes=()
    
    # Process each changed file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        log "Analyzing file: $file"
        
        case "$file" in
            terraform/modules/flink-*)
                terraform_files=$((terraform_files + 1))
                terraform_changes+=("$file")
                ;;
            terraform/modules/compute-pool/*)
                terraform_files=$((terraform_files + 1))
                terraform_changes+=("$file")
                ;;
            terraform/modules/flink-testing/*)
                terraform_files=$((terraform_files + 1))
                terraform_changes+=("$file")
                ;;
            terraform/modules/*)
                terraform_files=$((terraform_files + 1))
                terraform_changes+=("$file")
                ;;
            terraform/tests/*)
                test_files=$((test_files + 1))
                test_changes+=("$file")
                ;;
            flink/sql/*)
                flink_sql_files=$((flink_sql_files + 1))
                flink_changes+=("$file")
                ;;
            scripts/*)
                script_files=$((script_files + 1))
                script_changes+=("$file")
                ;;
            continuous-testing/*)
                script_files=$((script_files + 1))
                script_changes+=("$file")
                ;;
            config/*)
                config_files=$((config_files + 1))
                config_changes+=("$file")
                ;;
            .gitlab-ci.yml)
                ci_files=$((ci_files + 1))
                ci_changes+=("$file")
                ;;
            *.md|docs/*)
                doc_files=$((doc_files + 1))
                ;;
        esac
    done <<< "$changed_files"
    
    # Create analysis result
    cat > /tmp/file_analysis.json << EOF
{
    "file_counts": {
        "terraform": $terraform_files,
        "flink_sql": $flink_sql_files,
        "scripts": $script_files,
        "config": $config_files,
        "tests": $test_files,
        "docs": $doc_files,
        "ci": $ci_files
    },
    "changed_files": {
        "terraform": $(printf '%s\n' "${terraform_changes[@]}" | jq -R . | jq -s .),
        "flink": $(printf '%s\n' "${flink_changes[@]}" | jq -R . | jq -s .),
        "scripts": $(printf '%s\n' "${script_changes[@]}" | jq -R . | jq -s .),
        "config": $(printf '%s\n' "${config_changes[@]}" | jq -R . | jq -s .),
        "tests": $(printf '%s\n' "${test_changes[@]}" | jq -R . | jq -s .),
        "ci": $(printf '%s\n' "${ci_changes[@]}" | jq -R . | jq -s .)
    }
}
EOF
}

# Determine impact level based on changes
determine_impact_level() {
    local file_analysis="$1"
    
    log "Determining impact level"
    
    local terraform_count flink_count ci_count
    terraform_count=$(echo "$file_analysis" | jq -r '.file_counts.terraform')
    flink_count=$(echo "$file_analysis" | jq -r '.file_counts.flink_sql')
    ci_count=$(echo "$file_analysis" | jq -r '.file_counts.ci')
    
    local impact_level="low"
    local impact_score=0
    
    # Calculate impact score
    impact_score=$((impact_score + terraform_count * 10))
    impact_score=$((impact_score + flink_count * 15))
    impact_score=$((impact_score + ci_count * 20))
    
    # Determine impact level
    if [[ $impact_score -ge 30 ]]; then
        impact_level="high"
    elif [[ $impact_score -ge 15 ]]; then
        impact_level="medium"
    else
        impact_level="low"
    fi
    
    log "Impact score: $impact_score, Impact level: $impact_level"
    
    echo "{\"impact_level\": \"$impact_level\", \"impact_score\": $impact_score}"
}

# Map changes to affected test categories
map_to_test_categories() {
    local file_analysis="$1"
    
    log "Mapping changes to test categories"
    
    local test_categories=()
    
    # Check Terraform changes
    local terraform_files
    terraform_files=$(echo "$file_analysis" | jq -r '.changed_files.terraform[]?' 2>/dev/null || true)
    
    if [[ -n "$terraform_files" ]]; then
        if echo "$terraform_files" | grep -q "flink"; then
            test_categories+=("flink_transformation_tests")
            test_categories+=("streaming_tests")
            test_categories+=("performance_validation_tests")
        fi
        
        if echo "$terraform_files" | grep -q "compute-pool"; then
            test_categories+=("flink_compute_pool_tests")
            test_categories+=("resource_allocation_tests")
        fi
        
        if echo "$terraform_files" | grep -q -E "(connector|smt)"; then
            test_categories+=("connector_tests")
            test_categories+=("smt_tests")
        fi
        
        if echo "$terraform_files" | grep -q "rbac"; then
            test_categories+=("rbac_tests")
            test_categories+=("security_validation")
        fi
        
        if echo "$terraform_files" | grep -q "schema"; then
            test_categories+=("schema_tests")
            test_categories+=("data_format_validation")
        fi
        
        # Always include basic validation for Terraform changes
        test_categories+=("terraform_validation")
        test_categories+=("basic_validation")
    fi
    
    # Check Flink SQL changes
    local flink_files
    flink_files=$(echo "$file_analysis" | jq -r '.changed_files.flink[]?' 2>/dev/null || true)
    
    if [[ -n "$flink_files" ]]; then
        test_categories+=("transformation_accuracy_tests")
        test_categories+=("sql_validation_tests")
        test_categories+=("flink_transformation_tests")
        
        if echo "$flink_files" | grep -q "transformation"; then
            test_categories+=("data_validation_tests")
        fi
        
        if echo "$flink_files" | grep -q "test"; then
            test_categories+=("validation_query_tests")
        fi
    fi
    
    # Check CI/CD changes
    local ci_files
    ci_files=$(echo "$file_analysis" | jq -r '.changed_files.ci[]?' 2>/dev/null || true)
    
    if [[ -n "$ci_files" ]]; then
        test_categories+=("pipeline_tests")
        test_categories+=("ci_cd_validation")
        test_categories+=("integration_tests")
    fi
    
    # Remove duplicates and convert to JSON array
    local unique_categories
    unique_categories=$(printf '%s\n' "${test_categories[@]}" | sort -u | jq -R . | jq -s .)
    
    echo "$unique_categories"
}

# Generate test execution recommendations
generate_recommendations() {
    local file_analysis="$1"
    local impact_info="$2"
    local test_categories="$3"
    
    log "Generating test execution recommendations"
    
    local impact_level
    impact_level=$(echo "$impact_info" | jq -r '.impact_level')
    
    local execution_mode="smart"
    local parallel_limit=5
    local timeout="45m"
    
    # Adjust recommendations based on impact level
    case "$impact_level" in
        "high")
            execution_mode="comprehensive"
            parallel_limit=3
            timeout="90m"
            ;;
        "medium")
            execution_mode="smart"
            parallel_limit=5
            timeout="60m"
            ;;
        "low")
            execution_mode="minimal"
            parallel_limit=8
            timeout="30m"
            ;;
    esac
    
    # Override based on analysis mode
    case "$ANALYSIS_MODE" in
        "full")
            execution_mode="comprehensive"
            parallel_limit=2
            timeout="120m"
            ;;
        "minimal")
            execution_mode="minimal"
            parallel_limit=10
            timeout="20m"
            ;;
    esac
    
    cat << EOF
{
    "execution_mode": "$execution_mode",
    "parallel_limit": $parallel_limit,
    "timeout": "$timeout",
    "recommendations": {
        "skip_non_critical": $([ "$impact_level" = "low" ] && echo "true" || echo "false"),
        "enable_performance_tests": $([ "$impact_level" != "low" ] && echo "true" || echo "false"),
        "require_manual_approval": $([ "$impact_level" = "high" ] && echo "true" || echo "false")
    }
}
EOF
}

# Main analysis function
main() {
    parse_args "$@"
    
    print_color "$GREEN" "🔍 Starting code change analysis..."
    print_color "$BLUE" "Base reference: $BASE_REF"
    print_color "$BLUE" "Head reference: $HEAD_REF"
    print_color "$BLUE" "Analysis mode: $ANALYSIS_MODE"
    print_color "$BLUE" "Output file: $OUTPUT_FILE"
    
    # Get changed files
    local changed_files
    changed_files=$(get_changed_files "$BASE_REF" "$HEAD_REF")
    
    if [[ -z "$changed_files" ]]; then
        print_color "$YELLOW" "⚠️  No changed files detected"
        # Create minimal analysis for no changes
        cat > "$OUTPUT_FILE" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "base_ref": "$BASE_REF",
    "head_ref": "$HEAD_REF",
    "analysis_mode": "$ANALYSIS_MODE",
    "changed_files_count": 0,
    "file_analysis": {
        "file_counts": {"terraform": 0, "flink_sql": 0, "scripts": 0, "config": 0, "tests": 0, "docs": 0, "ci": 0},
        "changed_files": {"terraform": [], "flink": [], "scripts": [], "config": [], "tests": [], "ci": []}
    },
    "impact_analysis": {"impact_level": "none", "impact_score": 0},
    "test_categories": [],
    "recommendations": {
        "execution_mode": "skip",
        "parallel_limit": 1,
        "timeout": "5m",
        "recommendations": {
            "skip_non_critical": true,
            "enable_performance_tests": false,
            "require_manual_approval": false
        }
    }
}
EOF
        print_color "$GREEN" "✅ Analysis complete (no changes detected)"
        exit 0
    fi
    
    local changed_count
    changed_count=$(echo "$changed_files" | wc -l)
    print_color "$BLUE" "Changed files count: $changed_count"
    
    # Analyze file changes
    analyze_file_changes "$changed_files"
    local file_analysis
    file_analysis=$(cat /tmp/file_analysis.json)
    
    # Determine impact
    local impact_info
    impact_info=$(determine_impact_level "$file_analysis")
    
    # Map to test categories
    local test_categories
    test_categories=$(map_to_test_categories "$file_analysis")
    
    # Generate recommendations
    local recommendations
    recommendations=$(generate_recommendations "$file_analysis" "$impact_info" "$test_categories")
    
    # Create final analysis output
    cat > "$OUTPUT_FILE" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "base_ref": "$BASE_REF",
    "head_ref": "$HEAD_REF",
    "analysis_mode": "$ANALYSIS_MODE",
    "changed_files_count": $changed_count,
    "changed_files": $(echo "$changed_files" | jq -R . | jq -s .),
    "file_analysis": $file_analysis,
    "impact_analysis": $impact_info,
    "test_categories": $test_categories,
    "recommendations": $recommendations
}
EOF
    
    # Clean up temporary files
    rm -f /tmp/file_analysis.json
    
    # Print summary
    local impact_level
    impact_level=$(echo "$impact_info" | jq -r '.impact_level')
    local test_count
    test_count=$(echo "$test_categories" | jq '. | length')
    
    print_color "$GREEN" "✅ Analysis complete!"
    print_color "$BLUE" "   Impact level: $impact_level"
    print_color "$BLUE" "   Test categories: $test_count"
    print_color "$BLUE" "   Output saved to: $OUTPUT_FILE"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$YELLOW" "📊 Analysis Summary:"
        jq -C . "$OUTPUT_FILE"
    fi
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
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
