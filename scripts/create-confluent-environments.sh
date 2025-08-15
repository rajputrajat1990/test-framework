#!/bin/bash
# Environment and Cluster Creation Script
# Creates Confluent Cloud environments and clusters for testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Confluent CLI is installed
check_confluent_cli() {
    if ! command -v confluent &> /dev/null; then
        print_error "Confluent CLI is not installed"
        print_status "Install it from: https://docs.confluent.io/confluent-cli/current/install.html"
        exit 1
    fi
    print_success "Confluent CLI found"
}

# Login to Confluent Cloud
login_confluent() {
    print_status "Logging into Confluent Cloud..."
    
    if [ -n "$CONFLUENT_CLOUD_EMAIL" ] && [ -n "$CONFLUENT_CLOUD_PASSWORD" ]; then
        echo "$CONFLUENT_CLOUD_PASSWORD" | confluent login --save --username "$CONFLUENT_CLOUD_EMAIL"
    else
        print_warning "No credentials in environment variables"
        print_status "Please login manually:"
        confluent login --save
    fi
    
    print_success "Logged into Confluent Cloud"
}

# Create environment
create_environment() {
    local env_name="$1"
    local env_description="$2"
    
    print_status "Creating environment: $env_name"
    
    # Check if environment already exists
    if confluent environment list -o json | jq -r '.[].name' | grep -q "^$env_name$"; then
        local env_id=$(confluent environment list -o json | jq -r ".[] | select(.name == \"$env_name\") | .id")
        print_warning "Environment '$env_name' already exists with ID: $env_id"
        echo "$env_id"
        return
    fi
    
    # Create new environment
    local env_id=$(confluent environment create "$env_name" --output json | jq -r '.id')
    
    if [ -n "$env_id" ] && [ "$env_id" != "null" ]; then
        print_success "Environment created: $env_name (ID: $env_id)"
        echo "$env_id"
    else
        print_error "Failed to create environment: $env_name"
        exit 1
    fi
}

# Create Kafka cluster
create_cluster() {
    local env_id="$1"
    local cluster_name="$2"
    local cluster_type="$3"
    local cloud="$4"
    local region="$5"
    
    print_status "Creating cluster: $cluster_name in environment $env_id"
    
    # Use environment
    confluent environment use "$env_id"
    
    # Check if cluster already exists
    if confluent kafka cluster list -o json | jq -r '.[].name' | grep -q "^$cluster_name$"; then
        local cluster_id=$(confluent kafka cluster list -o json | jq -r ".[] | select(.name == \"$cluster_name\") | .id")
        print_warning "Cluster '$cluster_name' already exists with ID: $cluster_id"
        echo "$cluster_id"
        return
    fi
    
    # Create cluster based on type
    local cluster_id
    if [ "$cluster_type" = "basic" ]; then
        cluster_id=$(confluent kafka cluster create "$cluster_name" \
            --cloud "$cloud" \
            --region "$region" \
            --type basic \
            --output json | jq -r '.id')
    elif [ "$cluster_type" = "standard" ]; then
        cluster_id=$(confluent kafka cluster create "$cluster_name" \
            --cloud "$cloud" \
            --region "$region" \
            --type standard \
            --output json | jq -r '.id')
    else
        print_error "Invalid cluster type: $cluster_type"
        exit 1
    fi
    
    if [ -n "$cluster_id" ] && [ "$cluster_id" != "null" ]; then
        print_success "Cluster created: $cluster_name (ID: $cluster_id)"
        echo "$cluster_id"
    else
        print_error "Failed to create cluster: $cluster_name"
        exit 1
    fi
}

# Wait for cluster to be ready
wait_for_cluster() {
    local cluster_id="$1"
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for cluster $cluster_id to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        local status=$(confluent kafka cluster describe "$cluster_id" -o json | jq -r '.status')
        
        if [ "$status" = "UP" ]; then
            print_success "Cluster is ready!"
            return 0
        fi
        
        print_status "Cluster status: $status (attempt $attempt/$max_attempts)"
        sleep 30
        attempt=$((attempt + 1))
    done
    
    print_error "Cluster did not become ready within expected time"
    return 1
}

# Create API key for cluster
create_api_key() {
    local cluster_id="$1"
    local description="$2"
    
    print_status "Creating API key for cluster $cluster_id"
    
    local api_key_output=$(confluent api-key create \
        --resource "$cluster_id" \
        --description "$description" \
        --output json)
    
    local api_key=$(echo "$api_key_output" | jq -r '.key')
    local api_secret=$(echo "$api_key_output" | jq -r '.secret')
    
    if [ -n "$api_key" ] && [ "$api_key" != "null" ]; then
        print_success "API key created: $api_key"
        echo "$api_key:$api_secret"
    else
        print_error "Failed to create API key"
        exit 1
    fi
}

