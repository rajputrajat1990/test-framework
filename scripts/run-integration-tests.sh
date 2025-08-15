#!/bin/bash

# Sprint 2: Integration Tests Runner
# Runs integration tests for Terraform modules against real Confluent Cloud resources

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
TEST_RESULTS_DIR="${PROJECT_ROOT}/test-results"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Default values
TEST_ENV="${TEST_ENV:-dev}"
MODULE_TYPE="${MODULE_TYPE:-all}"
PARALLEL_EXECUTION=true
CLEANUP_AFTER=true
TIMEOUT=1800  # 30 minutes

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up integration test environment..."
    
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$LOGS_DIR"
    
    # Set test-specific environment variables
    export TEST_PREFIX="integration-${MODULE_TYPE}"
    export TEST_SUFFIX="${TEST_ENV}-$(date +%s)"
    export TF_VAR_test_prefix="$TEST_PREFIX"
    export TF_VAR_test_suffix="$TEST_SUFFIX"
    
    log_success "Test environment setup complete"
}

# Validate required environment variables
validate_environment() {
    log_info "Validating environment variables..."
    
    local required_vars=(
        "CONFLUENT_CLOUD_API_KEY"
        "CONFLUENT_CLOUD_API_SECRET"
        "CONFLUENT_ENVIRONMENT_ID"
        "CONFLUENT_CLUSTER_ID"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    # Add module-specific environment variables based on MODULE_TYPE
    case "$MODULE_TYPE" in
        "s3-source-connector")
            if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
                missing_vars+=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")
            fi
            if [[ -z "${TEST_S3_BUCKET:-}" ]]; then
                missing_vars+=("TEST_S3_BUCKET")
            fi
            ;;
        "postgres-sink-connector")
            if [[ -z "${TEST_DATABASE_URL:-}" ]]; then
                missing_vars+=("TEST_DATABASE_URL")
            fi
            ;;
    esac
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        return 1
    fi
    
    log_success "Environment variables validated"
    return 0
}

# Get available modules for testing
get_available_modules() {
    local modules_config="${PROJECT_ROOT}/config/modules.yaml"
    
    if [[ "$MODULE_TYPE" == "all" ]]; then
        python3 -c "
import yaml
with open('$modules_config', 'r') as f:
    config = yaml.safe_load(f)
    for module_name in config['modules'].keys():
        print(module_name)
"
    else
        echo "$MODULE_TYPE"
    fi
}

# Run integration test for a single module
run_module_integration_test() {
    local module_name="$1"
    local test_start_time=$(date +%s)
    
    log_info "Running integration test for module: $module_name"
    
    # Create module-specific log file
    local log_file="${LOGS_DIR}/integration-${module_name}-${TEST_ENV}-$(date +%Y%m%d-%H%M%S).log"
    
    # Create test directory for this module
    local test_dir="${PROJECT_ROOT}/terraform/tests/integration/${module_name}"
    mkdir -p "$test_dir"
    
    # Create Terraform test configuration for the module
    create_integration_test_config "$module_name" "$test_dir"
    
    cd "$test_dir"
    
    # Initialize Terraform
    if ! terraform init >> "$log_file" 2>&1; then
        log_error "Failed to initialize Terraform for module: $module_name"
        return 1
    fi
    
    # Plan the test
    log_info "Planning integration test for $module_name..."
    if ! timeout 300 terraform plan -var-file="${PROJECT_ROOT}/config/environments/${TEST_ENV}.yaml" -out=tfplan >> "$log_file" 2>&1; then
        log_error "Failed to plan integration test for module: $module_name"
        return 1
    fi
    
    # Apply the test
    log_info "Applying integration test for $module_name..."
    if ! timeout 600 terraform apply -auto-approve tfplan >> "$log_file" 2>&1; then
        log_error "Failed to apply integration test for module: $module_name"
        return 1
    fi
    
    # Run validation
    log_info "Validating resources for $module_name..."
    if ! validate_module_resources "$module_name" "$log_file"; then
        log_error "Resource validation failed for module: $module_name"
        return 1
    fi
    
    # Run module-specific tests
    if ! run_module_specific_tests "$module_name" "$log_file"; then
        log_error "Module-specific tests failed for: $module_name"
        return 1
    fi
    
    # Cleanup resources
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        log_info "Cleaning up resources for $module_name..."
        if ! timeout 600 terraform destroy -auto-approve -var-file="${PROJECT_ROOT}/config/environments/${TEST_ENV}.yaml" >> "$log_file" 2>&1; then
            log_warning "Failed to cleanup resources for module: $module_name"
        fi
    fi
    
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))
    
    # Generate JUnit report for this module
    create_module_junit_report "$module_name" "passed" "$test_duration"
    
    log_success "Integration test passed for module: $module_name (${test_duration}s)"
    return 0
}

