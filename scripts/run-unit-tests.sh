#!/bin/bash

# Sprint 2: Unit Tests Runner
# Runs unit tests for Terraform modules and configurations

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

# Test configuration
MODULES_DIR="${PROJECT_ROOT}/terraform/modules"
TESTS_DIR="${PROJECT_ROOT}/terraform/tests"
COVERAGE_THRESHOLD=80

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
    log_info "Setting up unit test environment..."
    
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Initialize test results file
    cat > "${TEST_RESULTS_DIR}/unit-tests.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="TerraformUnitTests" tests="0" failures="0" time="0">
</testsuite>
EOF
    
    # Initialize coverage report
    cat > "${TEST_RESULTS_DIR}/coverage.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<coverage version="1.0" timestamp="0" line-rate="0.0" branch-rate="0.0">
  <sources></sources>
  <packages></packages>
</coverage>
EOF
    
    log_success "Test environment setup complete"
}

# Validate Terraform configuration syntax
validate_terraform_syntax() {
    log_info "Validating Terraform configuration syntax..."
    
    local test_passed=true
    local modules_tested=0
    local syntax_errors=0
    
    cd "$PROJECT_ROOT/terraform"
    
    # Initialize Terraform
    if ! terraform init -backend=false; then
        log_error "Failed to initialize Terraform"
        return 1
    fi
    
    # Validate main configuration
    log_info "Validating main Terraform configuration..."
    if terraform validate; then
        log_success "Main configuration is valid"
        ((modules_tested++))
    else
        log_error "Main configuration has syntax errors"
        ((syntax_errors++))
        test_passed=false
    fi
    
    # Validate each module
    for module_dir in "$MODULES_DIR"/*; do
        if [[ -d "$module_dir" ]]; then
            local module_name=$(basename "$module_dir")
            log_info "Validating module: $module_name"
            
            cd "$module_dir"
            
            if terraform init -backend=false && terraform validate; then
                log_success "Module '$module_name' is valid"
                ((modules_tested++))
            else
                log_error "Module '$module_name' has syntax errors"
                ((syntax_errors++))
                test_passed=false
            fi
            
            cd "$PROJECT_ROOT/terraform"
        fi
    done
    
    # Generate JUnit XML for syntax validation
    create_syntax_validation_report "$modules_tested" "$syntax_errors"
    
    if [[ "$test_passed" == "true" ]]; then
        log_success "All Terraform configurations passed syntax validation"
        return 0
    else
        log_error "Some Terraform configurations failed syntax validation"
        return 1
    fi
}

# Test Terraform formatting
test_terraform_formatting() {
    log_info "Testing Terraform code formatting..."
    
    cd "$PROJECT_ROOT"
    
    # Check if all .tf files are properly formatted
    local unformatted_files=$(terraform fmt -check -recursive -diff 2>&1 | grep -E '\.tf$' || true)
    
    if [[ -z "$unformatted_files" ]]; then
        log_success "All Terraform files are properly formatted"
        return 0
    else
        log_error "The following files are not properly formatted:"
        echo "$unformatted_files"
        log_info "Run 'terraform fmt -recursive' to fix formatting"
        return 1
    fi
}

# Validate YAML configuration files
validate_yaml_configs() {
    log_info "Validating YAML configuration files..."
    
    local yaml_files=(
        "${PROJECT_ROOT}/config/modules.yaml"
        "${PROJECT_ROOT}/config/environments/dev.yaml"
        "${PROJECT_ROOT}/config/environments/local.yaml.example"
    )
    
    # Add staging.yaml if it exists
    if [[ -f "${PROJECT_ROOT}/config/environments/staging.yaml" ]]; then
        yaml_files+=("${PROJECT_ROOT}/config/environments/staging.yaml")
    fi
    
    local valid_files=0
    local total_files=${#yaml_files[@]}
    
    # Install yq if not available
    if ! command -v yq &> /dev/null; then
        log_info "Installing yq for YAML validation..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y yq
        elif command -v apk &> /dev/null; then
            apk add --no-cache yq
        else
            log_warning "Could not install yq, using python for YAML validation"
            validate_yaml_with_python "${yaml_files[@]}"
            return $?
        fi
    fi
    
    for yaml_file in "${yaml_files[@]}"; do
        if [[ -f "$yaml_file" ]]; then
            log_info "Validating: $(basename "$yaml_file")"
            
            if yq eval '.' "$yaml_file" > /dev/null 2>&1; then
                log_success "Valid YAML: $(basename "$yaml_file")"
                ((valid_files++))
            else
                log_error "Invalid YAML: $(basename "$yaml_file")"
            fi
        else
            log_warning "YAML file not found: $yaml_file"
        fi
    done
    
    if [[ $valid_files -eq $total_files ]]; then
        log_success "All YAML files are valid"
        return 0
    else
        log_error "Some YAML files are invalid"
        return 1
    fi
}

# Validate YAML using Python (fallback)
validate_yaml_with_python() {
    local yaml_files=("$@")
    local valid_files=0
    local total_files=${#yaml_files[@]}
    
    for yaml_file in "${yaml_files[@]}"; do
        if [[ -f "$yaml_file" ]]; then
            log_info "Validating with Python: $(basename "$yaml_file")"
            
            if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                log_success "Valid YAML: $(basename "$yaml_file")"
                ((valid_files++))
            else
                log_error "Invalid YAML: $(basename "$yaml_file")"
            fi
        else
            log_warning "YAML file not found: $yaml_file"
        fi
    done
    
    if [[ $valid_files -eq $total_files ]]; then
        return 0
    else
        return 1
    fi
}

# Test module configurations
test_module_configurations() {
    log_info "Testing module configurations..."
    
    local modules_config="${PROJECT_ROOT}/config/modules.yaml"
    local passed_tests=0
    local failed_tests=0
    
    # Check if modules.yaml exists and is readable
    if [[ ! -f "$modules_config" ]]; then
        log_error "modules.yaml not found"
        return 1
    fi
    
    # Extract module names using Python
    local module_names
    if ! module_names=$(python3 -c "
import yaml
with open('$modules_config', 'r') as f:
    config = yaml.safe_load(f)
    if 'modules' in config:
        for module_name in config['modules'].keys():
            print(module_name)
    else:
        print('ERROR: No modules section found')
        exit(1)
" 2>/dev/null); then
        log_error "Failed to parse modules.yaml"
        return 1
    fi
    
    # Test each module configuration
    while IFS= read -r module_name; do
        if [[ -n "$module_name" && "$module_name" != "ERROR:"* ]]; then
            log_info "Testing configuration for module: $module_name"
            
            if test_single_module_config "$module_name"; then
                ((passed_tests++))
            else
                ((failed_tests++))
            fi
        fi
    done <<< "$module_names"
    
    log_info "Module configuration tests: $passed_tests passed, $failed_tests failed"
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All module configurations are valid"
        return 0
    else
        log_error "Some module configurations are invalid"
        return 1
    fi
}

# Test a single module configuration
test_single_module_config() {
    local module_name="$1"
    local modules_config="${PROJECT_ROOT}/config/modules.yaml"
    
    # Validate required fields exist
    local required_fields=("path" "description" "parameters")
    
    for field in "${required_fields[@]}"; do
        local field_value
        field_value=$(python3 -c "
import yaml
with open('$modules_config', 'r') as f:
    config = yaml.safe_load(f)
    try:
        print(config['modules']['$module_name']['$field'])
    except KeyError:
        print('MISSING')
" 2>/dev/null)
        
        if [[ "$field_value" == "MISSING" || -z "$field_value" ]]; then
            log_error "Module '$module_name' missing required field: $field"
            return 1
        fi
    done
    
    # Check if module directory exists
    local module_path
    module_path=$(python3 -c "
import yaml
with open('$modules_config', 'r') as f:
    config = yaml.safe_load(f)
    print(config['modules']['$module_name']['path'])
" 2>/dev/null)
    
    local full_module_path="${PROJECT_ROOT}/terraform/${module_path#./}"
    if [[ ! -d "$full_module_path" ]]; then
        log_error "Module directory not found: $full_module_path"
        return 1
    fi
    
    # Check if main.tf exists in module
    if [[ ! -f "$full_module_path/main.tf" ]]; then
        log_error "main.tf not found in module: $module_name"
        return 1
    fi
    
    log_success "Module configuration valid: $module_name"
    return 0
}

# Test script permissions and executability
test_script_permissions() {
    log_info "Testing script permissions and executability..."
    
    local scripts=(
        "${PROJECT_ROOT}/scripts/setup.sh"
        "${PROJECT_ROOT}/scripts/test-runner.sh"
        "${PROJECT_ROOT}/scripts/quick-start.sh"
        "${PROJECT_ROOT}/scripts/run-e2e-tests.sh"
    )
    
    local passed_tests=0
    local failed_tests=0
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_success "Script is executable: $(basename "$script")"
                ((passed_tests++))
            else
                log_error "Script is not executable: $(basename "$script")"
                ((failed_tests++))
            fi
        else
            log_error "Script not found: $(basename "$script")"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All scripts have correct permissions"
        return 0
    else
        log_error "Some scripts have permission issues"
        return 1
    fi
}

# Create syntax validation JUnit report
create_syntax_validation_report() {
    local modules_tested="$1"
    local syntax_errors="$2"
    local report_file="${TEST_RESULTS_DIR}/syntax-validation.xml"
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="TerraformSyntaxValidation" tests="$modules_tested" failures="$syntax_errors" time="0">
  <testcase name="terraform_syntax_validation" classname="SyntaxTests" time="0">
    $(if [[ $syntax_errors -gt 0 ]]; then echo "<failure message=\"$syntax_errors modules failed syntax validation\">Some Terraform modules have syntax errors</failure>"; fi)
  </testcase>
</testsuite>
EOF
    
    log_info "Syntax validation report created: $report_file"
}

# Generate comprehensive JUnit report
generate_junit_report() {
    local total_tests="$1"
    local failed_tests="$2"
    local start_time="$3"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local report_file="${TEST_RESULTS_DIR}/unit-tests.xml"
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="TerraformUnitTests" tests="$total_tests" failures="$failed_tests" time="$duration">
  <testcase name="terraform_syntax_validation" classname="UnitTests" time="0">
    $(if [[ $failed_tests -gt 0 ]]; then echo "<failure message=\"$failed_tests tests failed\">Unit tests failed</failure>"; fi)
  </testcase>
  <testcase name="terraform_formatting" classname="UnitTests" time="0"/>
  <testcase name="yaml_configuration" classname="UnitTests" time="0"/>
  <testcase name="module_configuration" classname="UnitTests" time="0"/>
  <testcase name="script_permissions" classname="UnitTests" time="0"/>
  <system-out><![CDATA[
Unit Tests Summary:
- Total Tests: $total_tests
- Failed Tests: $failed_tests
- Duration: ${duration}s
- Coverage Threshold: ${COVERAGE_THRESHOLD}%
  ]]></system-out>
</testsuite>
EOF
    
    log_info "JUnit report generated: $report_file"
}

# Calculate coverage (mock implementation)
calculate_coverage() {
    log_info "Calculating test coverage..."
    
    # This is a simplified coverage calculation
    # In a real implementation, you would analyze Terraform modules and test coverage
    local terraform_files=$(find "$PROJECT_ROOT/terraform" -name "*.tf" | wc -l)
    local test_files=$(find "$PROJECT_ROOT/terraform/tests" -name "*.tftest.hcl" 2>/dev/null | wc -l || echo "0")
    
    local coverage=0
    if [[ $terraform_files -gt 0 ]]; then
        coverage=$(( (test_files * 100) / terraform_files ))
    fi
    
    log_info "Coverage: $coverage% ($test_files test files for $terraform_files Terraform files)"
    echo "Coverage: $coverage.0%"
    
    # Generate coverage report
    cat > "${TEST_RESULTS_DIR}/coverage.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<coverage version="1.0" timestamp="$(date +%s)" line-rate="0.${coverage}" branch-rate="0.${coverage}">
  <sources>
    <source>${PROJECT_ROOT}/terraform</source>
  </sources>
  <packages>
    <package name="terraform" line-rate="0.${coverage}" branch-rate="0.${coverage}">
      <classes>
        <class name="terraform_modules" filename="modules" line-rate="0.${coverage}" branch-rate="0.${coverage}">
          <lines>
            <line number="1" hits="1"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
    
    if [[ $coverage -lt $COVERAGE_THRESHOLD ]]; then
        log_warning "Coverage $coverage% is below threshold $COVERAGE_THRESHOLD%"
        return 1
    else
        log_success "Coverage $coverage% meets threshold $COVERAGE_THRESHOLD%"
        return 0
    fi
}

# Main execution function
main() {
    local start_time=$(date +%s)
    local total_tests=0
    local failed_tests=0
    
    log_info "Starting Terraform unit tests..."
    
    setup_test_environment
    
    # Run all unit tests
    local tests=(
        "validate_terraform_syntax"
        "test_terraform_formatting" 
        "validate_yaml_configs"
        "test_module_configurations"
        "test_script_permissions"
    )
    
    for test in "${tests[@]}"; do
        log_info "Running test: $test"
        ((total_tests++))
        
        if ! $test; then
            ((failed_tests++))
            log_error "Test failed: $test"
        else
            log_success "Test passed: $test"
        fi
    done
    
    # Calculate coverage
    if ! calculate_coverage; then
        log_warning "Coverage is below threshold but not failing the build"
    fi
    
    # Generate final report
    generate_junit_report "$total_tests" "$failed_tests" "$start_time"
    
    # Summary
    log_info "Unit Tests Summary:"
    log_info "  Total Tests: $total_tests"
    log_info "  Failed Tests: $failed_tests"
    log_info "  Success Rate: $(( (total_tests - failed_tests) * 100 / total_tests ))%"
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All unit tests passed!"
        exit 0
    else
        log_error "Some unit tests failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
