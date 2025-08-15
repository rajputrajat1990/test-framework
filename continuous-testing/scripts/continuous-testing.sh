#!/bin/bash

# Sprint 4: Main Continuous Testing Orchestrator
# Central script for managing the continuous testing workflow

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
CONFIG_FILE="$SCRIPT_DIR/../config/continuous-testing.yaml"
RESULTS_DIR="test-results"
REPORTS_DIR="test-reports"
EXECUTION_MODE="auto"
ENVIRONMENT="dev"
VERBOSE=false
DRY_RUN=false

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
Usage: $0 [COMMAND] [OPTIONS]

Sprint 4 Continuous Testing Orchestrator

Commands:
    run             Execute continuous testing workflow
    analyze         Analyze code changes and suggest tests
    select          Select tests based on changes
    execute         Execute specific test suite
    report          Generate test reports
    status          Show current test status
    help            Show this help message

Options:
    -c, --config FILE       Configuration file (default: $CONFIG_FILE)
    -e, --environment ENV   Target environment: dev, staging, production (default: $ENVIRONMENT)
    -m, --mode MODE         Execution mode: auto, manual, ci (default: $EXECUTION_MODE)
    -r, --results-dir DIR   Results directory (default: $RESULTS_DIR)
    -R, --reports-dir DIR   Reports directory (default: $REPORTS_DIR)
    --dry-run               Show what would be executed without running
    -v, --verbose           Enable verbose output

Examples:
    $0 run --environment staging --verbose
    $0 analyze --mode manual
    $0 execute --suite flink_transformation_tests
    $0 report --format html
    $0 status
EOF
}

# Parse command line arguments
parse_args() {
    local command=""
    
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    # Extract command
    command="$1"
    shift
    
    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -m|--mode)
                EXECUTION_MODE="$2"
                shift 2
                ;;
            -r|--results-dir)
                RESULTS_DIR="$2"
                shift 2
                ;;
            -R|--reports-dir)
                REPORTS_DIR="$2"
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
            --*)
                # Pass through additional options to subcommands
                break
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        "run")
            cmd_run "$@"
            ;;
        "analyze")
            cmd_analyze "$@"
            ;;
        "select")
            cmd_select "$@"
            ;;
        "execute")
            cmd_execute "$@"
            ;;
        "report")
            cmd_report "$@"
            ;;
        "status")
            cmd_status "$@"
            ;;
        "help")
            usage
            exit 0
            ;;
        *)
            echo "Unknown command: $command" >&2
            usage >&2
            exit 1
            ;;
    esac
}

# Log message based on verbose flag
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$BLUE" "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Check if configuration file exists
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_color "$RED" "❌ Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    log "Using configuration: $CONFIG_FILE"
}

# Validate environment
validate_environment() {
    local valid_envs=("dev" "staging" "production")
    local env_valid=false
    
    for env in "${valid_envs[@]}"; do
        if [[ "$ENVIRONMENT" == "$env" ]]; then
            env_valid=true
            break
        fi
    done
    
    if [[ "$env_valid" != "true" ]]; then
        print_color "$RED" "❌ Invalid environment: $ENVIRONMENT"
        print_color "$YELLOW" "Valid environments: ${valid_envs[*]}"
        exit 1
    fi
    
    log "Target environment: $ENVIRONMENT"
}

# Setup directories
setup_directories() {
    log "Setting up directories"
    
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$RESULTS_DIR/logs"
    mkdir -p "$RESULTS_DIR/artifacts"
}