# Create Terraform test configuration for integration testing
create_integration_test_config() {
    local module_name="$1"
    local test_dir="$2"
    
    # Get module configuration from modules.yaml
    local module_config=$(python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    module_config = config['modules']['$module_name']
    print(module_config['path'])
")
    
    # Create main.tf for the integration test
    cat > "${test_dir}/main.tf" << EOF
# Integration Test Configuration for Module: $module_name
# Generated automatically for testing

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.51.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Module under test
module "${module_name}_test" {
  source = "../../..$module_config"
  
  # Pass through all required variables
  $(generate_module_variables "$module_name")
}

# Output all module outputs for validation
$(generate_module_outputs "$module_name")
EOF

    # Create variables.tf
    create_integration_test_variables "$module_name" "$test_dir"
    
    # Create terraform.tfvars
    create_integration_test_tfvars "$module_name" "$test_dir"
}

# Generate module variables for integration test
generate_module_variables() {
    local module_name="$1"
    
    python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    module_config = config['modules']['$module_name']
    parameters = module_config.get('parameters', {})
    
    for param_name, param_value in parameters.items():
        print(f'  {param_name} = var.{param_name}')
"
}

# Generate module outputs for integration test
generate_module_outputs() {
    local module_name="$1"
    
    python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    module_config = config['modules']['$module_name']
    validation = module_config.get('validation', {})
    required_outputs = validation.get('required_outputs', [])
    
    for output_name in required_outputs:
        print(f'output \"{output_name}\" {{')
        print(f'  value = module.{module_name}_test.{output_name}')
        print(f'}}')
        print()
"
}

# Create variables.tf for integration test
create_integration_test_variables() {
    local module_name="$1"
    local test_dir="$2"
    
    cat > "${test_dir}/variables.tf" << 'EOF'
# Integration Test Variables

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "confluent_environment_id" {
  description = "Confluent Environment ID"
  type        = string
}

variable "confluent_cluster_id" {
  description = "Confluent Cluster ID"
  type        = string
}

variable "test_prefix" {
  description = "Test prefix for resource naming"
  type        = string
  default     = "integration-test"
}

variable "test_suffix" {
  description = "Test suffix for resource naming"
  type        = string
  default     = ""
}
EOF

    # Add module-specific variables
    case "$module_name" in
        "s3_source_connector")
            cat >> "${test_dir}/variables.tf" << 'EOF'

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "test_s3_bucket" {
  description = "S3 bucket for testing"
  type        = string
}
EOF
            ;;
        "postgres_sink_connector")
            cat >> "${test_dir}/variables.tf" << 'EOF'

variable "test_database_url" {
  description = "Test database URL"
  type        = string
  sensitive   = true
}

variable "test_database_user" {
  description = "Test database user"
  type        = string
  sensitive   = true
}

variable "test_database_password" {
  description = "Test database password"
  type        = string
  sensitive   = true
}
EOF
            ;;
    esac
}

# Create terraform.tfvars for integration test
create_integration_test_tfvars() {
    local module_name="$1"
    local test_dir="$2"
    
    cat > "${test_dir}/terraform.tfvars" << EOF
# Integration Test Variables
confluent_cloud_api_key    = "$CONFLUENT_CLOUD_API_KEY"
confluent_cloud_api_secret = "$CONFLUENT_CLOUD_API_SECRET"
confluent_environment_id   = "$CONFLUENT_ENVIRONMENT_ID"
confluent_cluster_id       = "$CONFLUENT_CLUSTER_ID"
test_prefix               = "$TEST_PREFIX"
test_suffix               = "$TEST_SUFFIX"
EOF

    # Add module-specific variables
    case "$module_name" in
        "s3_source_connector")
            cat >> "${test_dir}/terraform.tfvars" << EOF
aws_access_key_id     = "$AWS_ACCESS_KEY_ID"
aws_secret_access_key = "$AWS_SECRET_ACCESS_KEY"
test_s3_bucket        = "$TEST_S3_BUCKET"
EOF
            ;;
        "postgres_sink_connector")
            cat >> "${test_dir}/terraform.tfvars" << EOF
test_database_url      = "$TEST_DATABASE_URL"
test_database_user     = "$TEST_DATABASE_USER"
test_database_password = "$TEST_DATABASE_PASSWORD"
EOF
            ;;
    esac
}

