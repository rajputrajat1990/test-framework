#!/bin/bash

# Sprint 2: Test Resource Cleanup Script
# Cleans up test resources created during CI/CD pipeline execution

set -e
set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLEANUP_LOGS_DIR="${PROJECT_ROOT}/cleanup-logs"

# Default values
PIPELINE_ID=""
FORCE_CLEANUP=false
DRY_RUN=false
CLEANUP_TIMEOUT=1800  # 30 minutes
VERBOSE=false

# Resource tracking
declare -a CLEANUP_TASKS
declare -a FAILED_CLEANUPS

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Clean up test resources created during CI/CD pipeline execution

OPTIONS:
    --pipeline-id ID       Clean up resources for specific pipeline ID
    --force               Force cleanup even if resources are in use
    --dry-run             Show what would be cleaned up without doing it
    --timeout SECONDS     Cleanup timeout in seconds (default: 1800)
    --verbose             Enable verbose logging
    --help                Show this help message

EXAMPLES:
    # Clean up resources for specific pipeline
    $0 --pipeline-id=12345

    # Dry run to see what would be cleaned up
    $0 --dry-run --pipeline-id=12345

    # Force cleanup with verbose logging
    $0 --force --verbose --pipeline-id=12345

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    [[ "$VERBOSE" == "true" ]] && echo "$1" >> "$CLEANUP_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    [[ "$VERBOSE" == "true" ]] && echo "SUCCESS: $1" >> "$CLEANUP_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "WARNING: $1" >> "$CLEANUP_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "ERROR: $1" >> "$CLEANUP_LOG_FILE"
}

# Setup cleanup environment
setup_cleanup_environment() {
    log_info "Setting up cleanup environment..."
    
    mkdir -p "$CLEANUP_LOGS_DIR"
    
    # Create cleanup log file
    export CLEANUP_LOG_FILE="${CLEANUP_LOGS_DIR}/cleanup-${PIPELINE_ID:-$(date +%s)}-$(date +%Y%m%d-%H%M%S).log"
    touch "$CLEANUP_LOG_FILE"
    
    log_info "Cleanup log file: $CLEANUP_LOG_FILE"
    log_info "Pipeline ID: ${PIPELINE_ID:-'auto-detected'}"
    log_info "Force cleanup: $FORCE_CLEANUP"
    log_info "Dry run: $DRY_RUN"
}

