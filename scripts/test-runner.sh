#!/bin/bash

# Terraform Test Framework Runner
# This script executes tests based on module configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CONFIG_FILE="config/modules.yaml"
ENVIRONMENT="dev"
EXECUTION_MODE=""
MODULE_FILTER=""
EXECUTION_PLAN="basic"
DRY_RUN=false
VERBOSE=false
CLEANUP=true
PARALLEL=false

# Usage function
usage() {
    echo -e "${BLUE}Confluent Cloud Terraform Test Framework Runner${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --config FILE         Configuration file (default: config/modules.yaml)"
    echo "  -e, --env ENVIRONMENT     Environment (default: dev)"
    echo "  -m, --module MODULE       Run specific module only"
    echo "  -p, --plan PLAN          Execution plan: basic, full, security (default: basic)"
    echo "  --execution-mode MODE     Override execution mode: apply or plan"
    echo "  --dry-run                Show what would be executed without running"
    echo "  --no-cleanup             Skip cleanup after tests"
    echo "  --parallel               Run modules in parallel where possible"
    echo "  -v, --verbose            Verbose output"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --env dev --plan basic"
    echo "  $0 --module kafka_topic --env staging"
    echo "  $0 --config config/custom.yaml --env prod --parallel"
    echo "  $0 --dry-run --plan full"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -m|--module)
            MODULE_FILTER="$2"
            shift 2
            ;;
        -p|--plan)
            EXECUTION_PLAN="$2"
            shift 2
            ;;
        --execution-mode)
            EXECUTION_MODE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Check if yq is available for YAML parsing
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}⚠️  yq is not available. Installing...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y yq
    elif command -v brew &> /dev/null; then
        brew install yq
    else
        echo -e "${RED}❌ Please install yq to parse YAML configuration files${NC}"
        exit 1
    fi
fi

cd "$PROJECT_ROOT"

# Validate configuration file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Validate environment file
ENV_FILE="config/environments/${ENVIRONMENT}.yaml"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}🧪 Terraform Test Framework Runner${NC}"
echo "=================================================="
echo -e "${CYAN}Configuration:${NC} $CONFIG_FILE"
echo -e "${CYAN}Environment:${NC} $ENVIRONMENT"
echo -e "${CYAN}Execution Plan:${NC} $EXECUTION_PLAN"
if [[ -n "$MODULE_FILTER" ]]; then
    echo -e "${CYAN}Module Filter:${NC} $MODULE_FILTER"
fi
echo -e "${CYAN}Dry Run:${NC} $DRY_RUN"
echo -e "${CYAN}Parallel:${NC} $PARALLEL"
echo ""

# Load environment variables from environment file
echo -e "${YELLOW}🔧 Loading environment configuration...${NC}"

# Extract environment-specific settings
ENV_VARS=$(yq eval '.confluent_cloud | to_entries | map(.key + "=" + .value) | join(" ")' "$ENV_FILE")
if [[ "$VERBOSE" == "true" ]]; then
    echo "Environment variables: $ENV_VARS"
fi

# Set execution mode
if [[ -z "$EXECUTION_MODE" ]]; then
    EXECUTION_MODE=$(yq eval '.testing.execution_mode // "apply"' "$ENV_FILE")
fi
export TEST_EXECUTION_MODE="$EXECUTION_MODE"

echo -e "${CYAN}Execution Mode:${NC} $EXECUTION_MODE"

# Get modules to execute based on execution plan
if [[ -n "$MODULE_FILTER" ]]; then
    MODULES_TO_RUN="$MODULE_FILTER"
else
    MODULES_TO_RUN=$(yq eval ".execution_modes[] | select(.name == \"$EXECUTION_PLAN\") | .modules | join(\" \")" "$CONFIG_FILE")
    if [[ -z "$MODULES_TO_RUN" ]]; then
        echo -e "${RED}❌ Execution plan '$EXECUTION_PLAN' not found in configuration${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}📋 Modules to execute:${NC} $MODULES_TO_RUN"
echo ""

# Function to validate module exists
validate_module() {
    local module_name="$1"
    local module_path=$(yq eval ".modules.${module_name}.path // \"\"" "$CONFIG_FILE")
    
    if [[ -z "$module_path" ]]; then
        echo -e "${RED}❌ Module '$module_name' not found in configuration${NC}"
        return 1
    fi
    
    if [[ ! -d "terraform/$module_path" ]]; then
        echo -e "${RED}❌ Module path not found: terraform/$module_path${NC}"
        return 1
    fi
    
    return 0
}

# Function to check module dependencies
check_dependencies() {
    local module_name="$1"
    local dependencies=$(yq eval ".modules.${module_name}.dependencies // [] | join(\" \")" "$CONFIG_FILE")
    
    if [[ -n "$dependencies" && "$dependencies" != "null" ]]; then
        echo -e "${YELLOW}📦 Module '$module_name' has dependencies: $dependencies${NC}"
        # For now, just log dependencies. In a full implementation,
        # we would ensure dependencies are executed first
    fi
}