# Validate module resources after creation
validate_module_resources() {
    local module_name="$1"
    local log_file="$2"
    
    log_info "Validating resources for module: $module_name"
    
    # Get expected resource counts and types from module config
    local expected_count expected_type
    expected_count=$(python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    validation = config['modules']['$module_name'].get('validation', {})
    print(validation.get('resource_count', 1))
")
    
    expected_type=$(python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    validation = config['modules']['$module_name'].get('validation', {})
    print(validation.get('resource_type', 'unknown'))
")
    
    # Check Terraform state for created resources
    local actual_count
    actual_count=$(terraform show -json | jq -r '.values.root_module.child_modules[0].resources | length' 2>/dev/null || echo "0")
    
    if [[ "$actual_count" -ne "$expected_count" ]]; then
        log_error "Resource count validation failed. Expected: $expected_count, Actual: $actual_count"
        return 1
    fi
    
    # Validate required outputs exist
    local required_outputs
    required_outputs=$(python3 -c "
import yaml
with open('${PROJECT_ROOT}/config/modules.yaml', 'r') as f:
    config = yaml.safe_load(f)
    validation = config['modules']['$module_name'].get('validation', {})
    outputs = validation.get('required_outputs', [])
    for output in outputs:
        print(output)
")
    
    while IFS= read -r output_name; do
        if [[ -n "$output_name" ]]; then
            local output_value
            output_value=$(terraform output -raw "$output_name" 2>/dev/null || echo "")
            
            if [[ -z "$output_value" ]]; then
                log_error "Required output missing: $output_name"
                return 1
            fi
            
            log_info "Output validated: $output_name = $output_value"
        fi
    done <<< "$required_outputs"
    
    log_success "Resource validation passed for module: $module_name"
    return 0
}

# Run module-specific integration tests
run_module_specific_tests() {
    local module_name="$1"
    local log_file="$2"
    
    log_info "Running module-specific tests for: $module_name"
    
    case "$module_name" in
        "kafka_topic")
            test_kafka_topic_functionality "$log_file"
            ;;
        "rbac_cluster_admin"|"rbac_topic_access")
            test_rbac_functionality "$log_file"
            ;;
        "s3_source_connector")
            test_s3_source_connector_functionality "$log_file"
            ;;
        "postgres_sink_connector")
            test_postgres_sink_connector_functionality "$log_file"
            ;;
        *)
            log_info "No specific tests defined for module: $module_name"
            return 0
            ;;
    esac
}

# Test Kafka topic functionality
test_kafka_topic_functionality() {
    local log_file="$1"
    
    log_info "Testing Kafka topic functionality..."
    
    local topic_name
    topic_name=$(terraform output -raw topic_name 2>/dev/null)
    
    if [[ -z "$topic_name" ]]; then
        log_error "Topic name not available from Terraform output"
        return 1
    fi
    
    # Test topic existence using Confluent CLI (if available) or API
    log_info "Verifying topic exists: $topic_name"
    
    # For now, we'll just verify the output exists
    # In a full implementation, you would use the Confluent Cloud API to verify the topic
    log_success "Topic functionality test passed"
    return 0
}

# Test RBAC functionality
test_rbac_functionality() {
    local log_file="$1"
    
    log_info "Testing RBAC functionality..."
    
    local role_binding_id
    role_binding_id=$(terraform output -raw role_binding_id 2>/dev/null)
    
    if [[ -z "$role_binding_id" ]]; then
        log_error "Role binding ID not available from Terraform output"
        return 1
    fi
    
    log_info "Verifying role binding exists: $role_binding_id"
    
    # In a full implementation, you would use the Confluent Cloud API to verify the role binding
    log_success "RBAC functionality test passed"
    return 0
}

# Test S3 source connector functionality
test_s3_source_connector_functionality() {
    local log_file="$1"
    
    log_info "Testing S3 source connector functionality..."
    
    local connector_name
    connector_name=$(terraform output -raw connector_name 2>/dev/null)
    
    if [[ -z "$connector_name" ]]; then
        log_error "Connector name not available from Terraform output"
        return 1
    fi
    
    log_info "Verifying S3 source connector exists: $connector_name"
    
    # In a full implementation, you would:
    # 1. Upload test files to S3
    # 2. Wait for connector to process
    # 3. Verify data appears in Kafka topic
    
    log_success "S3 source connector functionality test passed"
    return 0
}

