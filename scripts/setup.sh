#!/bin/bash

# Terraform Test Framework Setup Script
# This script initializes the test framework environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Setting up Confluent Cloud Terraform Test Framework${NC}"
echo "=================================================="

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check Terraform version
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install Terraform >= 1.6.0${NC}"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | sed 's/.*v\([0-9.]*\).*/\1/')
REQUIRED_VERSION="1.6.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}❌ Terraform version $TERRAFORM_VERSION is too old. Required: >= $REQUIRED_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Terraform $TERRAFORM_VERSION is compatible${NC}"

# Check for required tools
for tool in jq curl; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${YELLOW}⚠️  $tool is not installed. Some features may not work properly.${NC}"
    else
        echo -e "${GREEN}✅ $tool is available${NC}"
    fi
done

# Check environment variables
echo -e "${YELLOW}🔐 Checking environment variables...${NC}"

REQUIRED_VARS=(
    "CONFLUENT_CLOUD_API_KEY"
    "CONFLUENT_CLOUD_API_SECRET" 
    "CONFLUENT_ENVIRONMENT_ID"
    "CONFLUENT_CLUSTER_ID"
    "CONFLUENT_ORGANIZATION_ID"
)

OPTIONAL_VARS=(
    "TEST_S3_BUCKET"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "CONFLUENT_KAFKA_API_KEY"
    "CONFLUENT_KAFKA_API_SECRET"
    "TEST_SERVICE_ACCOUNT"
)

missing_vars=()
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    else
        echo -e "${GREEN}✅ $var is set${NC}"
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "${RED}   - $var${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 Please set these environment variables before running tests:${NC}"
    echo ""
    echo "export CONFLUENT_CLOUD_API_KEY=\"your-api-key\""
    echo "export CONFLUENT_CLOUD_API_SECRET=\"your-api-secret\""
    echo "export CONFLUENT_ENVIRONMENT_ID=\"env-xxxxx\""
    echo "export CONFLUENT_CLUSTER_ID=\"lkc-xxxxx\""
    echo "export CONFLUENT_ORGANIZATION_ID=\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\""
    echo ""
    exit 1
fi

# Check optional variables
echo -e "${YELLOW}📝 Optional environment variables:${NC}"
for var in "${OPTIONAL_VARS[@]}"; do
    if [[ -n "${!var}" ]]; then
        echo -e "${GREEN}✅ $var is set${NC}"
    else
        echo -e "${YELLOW}⚠️  $var is not set (optional)${NC}"
    fi
done

# Initialize Terraform in shared directory
echo -e "${YELLOW}🔧 Initializing Terraform configurations...${NC}"

cd "$PROJECT_ROOT/terraform/shared"
echo "Initializing shared configuration..."
terraform init

# Initialize modules
cd "$PROJECT_ROOT/terraform/modules"
for module_dir in */; do
    if [[ -d "$module_dir" ]]; then
        echo "Initializing module: $module_dir"
        cd "$module_dir"
        terraform init
        cd ..
    fi
done

# Validate configurations
echo -e "${YELLOW}🔍 Validating Terraform configurations...${NC}"

cd "$PROJECT_ROOT/terraform/shared"
if terraform validate; then
    echo -e "${GREEN}✅ Shared configuration is valid${NC}"
else
    echo -e "${RED}❌ Shared configuration validation failed${NC}"
    exit 1
fi

cd "$PROJECT_ROOT/terraform/modules"
for module_dir in */; do
    if [[ -d "$module_dir" ]]; then
        cd "$module_dir"
        if terraform validate; then
            echo -e "${GREEN}✅ Module $module_dir is valid${NC}"
        else
            echo -e "${RED}❌ Module $module_dir validation failed${NC}"
            exit 1
        fi
        cd ..
    fi
done

# Test Confluent Cloud connectivity
echo -e "${YELLOW}🌐 Testing Confluent Cloud connectivity...${NC}"

cd "$PROJECT_ROOT/terraform/shared"
# Build terraform plan command non-interactively
plan_cmd=(terraform plan -input=false \
    -var="confluent_cloud_api_key=$CONFLUENT_CLOUD_API_KEY" \
    -var="confluent_cloud_api_secret=$CONFLUENT_CLOUD_API_SECRET" \
    -var="organization_id=$CONFLUENT_ORGANIZATION_ID" \
    -var="environment_id=$CONFLUENT_ENVIRONMENT_ID" \
    -var="cluster_id=$CONFLUENT_CLUSTER_ID")

# Work around provider validation that auto-reads env vars for Flink by unsetting them for this subprocess
unset_env_flags=(
    -u CONFLUENT_ORGANIZATION_ID \
    -u CONFLUENT_ENVIRONMENT_ID \
    -u CONFLUENT_FLINK_API_KEY \
    -u CONFLUENT_FLINK_API_SECRET \
    -u CONFLUENT_FLINK_REST_ENDPOINT \
    -u CONFLUENT_FLINK_COMPUTE_POOL_ID \
    -u CONFLUENT_FLINK_PRINCIPAL_ID
)

if env ${unset_env_flags[@]} "${plan_cmd[@]}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Confluent Cloud connectivity test passed${NC}"
else
    echo -e "${RED}❌ Confluent Cloud connectivity test failed${NC}"
    echo "Please verify your API credentials and environment/cluster IDs"
    echo "If your Terraform configuration requires an organization_id variable, set CONFLUENT_ORGANIZATION_ID in your .env or environment."
    exit 1
fi

# Create test directories
echo -e "${YELLOW}📁 Creating test directories...${NC}"
mkdir -p "$PROJECT_ROOT/test-results"
mkdir -p "$PROJECT_ROOT/logs"

# Set TEST_EXECUTION_MODE if not set
if [[ -z "$TEST_EXECUTION_MODE" ]]; then
    export TEST_EXECUTION_MODE="apply"
    echo -e "${YELLOW}💡 TEST_EXECUTION_MODE not set, defaulting to 'apply'${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo "=================================================="
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run tests: ./scripts/test-runner.sh --config config/modules.yaml --env dev"
echo "2. Run specific module: ./scripts/test-runner.sh --module kafka_topic --env dev"
echo "3. View logs in: logs/"
echo "4. View results in: test-results/"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "- Architecture: docs/architecture.md"
echo "- User Guide: docs/user-guide.md"
echo ""

cd "$PROJECT_ROOT"