# Function to get module variables
get_module_variables() {
    local module_name="$1"
    local temp_vars_file="/tmp/test_vars_${module_name}.tfvars"
    
    # Extract module parameters from config
    yq eval ".modules.${module_name}.parameters" "$CONFIG_FILE" > "/tmp/module_params_${module_name}.yaml"
    
    # Convert to Terraform variables format
    echo "# Generated variables for module: $module_name" > "$temp_vars_file"
    
    # Add environment ID and cluster ID
    echo "environment_id = \"${CONFLUENT_ENVIRONMENT_ID}\"" >> "$temp_vars_file"
    echo "cluster_id = \"${CONFLUENT_CLUSTER_ID}\"" >> "$temp_vars_file"
    
    # Add other parameters (this is a simplified version)
    # In a full implementation, we would properly parse and substitute variables
    
    echo "$temp_vars_file"
}

# Function to run a single module test
run_module_test() {
    local module_name="$1"
    
    echo -e "${BLUE}🧪 Running module test: $module_name${NC}"
    echo "----------------------------------------"
    
    # Validate module
    if ! validate_module "$module_name"; then
        return 1
    fi
    
    # Check dependencies
    check_dependencies "$module_name"
    
    # Get module configuration
    local module_path=$(yq eval ".modules.${module_name}.path" "$CONFIG_FILE")
    local module_enabled=$(yq eval ".modules.${module_name}.enabled // true" "$CONFIG_FILE")
    
    if [[ "$module_enabled" == "false" ]]; then
        echo -e "${YELLOW}⚠️  Module '$module_name' is disabled, skipping${NC}"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY RUN] Would execute: terraform test for $module_name${NC}"
        echo -e "${CYAN}[DRY RUN] Module path: terraform/$module_path${NC}"
        return 0
    fi
    
    # Create test directory
    local test_dir="test-results/${module_name}"
    mkdir -p "$test_dir"
    
    # Run the actual test
    cd "terraform/${module_path}"
    
    local log_file="$PROJECT_ROOT/logs/${module_name}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${YELLOW}📝 Logging to: $log_file${NC}"
    
    # Initialize if needed
    terraform init >> "$log_file" 2>&1
    
    if [[ "$EXECUTION_MODE" == "apply" ]]; then
        echo -e "${YELLOW}🚀 Running terraform apply for $module_name...${NC}"
        
        if terraform apply -auto-approve \
            -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" \
            -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" \
            -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" \
            -var="cluster_id=${CONFLUENT_CLUSTER_ID}" \
            >> "$log_file" 2>&1; then
            echo -e "${GREEN}✅ Module '$module_name' applied successfully${NC}"
            
            # Run validation if cleanup is enabled
            if [[ "$CLEANUP" == "true" ]]; then
                echo -e "${YELLOW}🧹 Cleaning up resources for $module_name...${NC}"
                terraform destroy -auto-approve \
                    -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" \
                    -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" \
                    -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" \
                    -var="cluster_id=${CONFLUENT_CLUSTER_ID}" \
                    >> "$log_file" 2>&1
                echo -e "${GREEN}✅ Cleanup completed for $module_name${NC}"
            fi
        else
            echo -e "${RED}❌ Module '$module_name' failed${NC}"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "Error details:"
                tail -20 "$log_file"
            fi
            cd "$PROJECT_ROOT"
            return 1
        fi
    else
        echo -e "${YELLOW}📋 Running terraform plan for $module_name...${NC}"
        
        if terraform plan \
            -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" \
            -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" \
            -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" \
            -var="cluster_id=${CONFLUENT_CLUSTER_ID}" \
            >> "$log_file" 2>&1; then
            echo -e "${GREEN}✅ Module '$module_name' plan succeeded${NC}"
        else
            echo -e "${RED}❌ Module '$module_name' plan failed${NC}"
            cd "$PROJECT_ROOT"
            return 1
        fi
    fi
    
    cd "$PROJECT_ROOT"
    return 0
}

# Main execution
echo -e "${YELLOW}🚀 Starting test execution...${NC}"

# Create logs directory
mkdir -p logs

# Track results
declare -a PASSED_MODULES
declare -a FAILED_MODULES

# Execute modules
for module in $MODULES_TO_RUN; do
    if run_module_test "$module"; then
        PASSED_MODULES+=("$module")
    else
        FAILED_MODULES+=("$module")
    fi
    echo ""
done

# Summary
echo -e "${BLUE}📊 Test Execution Summary${NC}"
echo "=================================================="
echo -e "${GREEN}✅ Passed (${#PASSED_MODULES[@]}):${NC} ${PASSED_MODULES[*]}"
if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Failed (${#FAILED_MODULES[@]}):${NC} ${FAILED_MODULES[*]}"
fi
echo ""

if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed. Check logs in the logs/ directory.${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    exit 0
fi
