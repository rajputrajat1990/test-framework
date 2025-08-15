#!/bin/bash

# Terraform Upgrade and Service Account Validation Script
# This script validates the new automated service account setup

set -e

echo "🚀 Validating Terraform Upgrade and Automated Service Account Setup"
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check Terraform version
echo -e "\n1. Checking Terraform version..."
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
REQUIRED_VERSION="1.12.2"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    print_status 0 "Terraform version $TERRAFORM_VERSION meets requirement (>= $REQUIRED_VERSION)"
else
    print_status 1 "Terraform version $TERRAFORM_VERSION does not meet requirement (>= $REQUIRED_VERSION)"
    echo "  Please upgrade Terraform to version $REQUIRED_VERSION or later"
    exit 1
fi

# Check for required environment variables or files
echo -e "\n2. Checking configuration..."

if [ -f "terraform.tfvars" ]; then
    print_status 0 "terraform.tfvars file exists"
    
    # Check for required variables
    if grep -q "confluent_cloud_api_key" terraform.tfvars; then
        print_status 0 "Bootstrap API key configured"
    else
        print_status 1 "Bootstrap API key not configured in terraform.tfvars"
    fi
    
    if grep -q "organization_id" terraform.tfvars; then
        print_status 0 "Organization ID configured"
    else
        print_status 1 "Organization ID not configured in terraform.tfvars"
    fi
    
else
    print_status 1 "terraform.tfvars file not found"
    print_warning "Create terraform.tfvars with required variables"
fi

# Check provider versions in main.tf
echo -e "\n3. Checking provider versions..."

if [ -f "main.tf" ] || [ -f "terraform/shared/main.tf" ]; then
    MAIN_FILE="main.tf"
    if [ -f "terraform/shared/main.tf" ]; then
        MAIN_FILE="terraform/shared/main.tf"
    fi
    
    # Check Confluent provider version
    if grep -q "version.*2\.37\.0" "$MAIN_FILE"; then
        print_status 0 "Confluent provider version updated to ~> 2.37.0"
    else
        print_status 1 "Confluent provider version needs updating to ~> 2.37.0"
    fi
    
    # Check Random provider version
    if grep -q -A 5 "hashicorp/random" "$MAIN_FILE" | grep -q "3\.7\.2"; then
        print_status 0 "Random provider version updated to ~> 3.7.2"
    else
        print_status 1 "Random provider version needs updating to ~> 3.7.2"
    fi
    
    # Check Time provider version
    if grep -q -A 5 "hashicorp/time" "$MAIN_FILE" | grep -q "0\.13\.1"; then
        print_status 0 "Time provider version updated to ~> 0.13.1"
    else
        print_status 1 "Time provider version needs updating to ~> 0.13.1"
    fi
    
else
    print_status 1 "Main Terraform file not found"
fi

# Check for automated service account module
echo -e "\n4. Checking automated service account module..."

if [ -d "terraform/modules/automated-service-account" ] || [ -d "modules/automated-service-account" ]; then
    MODULE_DIR="modules/automated-service-account"
    if [ -d "terraform/modules/automated-service-account" ]; then
        MODULE_DIR="terraform/modules/automated-service-account"
    fi
    
    print_status 0 "Automated service account module directory exists"
    
    # Check for required module files
    for file in "main.tf" "variables.tf" "outputs.tf"; do
        if [ -f "$MODULE_DIR/$file" ]; then
            print_status 0 "Module file $file exists"
        else
            print_status 1 "Module file $file missing"
        fi
    done
    
else
    print_status 1 "Automated service account module not found"
    print_warning "Make sure the module is in terraform/modules/automated-service-account/"
fi

# Test terraform init
echo -e "\n5. Testing Terraform initialization..."

# Change to terraform directory if it exists
if [ -d "terraform/shared" ]; then
    cd terraform/shared
elif [ -d "terraform" ]; then
    cd terraform
fi

if terraform init -upgrade > /dev/null 2>&1; then
    print_status 0 "Terraform initialization successful"
else
    print_status 1 "Terraform initialization failed"
    print_warning "Run 'terraform init -upgrade' manually to see detailed errors"
fi

# Test terraform validate
echo -e "\n6. Validating Terraform configuration..."

if terraform validate > /dev/null 2>&1; then
    print_status 0 "Terraform configuration is valid"
else
    print_status 1 "Terraform configuration validation failed"
    print_warning "Run 'terraform validate' manually to see detailed errors"
fi

# Check for Confluent CLI (optional)
echo -e "\n7. Checking Confluent CLI (optional)..."

if command -v confluent &> /dev/null; then
    CONFLUENT_VERSION=$(confluent version | grep "Version:" | awk '{print $2}')
    print_status 0 "Confluent CLI version $CONFLUENT_VERSION available"
    
    # Test authentication if possible
    if confluent organization list &> /dev/null; then
        print_status 0 "Confluent CLI authentication working"
    else
        print_warning "Confluent CLI not authenticated or network issues"
    fi
else
    print_warning "Confluent CLI not installed (optional for manual verification)"
fi

# Summary and next steps
echo -e "\n=================================================================="
echo "🎯 Validation Summary"
echo "=================================================================="

echo -e "\nNext Steps:"
echo "1. Review any failed checks above"
echo "2. Create/update terraform.tfvars with your bootstrap API key"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
echo "5. Verify service accounts created in Confluent Cloud UI"

echo -e "\nRequired terraform.tfvars format:"
echo "================================="
echo "confluent_cloud_api_key    = \"YOUR_BOOTSTRAP_API_KEY\""
echo "confluent_cloud_api_secret = \"YOUR_BOOTSTRAP_API_SECRET\""
echo "organization_id            = \"your-org-id\""
echo "environment_id             = \"env-12345\""
echo "cluster_id                 = \"lkc-12345\""

echo -e "\n📚 Documentation:"
echo "- Migration guide: docs/terraform-upgrade-guide.md"
echo "- Module README: terraform/modules/automated-service-account/README.md"
echo "- Examples: terraform/examples/automated-service-accounts.tf"

echo -e "\n✨ Benefits after migration:"
echo "- Automated service account creation"
echo "- No manual API key management"
echo "- Proper RBAC role assignment"
echo "- Better security and governance"

echo -e "\nValidation complete! 🎉"