# Validate environment variables
validate_environment() {
    log_info "Validating environment for cleanup..."
    
    local required_vars=(
        "CONFLUENT_CLOUD_API_KEY"
        "CONFLUENT_CLOUD_API_SECRET"
        "CONFLUENT_ENVIRONMENT_ID"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables for cleanup:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        return 1
    fi
    
    log_success "Environment variables validated for cleanup"
    return 0
}

# Detect test resources to clean up
detect_test_resources() {
    log_info "Detecting test resources to clean up..."
    
    local resource_patterns=()
    
    if [[ -n "$PIPELINE_ID" ]]; then
        # Look for resources created by specific pipeline
        resource_patterns+=(
            "ci-${PIPELINE_ID}-*"
            "integration-*-${PIPELINE_ID}"
            "e2e-*-${PIPELINE_ID}"
            "test-*-${PIPELINE_ID}"
        )
    else
        # Look for general test resource patterns
        resource_patterns+=(
            "ci-*"
            "integration-test-*"
            "e2e-*"
            "test-*"
        )
    fi
    
    # Find Terraform state directories
    find_terraform_test_states "${resource_patterns[@]}"
    
    # Find test data and temporary files
    find_test_artifacts "${resource_patterns[@]}"
    
    log_info "Found ${#CLEANUP_TASKS[@]} cleanup tasks"
}

# Find Terraform test state directories
find_terraform_test_states() {
    local patterns=("$@")
    
    log_info "Searching for Terraform test states..."
    
    # Look in the tests directory for integration test states
    local integration_tests_dir="${PROJECT_ROOT}/terraform/tests/integration"
    if [[ -d "$integration_tests_dir" ]]; then
        for test_dir in "$integration_tests_dir"/*; do
            if [[ -d "$test_dir" && -f "$test_dir/terraform.tfstate" ]]; then
                local dir_name=$(basename "$test_dir")
                
                # Check if this test directory matches our patterns
                for pattern in "${patterns[@]}"; do
                    if [[ "$dir_name" == *"${pattern%\*}"* || "$pattern" == "*" ]]; then
                        CLEANUP_TASKS+=("terraform_state:$test_dir")
                        log_info "Found Terraform state to cleanup: $test_dir"
                        break
                    fi
                done
            fi
        done
    fi
    
    # Look for E2E test states
    local e2e_tests_dir="${PROJECT_ROOT}/terraform/tests/e2e"
    if [[ -d "$e2e_tests_dir" ]]; then
        for test_dir in "$e2e_tests_dir"/*; do
            if [[ -d "$test_dir" && -f "$test_dir/terraform.tfstate" ]]; then
                local dir_name=$(basename "$test_dir")
                
                for pattern in "${patterns[@]}"; do
                    if [[ "$dir_name" == *"${pattern%\*}"* || "$pattern" == "*" ]]; then
                        CLEANUP_TASKS+=("terraform_state:$test_dir")
                        log_info "Found E2E test state to cleanup: $test_dir"
                        break
                    fi
                done
            fi
        done
    fi
}

# Find test artifacts and temporary files
find_test_artifacts() {
    local patterns=("$@")
    
    log_info "Searching for test artifacts..."
    
    # Find test data files
    if [[ -d "${PROJECT_ROOT}/test-data" ]]; then
        for data_file in "${PROJECT_ROOT}/test-data"/*; do
            if [[ -f "$data_file" ]]; then
                local file_name=$(basename "$data_file")
                
                for pattern in "${patterns[@]}"; do
                    if [[ "$file_name" == *"${pattern%\*}"* || "$pattern" == "*" ]]; then
                        CLEANUP_TASKS+=("test_artifact:$data_file")
                        log_info "Found test artifact to cleanup: $data_file"
                        break
                    fi
                done
            fi
        done
    fi
    
    # Find log files
    if [[ -d "${PROJECT_ROOT}/logs" ]]; then
        for log_file in "${PROJECT_ROOT}/logs"/*; do
            if [[ -f "$log_file" ]]; then
                local file_name=$(basename "$log_file")
                
                # Clean up old log files (older than 7 days) or pipeline-specific logs
                if [[ -n "$PIPELINE_ID" && "$file_name" == *"$PIPELINE_ID"* ]]; then
                    CLEANUP_TASKS+=("log_file:$log_file")
                    log_info "Found pipeline log to cleanup: $log_file"
                elif [[ $(find "$log_file" -mtime +7 2>/dev/null | wc -l) -gt 0 ]]; then
                    CLEANUP_TASKS+=("log_file:$log_file")
                    log_info "Found old log file to cleanup: $log_file"
                fi
            fi
        done
    fi
    
    # Find test result files
    if [[ -d "${PROJECT_ROOT}/test-results" ]]; then
        for result_file in "${PROJECT_ROOT}/test-results"/*; do
            if [[ -f "$result_file" ]]; then
                local file_name=$(basename "$result_file")
                
                for pattern in "${patterns[@]}"; do
                    if [[ "$file_name" == *"${pattern%\*}"* || "$pattern" == "*" ]]; then
                        CLEANUP_TASKS+=("test_result:$result_file")
                        log_info "Found test result to cleanup: $result_file"
                        break
                    fi
                done
            fi
        done
    fi
}

# Execute cleanup tasks
execute_cleanup() {
    log_info "Executing cleanup tasks..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No actual cleanup will be performed"
        
        for task in "${CLEANUP_TASKS[@]}"; do
            local task_type="${task%:*}"
            local task_path="${task#*:}"
            
            log_info "Would cleanup $task_type: $task_path"
        done
        
        return 0
    fi
    
    local successful_cleanups=0
    local failed_cleanups=0
    
    for task in "${CLEANUP_TASKS[@]}"; do
        local task_type="${task%:*}"
        local task_path="${task#*:}"
        
        log_info "Cleaning up $task_type: $task_path"
        
        if execute_single_cleanup "$task_type" "$task_path"; then
            ((successful_cleanups++))
            log_success "Cleaned up $task_type: $task_path"
        else
            ((failed_cleanups++))
            FAILED_CLEANUPS+=("$task")
            log_error "Failed to cleanup $task_type: $task_path"
        fi
    done
    
    log_info "Cleanup summary: $successful_cleanups successful, $failed_cleanups failed"
    
    if [[ $failed_cleanups -gt 0 ]]; then
        log_warning "Some cleanup tasks failed. See log for details."
        return 1
    else
        log_success "All cleanup tasks completed successfully"
        return 0
    fi
}

# Execute a single cleanup task
execute_single_cleanup() {
    local task_type="$1"
    local task_path="$2"
    
    case "$task_type" in
        "terraform_state")
            cleanup_terraform_state "$task_path"
            ;;
        "test_artifact")
            cleanup_test_artifact "$task_path"
            ;;
        "log_file")
            cleanup_log_file "$task_path"
            ;;
        "test_result")
            cleanup_test_result "$task_path"
            ;;
        *)
            log_error "Unknown cleanup task type: $task_type"
            return 1
            ;;
    esac
}

# Cleanup Terraform state and associated resources
cleanup_terraform_state() {
    local state_dir="$1"
    
    log_info "Cleaning up Terraform state: $state_dir"
    
    cd "$state_dir"
    
    # Check if state file exists and has resources
    if [[ ! -f "terraform.tfstate" ]]; then
        log_warning "No terraform.tfstate file found in $state_dir"
        return 0
    fi
    
    # Check if there are resources to destroy
    local resource_count
    resource_count=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources | length' 2>/dev/null || echo "0")
    
    if [[ "$resource_count" == "0" ]]; then
        log_info "No resources found in state, removing state files only"
        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
        rm -rf .terraform/
        return 0
    fi
    
    # Initialize Terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform for cleanup..."
        if ! terraform init -backend=false >> "$CLEANUP_LOG_FILE" 2>&1; then
            log_error "Failed to initialize Terraform for cleanup"
            return 1
        fi
    fi
    
    # Destroy resources
    log_info "Destroying $resource_count resources..."
    
    local destroy_command="terraform destroy -auto-approve"
    
    # Add environment-specific variables if available
    if [[ -f "${PROJECT_ROOT}/config/environments/dev.yaml" ]]; then
        destroy_command="$destroy_command -var-file=${PROJECT_ROOT}/config/environments/dev.yaml"
    fi
    
    if timeout "$CLEANUP_TIMEOUT" bash -c "$destroy_command >> \"$CLEANUP_LOG_FILE\" 2>&1"; then
        log_success "Successfully destroyed resources in $state_dir"
        
        # Clean up state files
        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
        rm -rf .terraform/
        
        return 0
    else
        log_error "Failed to destroy resources in $state_dir"
        
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_warning "Force cleanup enabled, removing state files anyway"
            rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
            rm -rf .terraform/
            return 0
        fi
        
        return 1
    fi
}

# Cleanup test artifacts
cleanup_test_artifact() {
    local artifact_path="$1"
    
    if [[ -f "$artifact_path" ]]; then
        if rm "$artifact_path" 2>> "$CLEANUP_LOG_FILE"; then
            return 0
        else
            log_error "Failed to remove test artifact: $artifact_path"
            return 1
        fi
    else
        log_warning "Test artifact not found: $artifact_path"
        return 0
    fi
}

# Cleanup log files
cleanup_log_file() {
    local log_file="$1"
    
    # Don't delete the current cleanup log file
    if [[ "$log_file" == "$CLEANUP_LOG_FILE" ]]; then
        log_info "Skipping current cleanup log file"
        return 0
    fi
    
    if [[ -f "$log_file" ]]; then
        if rm "$log_file" 2>> "$CLEANUP_LOG_FILE"; then
            return 0
        else
            log_error "Failed to remove log file: $log_file"
            return 1
        fi
    else
        log_warning "Log file not found: $log_file"
        return 0
    fi
}

# Cleanup test result files
cleanup_test_result() {
    local result_file="$1"
    
    if [[ -f "$result_file" ]]; then
        if rm "$result_file" 2>> "$CLEANUP_LOG_FILE"; then
            return 0
        else
            log_error "Failed to remove test result file: $result_file"
            return 1
        fi
    else
        log_warning "Test result file not found: $result_file"
        return 0
    fi
}

# Emergency cleanup - force remove all test-related directories
emergency_cleanup() {
    log_warning "Performing emergency cleanup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would perform emergency cleanup"
        return 0
    fi
    
    local cleanup_dirs=(
        "${PROJECT_ROOT}/terraform/tests/integration"
        "${PROJECT_ROOT}/terraform/tests/e2e"
        "${PROJECT_ROOT}/test-data"
        "${PROJECT_ROOT}/test-results"
    )
    
    for cleanup_dir in "${cleanup_dirs[@]}"; do
        if [[ -d "$cleanup_dir" ]]; then
            log_warning "Emergency cleanup of directory: $cleanup_dir"
            if rm -rf "$cleanup_dir" 2>> "$CLEANUP_LOG_FILE"; then
                log_success "Emergency cleanup completed: $cleanup_dir"
                mkdir -p "$cleanup_dir"  # Recreate empty directory
            else
                log_error "Emergency cleanup failed: $cleanup_dir"
            fi
        fi
    done
}

# Generate cleanup report
generate_cleanup_report() {
    log_info "Generating cleanup report..."
    
    local report_file="${CLEANUP_LOGS_DIR}/cleanup-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "cleanup_session": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "pipeline_id": "${PIPELINE_ID:-null}",
    "dry_run": $DRY_RUN,
    "force_cleanup": $FORCE_CLEANUP,
    "timeout_seconds": $CLEANUP_TIMEOUT
  },
  "tasks": {
    "total": ${#CLEANUP_TASKS[@]},
    "successful": $((${#CLEANUP_TASKS[@]} - ${#FAILED_CLEANUPS[@]})),
    "failed": ${#FAILED_CLEANUPS[@]}
  },
  "failed_tasks": [
$(IFS=$'\n'; echo "${FAILED_CLEANUPS[*]}" | sed 's/^/    "/' | sed 's/$/"/' | sed '$!s/$/,/')
  ],
  "log_file": "$CLEANUP_LOG_FILE"
}
EOF
    
    log_info "Cleanup report generated: $report_file"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pipeline-id=*)
                PIPELINE_ID="${1#*=}"
                shift
                ;;
            --force)
                FORCE_CLEANUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --timeout=*)
                CLEANUP_TIMEOUT="${1#*=}"
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --emergency)
                EMERGENCY_CLEANUP=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Main execution function
main() {
    local start_time=$(date +%s)
    
    log_info "Starting test resource cleanup..."
    
    setup_cleanup_environment
    
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    # Emergency cleanup mode
    if [[ "${EMERGENCY_CLEANUP:-false}" == "true" ]]; then
        emergency_cleanup
        generate_cleanup_report
        exit 0
    fi
    
    # Normal cleanup process
    detect_test_resources
    
    if [[ ${#CLEANUP_TASKS[@]} -eq 0 ]]; then
        log_info "No test resources found to cleanup"
        generate_cleanup_report
        exit 0
    fi
    
    if execute_cleanup; then
        log_success "Cleanup completed successfully"
        generate_cleanup_report
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "Total cleanup time: ${duration}s"
        
        exit 0
    else
        log_error "Cleanup completed with failures"
        generate_cleanup_report
        
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_warning "Force cleanup mode - exiting with success despite failures"
            exit 0
        else
            exit 1
        fi
    fi
}

# Parse arguments and run main function
parse_arguments "$@"
main