# Command: Run full continuous testing workflow
cmd_run() {
    print_color "$GREEN" "🚀 Starting continuous testing workflow..."
    
    local start_time=$(date +%s)
    local overall_exit_code=0
    
    # Step 1: Analyze changes
    print_color "$YELLOW" "📊 Step 1: Analyzing code changes..."
    if ! cmd_analyze --internal; then
        print_color "$RED" "❌ Change analysis failed"
        overall_exit_code=1
    fi
    
    # Step 2: Select tests
    print_color "$YELLOW" "🎯 Step 2: Selecting tests..."
    if ! cmd_select --internal; then
        print_color "$RED" "❌ Test selection failed"
        overall_exit_code=1
    fi
    
    # Step 3: Execute tests (if not dry run)
    if [[ "$DRY_RUN" != "true" && $overall_exit_code -eq 0 ]]; then
        print_color "$YELLOW" "⚡ Step 3: Executing tests..."
        
        # Read execution plan and run tests
        local execution_plan="test-execution-plan.json"
        if [[ -f "$execution_plan" ]]; then
            local selected_suites
            selected_suites=$(jq -r '.execution_plan.selected_suites[]' "$execution_plan" 2>/dev/null || echo "")
            
            if [[ -n "$selected_suites" ]]; then
                while IFS= read -r suite; do
                    if [[ -n "$suite" ]]; then
                        print_color "$BLUE" "▶️ Executing suite: $suite"
                        if ! cmd_execute --suite "$suite" --internal; then
                            print_color "$RED" "❌ Suite execution failed: $suite"
                            overall_exit_code=1
                        fi
                    fi
                done <<< "$selected_suites"
            else
                print_color "$YELLOW" "⏭️ No tests selected for execution"
            fi
        else
            print_color "$YELLOW" "⚠️ No execution plan found, skipping test execution"
        fi
    fi
    
    # Step 4: Generate reports
    print_color "$YELLOW" "📋 Step 4: Generating reports..."
    if ! cmd_report --internal; then
        print_color "$RED" "❌ Report generation failed"
        # Don't fail the overall workflow for report generation issues
    fi
    
    # Calculate total time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Final status
    if [[ $overall_exit_code -eq 0 ]]; then
        print_color "$GREEN" "✅ Continuous testing workflow completed successfully!"
    else
        print_color "$RED" "❌ Continuous testing workflow completed with errors!"
    fi
    
    print_color "$BLUE" "Total execution time: ${duration}s"
    print_color "$BLUE" "Results: $RESULTS_DIR"
    print_color "$BLUE" "Reports: $REPORTS_DIR"
    
    return $overall_exit_code
}

# Command: Analyze changes
cmd_analyze() {
    local internal=false
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --internal)
                internal=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [[ "$internal" != "true" ]]; then
        print_color "$GREEN" "📊 Starting change analysis..."
    fi
    
    local analyze_script="$SCRIPT_DIR/analyze-code-changes.sh"
    local args=(
        "--config" "$CONFIG_FILE"
        "--environment" "$ENVIRONMENT"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        args+=("--dry-run")
    fi
    
    # Add any additional arguments
    args+=("$@")
    
    if [[ -f "$analyze_script" ]]; then
        "$analyze_script" "${args[@]}"
    else
        print_color "$RED" "❌ Analysis script not found: $analyze_script"
        return 1
    fi
}

# Command: Select tests
cmd_select() {
    local internal=false
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --internal)
                internal=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [[ "$internal" != "true" ]]; then
        print_color "$GREEN" "🎯 Starting test selection..."
    fi
    
    local select_script="$SCRIPT_DIR/select-tests.sh"
    local args=(
        "--config" "$CONFIG_FILE"
        "--environment" "$ENVIRONMENT"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        args+=("--dry-run")
    fi
    
    # Add any additional arguments
    args+=("$@")
    
    if [[ -f "$select_script" ]]; then
        "$select_script" "${args[@]}"
    else
        print_color "$RED" "❌ Selection script not found: $select_script"
        return 1
    fi
}

# Command: Execute test suite
cmd_execute() {
    local internal=false
    local suite=""
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --internal)
                internal=true
                shift
                ;;
            --suite)
                suite="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [[ "$internal" != "true" ]]; then
        print_color "$GREEN" "⚡ Starting test execution..."
    fi
    
    local execute_script="$SCRIPT_DIR/execute-test-suite.sh"
    local args=(
        "--results-dir" "$RESULTS_DIR"
    )
    
    if [[ -n "$suite" ]]; then
        args+=("--suite" "$suite")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        args+=("--dry-run")
    fi
    
    # Add any additional arguments
    args+=("$@")
    
    if [[ -f "$execute_script" ]]; then
        "$execute_script" "${args[@]}"
    else
        print_color "$RED" "❌ Execution script not found: $execute_script"
        return 1
    fi
}