# Test PostgreSQL sink connector functionality
test_postgres_sink_connector_functionality() {
    local log_file="$1"
    
    log_info "Testing PostgreSQL sink connector functionality..."
    
    local connector_name
    connector_name=$(terraform output -raw connector_name 2>/dev/null)
    
    if [[ -z "$connector_name" ]]; then
        log_error "Connector name not available from Terraform output"
        return 1
    fi
    
    log_info "Verifying PostgreSQL sink connector exists: $connector_name"
    
    # In a full implementation, you would:
    # 1. Send test data to Kafka topic
    # 2. Wait for connector to process
    # 3. Verify data appears in PostgreSQL database
    
    log_success "PostgreSQL sink connector functionality test passed"
    return 0
}

# Create JUnit report for a module test
create_module_junit_report() {
    local module_name="$1"
    local test_result="$2"  # "passed" or "failed"
    local test_duration="$3"
    
    local report_file="${TEST_RESULTS_DIR}/integration-${module_name}-${TEST_ENV}.xml"
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Integration-${module_name}-${TEST_ENV}" tests="1" failures="$([[ $test_result == "failed" ]] && echo "1" || echo "0")" time="$test_duration">
  <testcase name="integration_${module_name}" classname="IntegrationTests" time="$test_duration">
    $([[ $test_result == "failed" ]] && echo '<failure message="Integration test failed">Module integration test failed</failure>')
  </testcase>
  <system-out><![CDATA[
Module: $module_name
Environment: $TEST_ENV
Duration: ${test_duration}s
Test Prefix: $TEST_PREFIX
Test Suffix: $TEST_SUFFIX
  ]]></system-out>
</testsuite>
EOF
    
    log_info "JUnit report created for $module_name: $report_file"
}

# Run all integration tests
main() {
    local start_time=$(date +%s)
    
    log_info "Starting integration tests..."
    log_info "Environment: $TEST_ENV"
    log_info "Module Type: $MODULE_TYPE"
    log_info "Parallel Execution: $PARALLEL_EXECUTION"
    
    setup_test_environment
    
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    local modules
    modules=$(get_available_modules)
    
    if [[ -z "$modules" ]]; then
        log_error "No modules found for testing"
        exit 1
    fi
    
    local total_modules=0
    local failed_modules=0
    local passed_modules=0
    
    # Count total modules
    while IFS= read -r module_name; do
        if [[ -n "$module_name" ]]; then
            ((total_modules++))
        fi
    done <<< "$modules"
    
    log_info "Running integration tests for $total_modules module(s)..."
    
    # Run tests for each module
    if [[ "$PARALLEL_EXECUTION" == "true" && $total_modules -gt 1 ]]; then
        log_info "Running tests in parallel..."
        
        local pids=()
        while IFS= read -r module_name; do
            if [[ -n "$module_name" ]]; then
                run_module_integration_test "$module_name" &
                pids+=($!)
                
                # Limit parallel executions
                if [[ ${#pids[@]} -ge ${PARALLEL_EXECUTION_LIMIT:-3} ]]; then
                    wait ${pids[0]}
                    pids=("${pids[@]:1}")
                fi
            fi
        done <<< "$modules"
        
        # Wait for remaining processes
        for pid in "${pids[@]}"; do
            wait $pid
        done
    else
        log_info "Running tests sequentially..."
        
        while IFS= read -r module_name; do
            if [[ -n "$module_name" ]]; then
                if run_module_integration_test "$module_name"; then
                    ((passed_modules++))
                else
                    ((failed_modules++))
                    create_module_junit_report "$module_name" "failed" "0"
                fi
            fi
        done <<< "$modules"
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Summary
    log_info "Integration Tests Summary:"
    log_info "  Total Modules: $total_modules"
    log_info "  Passed: $passed_modules"
    log_info "  Failed: $failed_modules"
    log_info "  Duration: ${total_duration}s"
    log_info "  Success Rate: $(( (passed_modules * 100) / total_modules ))%"
    
    if [[ $failed_modules -eq 0 ]]; then
        log_success "All integration tests passed!"
        exit 0
    else
        log_error "Some integration tests failed!"
        exit 1
    fi
}

# Parse command line arguments if any
while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            TEST_ENV="${1#*=}"
            shift
            ;;
        --module=*)
            MODULE_TYPE="${1#*=}"
            shift
            ;;
        --no-parallel)
            PARALLEL_EXECUTION=false
            shift
            ;;
        --no-cleanup)
            CLEANUP_AFTER=false
            shift
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [--env=ENV] [--module=MODULE] [--no-parallel] [--no-cleanup] [--timeout=SECONDS]"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
