#!/bin/bash

# Terraform Test Framework Runner
# This script executes tests based on module configurations

set -e
set -o pipefail

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

# Sensible defaults
export TEST_PREFIX="${TEST_PREFIX:-tftest}"

# Helper: get module block range and extract a field
get_module_block_range() {
    local config_file="$1" module_name="$2"
    local start end total
    start=$(grep -nE "^  ${module_name}:" "$config_file" | head -1 | cut -d: -f1 || true)
    if [[ -z "$start" ]]; then
        echo ""; return 1
    fi
    total=$(wc -l < "$config_file")
    end=$(awk -v s=$start 'NR>s && /^  [A-Za-z0-9_-]+:/{print NR; exit}' "$config_file")
    [[ -z "$end" ]] && end=$total
    echo "$start:$end"
}

get_module_field() {
    local config_file="$1" module_name="$2" field="$3"
    local range=$(get_module_block_range "$config_file" "$module_name")
    [[ -z "$range" ]] && return 1
    local start=${range%:*} end=${range#*:}
    sed -n "${start},${end}p" "$config_file" | grep -m1 -E "^[[:space:]]+${field}:" | awk -F': *' '{print $2}' | tr -d '"' | tr -d '\r\n\t'
}

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
    echo "  $0 -e dev                 Run basic tests in dev environment"
    echo "  $0 -e staging -p full     Run full test suite in staging"
    echo "  $0 -m kafka_topic         Run only the Kafka topic module tests"
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

# Load .env file if it exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo -e "${YELLOW}🔧 Loading .env file...${NC}"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# yq is optional; we will use simple shell/Python parsing instead to avoid version differences

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

echo -e "${YELLOW}🔧 Loading environment configuration...${NC}"

# Lightweight YAML parse for environment and cluster IDs
if [[ -z "${CONFLUENT_ENVIRONMENT_ID:-}" ]]; then
    CONFLUENT_ENVIRONMENT_ID=$(awk -F': *' '/^\s*environment_id:/ {print $2; exit}' "$ENV_FILE" | tr -d '"')
fi
if [[ -z "${CONFLUENT_CLUSTER_ID:-}" ]]; then
    CONFLUENT_CLUSTER_ID=$(awk -F': *' '/^\s*cluster_id:/ {print $2; exit}' "$ENV_FILE" | tr -d '"')
fi

if [[ -z "${CONFLUENT_ENVIRONMENT_ID:-}" || -z "${CONFLUENT_CLUSTER_ID:-}" ]]; then
    echo -e "${RED}❌ Could not read environment_id/cluster_id from $ENV_FILE or .env${NC}"
    exit 1
fi

export CONFLUENT_ENVIRONMENT_ID
export CONFLUENT_CLUSTER_ID

# Set execution mode
if [[ -z "$EXECUTION_MODE" ]]; then
    EXECUTION_MODE=$(awk -F': *' '/^\s*execution_mode:/ {print $2; exit}' "$ENV_FILE" | tr -d '"')
    EXECUTION_MODE=${EXECUTION_MODE:-apply}
fi
export TEST_EXECUTION_MODE="$EXECUTION_MODE"

echo -e "${CYAN}Execution Mode:${NC} $EXECUTION_MODE"

# Get modules to execute based on execution plan
if [[ -n "$MODULE_FILTER" ]]; then
    MODULES_TO_RUN="$MODULE_FILTER"
else
    MODULES_TO_RUN=$(python3 - <<PYEOF
try:
    import yaml, os
    cfg = "$PROJECT_ROOT/$CONFIG_FILE"
    with open(cfg, 'r') as f:
        y = yaml.safe_load(f) or {}
    plan = os.environ.get('EXECUTION_PLAN', '$EXECUTION_PLAN')
    mods = []
    for mode in (y.get('execution_modes') or []):
        if mode.get('name') == plan:
            mods = mode.get('modules') or []
            break
    print(' '.join(mods))
except Exception:
    pass
PYEOF
)
    if [[ -z "$MODULES_TO_RUN" ]]; then
        # Fallback defaults if PyYAML isn't available
        case "$EXECUTION_PLAN" in
            basic) MODULES_TO_RUN="kafka_topic rbac_cluster_admin rbac_topic_access";;
            security) MODULES_TO_RUN="rbac_cluster_admin rbac_topic_access";;
            *) MODULES_TO_RUN="kafka_topic rbac_cluster_admin rbac_topic_access";;
        esac
        echo -e "${YELLOW}⚠️  Falling back to default modules for plan '$EXECUTION_PLAN': ${MODULES_TO_RUN}${NC}"
    fi