# Command: Generate reports
cmd_report() {
    local internal=false
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --internal)
                internal=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [[ "$internal" != "true" ]]; then
        print_color "$GREEN" "📋 Starting report generation..."
    fi
    
    local report_script="$SCRIPT_DIR/generate-test-report.sh"
    local args=(
        "--results-dir" "$RESULTS_DIR"
        "--output-dir" "$REPORTS_DIR"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi
    
    # Add any additional arguments
    args+=("$@")
    
    if [[ -f "$report_script" ]]; then
        "$report_script" "${args[@]}"
    else
        print_color "$RED" "❌ Report script not found: $report_script"
        return 1
    fi
}

# Command: Show status
cmd_status() {
    print_color "$GREEN" "📊 Sprint 4 Continuous Testing Status"
    echo
    
    # Show configuration
    print_color "$BLUE" "Configuration:"
    print_color "$NC" "  Config file: $CONFIG_FILE"
    print_color "$NC" "  Environment: $ENVIRONMENT"
    print_color "$NC" "  Execution mode: $EXECUTION_MODE"
    print_color "$NC" "  Results directory: $RESULTS_DIR"
    print_color "$NC" "  Reports directory: $REPORTS_DIR"
    echo
    
    # Show recent execution results
    if [[ -d "$RESULTS_DIR" ]]; then
        print_color "$BLUE" "Recent Test Results:"
        local result_count=0
        
        for result_file in "$RESULTS_DIR"/*-results.json; do
            if [[ -f "$result_file" ]]; then
                local suite_name
                suite_name=$(jq -r '.test_suite // "unknown"' "$result_file" 2>/dev/null || echo "unknown")
                local suite_status
                suite_status=$(jq -r '.status // "UNKNOWN"' "$result_file" 2>/dev/null || echo "UNKNOWN")
                local suite_timestamp
                suite_timestamp=$(jq -r '.timestamp // "N/A"' "$result_file" 2>/dev/null || echo "N/A")
                
                local status_color="$GREEN"
                local status_emoji="✅"
                
                if [[ "$suite_status" != "PASSED" ]]; then
                    status_color="$RED"
                    status_emoji="❌"
                fi
                
                print_color "$status_color" "  $status_emoji $suite_name ($suite_status) - $suite_timestamp"
                result_count=$((result_count + 1))
            fi
        done
        
        if [[ $result_count -eq 0 ]]; then
            print_color "$YELLOW" "  No test results found"
        fi
    else
        print_color "$YELLOW" "  Results directory not found"
    fi
    
    echo
    
    # Show available reports
    if [[ -d "$REPORTS_DIR" ]]; then
        print_color "$BLUE" "Available Reports:"
        local report_count=0
        
        for report_file in "$REPORTS_DIR"/*.html "$REPORTS_DIR"/*.json "$REPORTS_DIR"/*.xml "$REPORTS_DIR"/*.md; do
            if [[ -f "$report_file" ]]; then
                local report_name
                report_name=$(basename "$report_file")
                local report_size
                report_size=$(du -h "$report_file" | cut -f1)
                local report_date
                report_date=$(stat -c %y "$report_file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
                
                print_color "$NC" "  📄 $report_name ($report_size, $report_date)"
                report_count=$((report_count + 1))
            fi
        done
        
        if [[ $report_count -eq 0 ]]; then
            print_color "$YELLOW" "  No reports found"
        fi
    else
        print_color "$YELLOW" "  Reports directory not found"
    fi
    
    echo
    
    # Show Git status if available
    if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
        print_color "$BLUE" "Git Status:"
        local git_branch
        git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local git_commit
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local git_changes
        git_changes=$(git status --porcelain 2>/dev/null | wc -l || echo "0")
        
        print_color "$NC" "  Branch: $git_branch"
        print_color "$NC" "  Commit: $git_commit"
        print_color "$NC" "  Uncommitted changes: $git_changes"
    fi
}

# Main execution function
main() {
    # Validate prerequisites
    check_config
    validate_environment
    
    # Setup directories
    setup_directories
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Parse arguments and execute command
    parse_args "$@"
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_color "$RED" "❌ Missing required dependencies: ${missing_deps[*]}"
        print_color "$YELLOW" "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Run dependency check and main function
check_dependencies
main "$@"