# Update configuration files
update_config_file() {
    local env_file="$1"
    local env_id="$2"
    local cluster_id="$3"
    local api_key="$4"
    local api_secret="$5"
    
    print_status "Updating configuration file: $env_file"
    
    # Create backup
    cp "$env_file" "${env_file}.backup"
    
    # Update environment ID
    sed -i.tmp "s/environment_id: .*/environment_id: \"$env_id\"/" "$env_file"
    
    # Update cluster ID  
    sed -i.tmp "s/cluster_id: .*/cluster_id: \"$cluster_id\"/" "$env_file"
    
    # Add API key information (commented for security)
    cat >> "$env_file" << EOF

# Generated API Credentials (Add to your secure environment variables)
# CONFLUENT_CLOUD_API_KEY: $api_key
# CONFLUENT_CLOUD_API_SECRET: $api_secret
EOF
    
    # Remove temporary files
    rm -f "${env_file}.tmp"
    
    print_success "Configuration file updated: $env_file"
}

# Main execution
main() {
    local create_dev="${CREATE_DEV:-true}"
    local create_staging="${CREATE_STAGING:-true}"
    local create_prod="${CREATE_PROD:-false}"
    
    echo "🚀 Confluent Cloud Environment Setup"
    echo "===================================="
    echo ""
    
    check_confluent_cli
    login_confluent
    
    # Create Development Environment
    if [ "$create_dev" = "true" ]; then
        print_status "Setting up Development Environment..."
        
        dev_env_id=$(create_environment "test-framework-dev" "Development environment for testing framework")
        dev_cluster_id=$(create_cluster "$dev_env_id" "dev-test-cluster" "basic" "aws" "us-west-2")
        
        wait_for_cluster "$dev_cluster_id"
        dev_api_credentials=$(create_api_key "$dev_cluster_id" "Development API Key")
        
        # Update dev.yaml
        update_config_file "$PROJECT_ROOT/config/environments/dev.yaml" \
            "$dev_env_id" "$dev_cluster_id" \
            "${dev_api_credentials%:*}" "${dev_api_credentials#*:}"
    fi
    
    # Create Staging Environment
    if [ "$create_staging" = "true" ]; then
        print_status "Setting up Staging Environment..."
        
        staging_env_id=$(create_environment "test-framework-staging" "Staging environment for pre-production testing")
        staging_cluster_id=$(create_cluster "$staging_env_id" "staging-test-cluster" "standard" "aws" "us-west-2")
        
        wait_for_cluster "$staging_cluster_id"
        staging_api_credentials=$(create_api_key "$staging_cluster_id" "Staging API Key")
        
        # Update staging.yaml
        update_config_file "$PROJECT_ROOT/config/environments/staging.yaml" \
            "$staging_env_id" "$staging_cluster_id" \
            "${staging_api_credentials%:*}" "${staging_api_credentials#*:}"
    fi
    
    # Create Production Environment (only if explicitly requested)
    if [ "$create_prod" = "true" ]; then
        print_warning "Creating Production Environment - Use with caution!"
        
        prod_env_id=$(create_environment "test-framework-prod" "Production environment for final testing")
        prod_cluster_id=$(create_cluster "$prod_env_id" "prod-test-cluster" "standard" "aws" "us-west-2")
        
        wait_for_cluster "$prod_cluster_id"
        prod_api_credentials=$(create_api_key "$prod_cluster_id" "Production API Key")
        
        # Create prod config if it doesn't exist
        if [ ! -f "$PROJECT_ROOT/config/environments/prod.yaml" ]; then
            cp "$PROJECT_ROOT/config/environments/staging.yaml" "$PROJECT_ROOT/config/environments/prod.yaml"
        fi
        
        update_config_file "$PROJECT_ROOT/config/environments/prod.yaml" \
            "$prod_env_id" "$prod_cluster_id" \
            "${prod_api_credentials%:*}" "${prod_api_credentials#*:}"
    fi
    
    print_success "Environment setup completed!"
    echo ""
    echo "📋 Summary:"
    [ "$create_dev" = "true" ] && echo "   Development: $dev_env_id / $dev_cluster_id"
    [ "$create_staging" = "true" ] && echo "   Staging: $staging_env_id / $staging_cluster_id"
    [ "$create_prod" = "true" ] && echo "   Production: $prod_env_id / $prod_cluster_id"
    echo ""
    echo "🔐 Security Note:"
    echo "   API credentials have been added as comments to config files"
    echo "   Add them to your environment variables or CI/CD settings"
    echo "   Remove them from config files before committing to version control"
    echo ""
    echo "🔧 Next Steps:"
    echo "   1. Update your .env file with the API credentials"
    echo "   2. Test the connection: confluent kafka cluster list"
    echo "   3. Run the test framework: ./scripts/quick-start.sh"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-dev)
            CREATE_DEV="false"
            shift
            ;;
        --no-staging)
            CREATE_STAGING="false"  
            shift
            ;;
        --include-prod)
            CREATE_PROD="true"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-dev          Skip development environment creation"
            echo "  --no-staging      Skip staging environment creation" 
            echo "  --include-prod    Create production environment (use with caution)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main "$@"