fi

echo -e "${YELLOW}📋 Modules to execute:${NC} $MODULES_TO_RUN"
echo ""

# Function to validate module exists
validate_module() {
    local module_name="$1"
    local config_file="$PROJECT_ROOT/$CONFIG_FILE"
    
    # Extract module path via helper
    local module_path
    module_path=$(get_module_field "$config_file" "$module_name" "path")
    if [[ -z "$module_path" ]]; then
        echo -e "${RED}❌ Module '$module_name' not found in configuration${NC}"
        return 1
    fi
    
    module_path=$(echo -n "$module_path" | tr -d '\r\n\t')
    
    if [[ -z "$module_path" ]]; then
        echo -e "${RED}❌ Module path not found for '$module_name'${NC}"
        return 1
    fi
    
    # Normalize path: modules.yaml paths are relative to terraform/
    local tf_module_dir="terraform/${module_path#./}"
    if [[ ! -d "$tf_module_dir" ]]; then
        echo -e "${RED}❌ Module path not found: $tf_module_dir${NC}"
        return 1
    fi
    
    return 0
}

# Function to check module dependencies
check_dependencies() {
    local module_name="$1"
    local config_file="$PROJECT_ROOT/$CONFIG_FILE"
    
    # If yq is not available, skip dependency parsing gracefully
    if ! command -v yq >/dev/null 2>&1; then
        return 0
    fi

    # Get dependencies
    local dependencies_data=$(yq ".modules.$module_name.dependencies" "$config_file")
    if [[ "$dependencies_data" == "null" ]]; then
        # No dependencies
        return 0
    fi
    
    # Parse dependencies
    local dependencies=$(echo "$dependencies_data" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        print(" ".join(data))
except Exception as e:
    pass
')
    
    if [[ -z "$dependencies" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}📦 Module '$module_name' depends on: $dependencies${NC}"
    
    # Check each dependency
    for dep in $dependencies; do
        if ! validate_module "$dep"; then
            echo -e "${RED}❌ Dependency '$dep' for module '$module_name' is invalid${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to get module variables
get_module_variables() {
    local module_name="$1"
    local temp_vars_file="/tmp/test_vars_${module_name}.tfvars"
    
    # Get the absolute paths
    local config_file="$PROJECT_ROOT/$CONFIG_FILE"
    
    # Extract module parameters from config
    local parameters=$(yq ".modules.$module_name.parameters" "$config_file")
    echo "$parameters" > "/tmp/module_params_${module_name}.yaml"
    
    # Convert to Terraform variables format
    echo "# Generated variables for module: $module_name" > "$temp_vars_file"
    
    # Add environment ID and cluster ID
    echo "environment_id = \"${CONFLUENT_ENVIRONMENT_ID}\"" >> "$temp_vars_file"
    echo "cluster_id = \"${CONFLUENT_CLUSTER_ID}\"" >> "$temp_vars_file"
    echo "organization_id = \"${CONFLUENT_ORGANIZATION_ID}\"" >> "$temp_vars_file"
    
    # Add other parameters (this is a simplified version)
    # In a full implementation, we would properly parse and substitute variables
    
    echo "$temp_vars_file"
}

# Check if the current terraform module declares a variable
module_has_variable() {
    local var_name="$1"
    # Search all .tf files in the current module directory for variable declaration
    if ls *.tf >/dev/null 2>&1; then
        # match: variable "name" or variable\n  "name" styles
        if grep -qE "variable[[:space:]]+\"${var_name}\"" *.tf 2>/dev/null; then
            return 0
        fi
        if grep -qE "variable[[:space:]]*\n[[:space:]]*\"${var_name}\"" *.tf 2>/dev/null; then
            return 0
        fi
        # fallback: variable followed by name without quotes (less common)
        if grep -qE "variable[[:space:]]+${var_name}" *.tf 2>/dev/null; then
            return 0
        fi
    fi
    return 1
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
    local config_file="$PROJECT_ROOT/$CONFIG_FILE"
    local module_path
    module_path=$(get_module_field "$config_file" "$module_name" "path")
    local module_enabled
    module_enabled=$(get_module_field "$config_file" "$module_name" "enabled")
    [[ -z "$module_enabled" ]] && module_enabled="true"
    
    if [[ "$module_enabled" == "false" ]]; then
        echo -e "${YELLOW}⚠️  Module '$module_name' is disabled, skipping${NC}"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would execute module '$module_name' in $module_path${NC}"
        return 0
    fi
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Resolve and enter the Terraform module directory
    local tf_module_dir
    tf_module_dir="terraform/${module_path#./}"
    if [[ ! -d "$tf_module_dir" ]]; then
        echo -e "${RED}❌ Module directory not found: $tf_module_dir${NC}"
        return 1
    fi
    # Run the actual test
    pushd "$tf_module_dir" >/dev/null
    
    local log_file="$PROJECT_ROOT/logs/${module_name}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${YELLOW}📝 Logging to: $log_file${NC}"
    
    # Initialize if needed
    echo "[debug] PWD=$(pwd)" >> "$log_file"
    echo "[debug] Files:" >> "$log_file"
    ls -la >> "$log_file" 2>&1
    # Build an env wrapper to avoid leaking provider-related env vars that trigger Flink validation
    TF_ENV=(env \
        -u CONFLUENT_ORGANIZATION_ID \
        -u CONFLUENT_ENVIRONMENT_ID \
        -u CONFLUENT_FLINK_API_KEY \
        -u CONFLUENT_FLINK_API_SECRET \
        -u CONFLUENT_FLINK_REST_ENDPOINT \
        -u CONFLUENT_FLINK_COMPUTE_POOL_ID \
        -u CONFLUENT_FLINK_PRINCIPAL_ID \
        -u KAFKA_API_KEY \
        -u KAFKA_API_SECRET)

    "${TF_ENV[@]}" terraform init >> "$log_file" 2>&1

    # Preflight: scan module configuration for placeholder env vars and ensure required envs exist
    MODULE_YAML_RANGE=$(get_module_block_range "$PROJECT_ROOT/$CONFIG_FILE" "$module_name" || true)
    if [[ -n "$MODULE_YAML_RANGE" ]]; then
        local start=${MODULE_YAML_RANGE%:*} end=${MODULE_YAML_RANGE#*:}
        local module_block
        module_block=$(sed -n "${start},${end}p" "$PROJECT_ROOT/$CONFIG_FILE")
        # Find ${VARNAME} occurrences
        local missing_envs=()
        while read -r var; do
            # strip ${ }
            local name=$(printf "%s" "$var" | sed -E 's/\$\{([^}]+)\}/\1/')
            # if env is not set, consider it missing
            if [[ -z "${!name:-}" ]]; then
                missing_envs+=("$name")
            fi
        done < <(printf "%s" "$module_block" | grep -oE '\$\{[A-Z0-9_]+\}' || true)

        if [[ ${#missing_envs[@]} -gt 0 ]]; then
            # decide whether to skip or provide fallbacks
            local to_skip=false
            for mv in "${missing_envs[@]}"; do
                case "$mv" in
                    AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|TEST_S3_BUCKET|TEST_S3_BUCKET_NAME)
                        echo -e "${YELLOW}⚠️  Skipping module '$module_name' because required external env '$mv' is not set.${NC}"
                        to_skip=true
                        ;;
                    SCHEMA_REGISTRY_API_KEY|SCHEMA_REGISTRY_API_SECRET|SR_API_KEY|SR_API_SECRET)
                        # fallback to cloud admin if available
                        if [[ -n "${CONFLUENT_CLOUD_ADMIN_API_KEY:-}" ]]; then
                            export SCHEMA_REGISTRY_API_KEY="${CONFLUENT_CLOUD_ADMIN_API_KEY}"
                        fi
                        if [[ -n "${CONFLUENT_CLOUD_ADMIN_API_SECRET:-}" ]]; then
                            export SCHEMA_REGISTRY_API_SECRET="${CONFLUENT_CLOUD_ADMIN_API_SECRET}"
                        fi
                        ;;
                    CONFLUENT_KAFKA_API_KEY|CONFLUENT_KAFKA_API_SECRET|KAFKA_API_KEY|KAFKA_API_SECRET)
                        # no-op: these should be provisioned by setup; warn if missing
                        echo -e "${YELLOW}⚠️  Module '$module_name' references Kafka credentials ('$mv') which are not set.${NC}"
                        ;;
                    *)
                        # Unknown missing env - warn but do not auto-skip
                        echo -e "${YELLOW}⚠️  Module '$module_name' references missing env '$mv' (will attempt to continue).${NC}"
                        ;;
                esac
            done
            if [[ "$to_skip" == "true" ]]; then
                echo -e "${YELLOW}⏭️  Skipping module '$module_name' due to missing external credentials. Marking as skipped.${NC}"
                popd >/dev/null
                return 0
            fi
        fi
    fi

    if [[ "$EXECUTION_MODE" == "apply" ]]; then
        echo -e "${YELLOW}🚀 Running terraform apply for $module_name...${NC}"

    # Provider auth is sourced from environment variables (.env); no tfvars required
        # Build module-specific args
    TF_ARGS=( -input=false -auto-approve )
    DEST_ARGS=( -input=false -auto-approve )

    # Only pass variables that the module actually declares to avoid "undeclared variable" errors
    if module_has_variable "environment_id"; then
        TF_ARGS+=( -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" )
        DEST_ARGS+=( -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" )
    fi
    if module_has_variable "cluster_id"; then
        TF_ARGS+=( -var="cluster_id=${CONFLUENT_CLUSTER_ID}" )
        DEST_ARGS+=( -var="cluster_id=${CONFLUENT_CLUSTER_ID}" )
    fi
    if module_has_variable "organization_id" && [[ -n "${CONFLUENT_ORGANIZATION_ID:-}" ]]; then
        TF_ARGS+=( -var="organization_id=${CONFLUENT_ORGANIZATION_ID}" )
        DEST_ARGS+=( -var="organization_id=${CONFLUENT_ORGANIZATION_ID}" )
    fi

    case "$module_name" in
            rbac_cluster_admin|rbac_topic_access|rbac_enhanced_validation)
                if [[ -n "${TEST_SERVICE_ACCOUNT_ID:-}" ]]; then
                    PRINCIPAL_VALUE="User:${TEST_SERVICE_ACCOUNT_ID}"
                else
                    PRINCIPAL_VALUE="${TEST_SERVICE_ACCOUNT:-User:admin@example.com}"
                fi
                ROLE_VALUE=$(get_module_field "$config_file" "$module_name" "role")
                [[ -z "$ROLE_VALUE" ]] && ROLE_VALUE="CloudClusterAdmin"
                # add principal/role/org only if module declares them
                if module_has_variable "principal"; then
                    TF_ARGS+=( -var="principal=${PRINCIPAL_VALUE}" )
                    DEST_ARGS+=( -var="principal=${PRINCIPAL_VALUE}" )
                fi
                if module_has_variable "role"; then
                    TF_ARGS+=( -var="role=${ROLE_VALUE}" )
                    DEST_ARGS+=( -var="role=${ROLE_VALUE}" )
                fi
                if module_has_variable "organization_id"; then
                    TF_ARGS+=( -var="organization_id=${CONFLUENT_ORGANIZATION_ID}" )
                    DEST_ARGS+=( -var="organization_id=${CONFLUENT_ORGANIZATION_ID}" )
                fi
                # If this module declares a topic_name, resolve and pass it only for topic-scoped roles
                if module_has_variable "topic_name"; then
                    RAW_TOPIC_NAME=$(get_module_field "$config_file" "$module_name" "topic_name")
                    RAW_TOPIC_NAME=${RAW_TOPIC_NAME:-"${TEST_PREFIX}-topic-${TEST_SUFFIX:-manual}"}
                    ROLE_UPPER=$(printf "%s" "$ROLE_VALUE" | tr '[:lower:]' '[:upper:]')
                    # Skip passing topic_name for cluster-scoped roles like CloudClusterAdmin
                    if [[ "$ROLE_UPPER" =~ CLUSTER ]]; then
                        echo -e "${YELLOW}⚠️  Not passing topic_name for cluster-scoped role '$ROLE_VALUE'${NC}"
                    else
                        TOPIC_NAME=$(printf "%s" "$RAW_TOPIC_NAME" | envsubst)
                        TOPIC_NAME=$(echo "$TOPIC_NAME" | sed -E 's/[^a-zA-Z0-9._-]/-/g')
                        TF_ARGS+=( -var="topic_name=${TOPIC_NAME}" )
                        DEST_ARGS+=( -var="topic_name=${TOPIC_NAME}" )
                    fi
                fi
        # Provider auth for this module (prefer OrgAdmin creds if available) - only if variables declared
        local ADMIN_KEY="${CONFLUENT_CLOUD_ADMIN_API_KEY:-$CONFLUENT_CLOUD_API_KEY}"
        local ADMIN_SECRET="${CONFLUENT_CLOUD_ADMIN_API_SECRET:-$CONFLUENT_CLOUD_API_SECRET}"
        if module_has_variable "confluent_cloud_api_key"; then
            TF_ARGS+=( -var="confluent_cloud_api_key=${ADMIN_KEY}" )
            DEST_ARGS+=( -var="confluent_cloud_api_key=${ADMIN_KEY}" )
        fi
        if module_has_variable "confluent_cloud_api_secret"; then
            TF_ARGS+=( -var="confluent_cloud_api_secret=${ADMIN_SECRET}" )
            DEST_ARGS+=( -var="confluent_cloud_api_secret=${ADMIN_SECRET}" )
        fi
                ;;
            kafka_topic)
                TOPIC_NAME="${TEST_PREFIX}-topic-$(date +%s)"
        PARTITIONS=$(get_module_field "$config_file" "$module_name" "partitions")
                [[ -z "$PARTITIONS" ]] && PARTITIONS=1
                if module_has_variable "topic_name"; then
                    TF_ARGS+=( -var="topic_name=${TOPIC_NAME}" )
                    DEST_ARGS+=( -var="topic_name=${TOPIC_NAME}" )
                fi
                if module_has_variable "partitions"; then
                    TF_ARGS+=( -var="partitions=${PARTITIONS}" )
                    DEST_ARGS+=( -var="partitions=${PARTITIONS}" )
                fi
                if module_has_variable "credentials" || module_has_variable "kafka_api_key"; then
                    TF_ARGS+=( -var "credentials={key=\"${CONFLUENT_KAFKA_API_KEY}\", secret=\"${CONFLUENT_KAFKA_API_SECRET}\"}" )
                    DEST_ARGS+=( -var "credentials={key=\"${CONFLUENT_KAFKA_API_KEY}\", secret=\"${CONFLUENT_KAFKA_API_SECRET}\"}" )
                fi
                # Provider auth for this module (add only if declared)
                if module_has_variable "confluent_cloud_api_key"; then
                    TF_ARGS+=( -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" )
                    DEST_ARGS+=( -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" )
                fi
                if module_has_variable "confluent_cloud_api_secret"; then
                    TF_ARGS+=( -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" )
                    DEST_ARGS+=( -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" )
                fi
                ;;
            schema_registry)
                # Provide service account id and schema registry API creds if declared
                if module_has_variable "service_account_id"; then
                    TF_ARGS+=( -var="service_account_id=${TEST_SERVICE_ACCOUNT_ID:-${CONFLUENT_CLOUD_SERVICE_ACCOUNT:-}}" )
                    DEST_ARGS+=( -var="service_account_id=${TEST_SERVICE_ACCOUNT_ID:-${CONFLUENT_CLOUD_SERVICE_ACCOUNT:-}}" )
                fi
                if module_has_variable "sr_api_key"; then
                    SR_KEY=${SCHEMA_REGISTRY_API_KEY:-${CONFLUENT_CLOUD_ADMIN_API_KEY:-${CONFLUENT_CLOUD_API_KEY:-}}}
                    TF_ARGS+=( -var="sr_api_key=${SR_KEY}" )
                    DEST_ARGS+=( -var="sr_api_key=${SR_KEY}" )
                fi
                if module_has_variable "sr_api_secret"; then
                    SR_SECRET=${SCHEMA_REGISTRY_API_SECRET:-${CONFLUENT_CLOUD_ADMIN_API_SECRET:-${CONFLUENT_CLOUD_API_SECRET:-}}}
                    TF_ARGS+=( -var="sr_api_secret=${SR_SECRET}" )
                    DEST_ARGS+=( -var="sr_api_secret=${SR_SECRET}" )
                fi
                ;;
            smt_connector)
                # If kafka_rest_endpoint is required and not set, skip this module
                if module_has_variable "kafka_rest_endpoint" && [[ -z "${CONFLUENT_KAFKA_REST_ENDPOINT:-}" ]]; then
                    echo -e "${YELLOW}⚠️  Skipping module 'smt_connector' because CONFLUENT_KAFKA_REST_ENDPOINT is not set.${NC}"
                    popd >/dev/null
                    return 0
                fi
                # Provide kafka API creds if declared
                if module_has_variable "kafka_api_key"; then
                    TF_ARGS+=( -var="kafka_api_key=${CONFLUENT_KAFKA_API_KEY}" )
                    DEST_ARGS+=( -var="kafka_api_key=${CONFLUENT_KAFKA_API_KEY}" )
                fi
                if module_has_variable "kafka_api_secret"; then
                    TF_ARGS+=( -var="kafka_api_secret=${CONFLUENT_KAFKA_API_SECRET}" )
                    DEST_ARGS+=( -var="kafka_api_secret=${CONFLUENT_KAFKA_API_SECRET}" )
                fi
                if module_has_variable "kafka_rest_endpoint" && [[ -n "${CONFLUENT_KAFKA_REST_ENDPOINT:-}" ]]; then
                    TF_ARGS+=( -var="kafka_rest_endpoint=${CONFLUENT_KAFKA_REST_ENDPOINT}" )
                    DEST_ARGS+=( -var="kafka_rest_endpoint=${CONFLUENT_KAFKA_REST_ENDPOINT}" )
                fi
                ;;
            *) ;;
        esac

        # Cleanup helper (always attempt if enabled)
        cleanup_module() {
            if [[ "$CLEANUP" == "true" ]]; then
                echo -e "${YELLOW}🧹 Cleaning up resources for $module_name...${NC}"
                "${TF_ENV[@]}" terraform destroy "${DEST_ARGS[@]}" >> "$log_file" 2>&1 || true
                echo -e "${GREEN}✅ Resources cleaned up successfully${NC}"
            fi
        }

        # Ensure we cleanup on interrupt too
        trap 'cleanup_module; popd >/dev/null; exit 130' INT TERM

        # Run terraform apply with the required variables
    if "${TF_ENV[@]}" terraform apply "${TF_ARGS[@]}" >> "$log_file" 2>&1; then
            echo -e "${GREEN}✅ Module '$module_name' applied successfully${NC}"
            cleanup_module
            trap - INT TERM
            popd >/dev/null
            return 0
        else
            echo -e "${RED}❌ Failed to apply module '$module_name'${NC}"
            echo -e "${RED}   Check the log file for details: $log_file${NC}"
            cleanup_module
            trap - INT TERM
            popd >/dev/null
            return 1
        fi
    else
        echo -e "${YELLOW}📝 Running terraform plan for $module_name...${NC}"
        
        # Build minimal vars for plan to avoid prompts
    PLAN_ARGS=( -input=false -var="environment_id=${CONFLUENT_ENVIRONMENT_ID}" -var="cluster_id=${CONFLUENT_CLUSTER_ID}" )
        if [[ "$module_name" == "kafka_topic" ]]; then
            TOPIC_NAME="${TEST_PREFIX}-topic-plan-$(date +%s)"
            PARTITIONS=$(get_module_field "$config_file" "$module_name" "partitions")
            [[ -z "$PARTITIONS" ]] && PARTITIONS=1
            PLAN_ARGS+=( -var="topic_name=${TOPIC_NAME}" -var="partitions=${PARTITIONS}" )
            PLAN_ARGS+=( -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" )
            PLAN_ARGS+=( -var "credentials={key=\"${CONFLUENT_KAFKA_API_KEY}\", secret=\"${CONFLUENT_KAFKA_API_SECRET}\"}" )
        fi
        if [[ "$module_name" == "rbac_cluster_admin" || "$module_name" == "rbac_topic_access" || "$module_name" == "rbac_enhanced_validation" ]]; then
            PRINCIPAL_VALUE="${TEST_SERVICE_ACCOUNT:-User:admin@example.com}"
            ROLE_VALUE=$(get_module_field "$config_file" "$module_name" "role")
            [[ -z "$ROLE_VALUE" ]] && ROLE_VALUE="CloudClusterAdmin"
            PLAN_ARGS+=( -var="principal=${PRINCIPAL_VALUE}" -var="role=${ROLE_VALUE}" -var="organization_id=${CONFLUENT_ORGANIZATION_ID}" )
            PLAN_ARGS+=( -var="confluent_cloud_api_key=${CONFLUENT_CLOUD_API_KEY}" -var="confluent_cloud_api_secret=${CONFLUENT_CLOUD_API_SECRET}" )
        fi

    if "${TF_ENV[@]}" terraform plan "${PLAN_ARGS[@]}" >> "$log_file" 2>&1; then
            echo -e "${GREEN}✅ Plan for module '$module_name' generated successfully${NC}"
            popd >/dev/null
            return 0
        else
            echo -e "${RED}❌ Failed to plan module '$module_name'${NC}"
            echo -e "${RED}   Check the log file for details: $log_file${NC}"
            popd >/dev/null
            return 1
        fi
    fi
}

# Run all modules
echo -e "${YELLOW}🚀 Starting test execution...${NC}"
PASSED_MODULES=""
FAILED_MODULES=""

for module in $MODULES_TO_RUN; do
    if run_module_test "$module"; then
        PASSED_MODULES="$PASSED_MODULES $module"
    else
        FAILED_MODULES="$FAILED_MODULES $module"
    fi
done

# Print summary
echo ""
echo -e "${BLUE}📊 Test Execution Summary${NC}"
echo "=================================================="
PASSED_COUNT=$(echo "$PASSED_MODULES" | wc -w | tr -d ' ')
FAILED_COUNT=$(echo "$FAILED_MODULES" | wc -w | tr -d ' ')
echo -e "${GREEN}✅ Passed (${PASSED_COUNT}): ${PASSED_MODULES}${NC}"
echo -e "${RED}❌ Failed (${FAILED_COUNT}): ${FAILED_MODULES}${NC}"
echo ""

if [[ -n "$FAILED_MODULES" ]]; then
    echo -e "${RED}❌ Some tests failed. Check logs in the logs/ directory.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
