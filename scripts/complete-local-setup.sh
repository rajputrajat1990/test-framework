#!/bin/bash
# Complete Local Setup for Confluent Test Framework with GitLab
# This script sets up everything you need to run the CI/CD pipeline locally

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

print_header() {
    echo -e "${BLUE}"
    echo "========================================="
    echo "$1"
    echo "========================================="
    echo -e "${NC}"
}

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

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("Docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("Docker Compose")
    fi
    
    # Check available memory
    local available_mem=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_mem" -lt 4000 ]; then
        print_warning "Available memory is ${available_mem}MB. GitLab requires at least 4GB free memory."
    fi
    
    # Check disk space
    local available_disk=$(df -m . | awk 'NR==2{print $4}')
    if [ "$available_disk" -lt 10000 ]; then
        print_warning "Available disk space is ${available_disk}MB. Recommended: 20GB+"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Setup environment file
setup_environment() {
    print_header "Setting Up Environment"
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        print_status "Creating environment file from template..."
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        print_warning "Please edit .env file with your Confluent Cloud credentials"
        print_status "You can do this now or after the GitLab setup"
    else
        print_success "Environment file already exists"
    fi
}

# Setup GitLab
setup_gitlab() {
    print_header "Setting Up Local GitLab"
    
    print_status "Starting GitLab setup process..."
    
    if ! "$SCRIPT_DIR/setup-local-gitlab.sh"; then
        print_error "GitLab setup failed"
        return 1
    fi
    
    print_success "GitLab setup completed"
}

# Create Confluent environments (optional)
setup_confluent_environments() {
    print_header "Confluent Cloud Environment Setup"
    
    echo ""
    print_status "Do you want to create new Confluent Cloud environments and clusters?"
    print_warning "This requires Confluent Cloud credentials and will create billable resources"
    print_status "Alternatively, you can use existing environment/cluster IDs in config files"
    echo ""
    
    read -p "Create new environments? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Checking for Confluent CLI..."
        
        if ! command -v confluent &> /dev/null; then
            print_status "Installing Confluent CLI..."
            curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
            export PATH="$HOME/.local/bin:$PATH"
        fi
        
        if "$SCRIPT_DIR/create-confluent-environments.sh"; then
            print_success "Confluent environments created successfully"
        else
            print_warning "Failed to create environments. You can do this manually later."
        fi
    else
        print_status "Skipping environment creation"
        print_status "Remember to update config files with your existing environment/cluster IDs"
    fi
}

# Setup GitLab project
setup_gitlab_project() {
    print_header "GitLab Project Setup"
    
    print_status "Setting up GitLab project with test framework..."
    
    # Wait for GitLab to be fully ready
    print_status "Waiting for GitLab to be fully ready..."
    sleep 30
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://gitlab.local:8080/api/v4/projects" > /dev/null 2>&1; then
            break
        fi
        print_status "GitLab API not ready yet, waiting... (attempt $attempt/$max_attempts)"
        sleep 15
        attempt=$((attempt + 1))
    done
    
    # Create project directory for GitLab
    local gitlab_project_dir="$PROJECT_ROOT/gitlab-projects/confluent-test-framework"
    
    if [ ! -d "$gitlab_project_dir" ]; then
        print_status "Creating GitLab project directory..."
        mkdir -p "$gitlab_project_dir"
        
        # Copy all project files except .git and docker-compose
        rsync -av --exclude='.git' --exclude='gitlab-projects' --exclude='docker-compose.gitlab.yml' \
              "$PROJECT_ROOT/" "$gitlab_project_dir/"
        
        # Initialize git repository
        cd "$gitlab_project_dir"
        git init
        git add .
        git commit -m "Initial commit - Confluent Test Framework"
        
        print_success "GitLab project directory created"
    else
        print_success "GitLab project directory already exists"
    fi
    
    cd "$PROJECT_ROOT"
}

# Print completion information
print_completion_info() {
    print_header "Setup Complete! 🎉"
    
    echo ""
    echo "✅ Local GitLab Environment:"
    echo "   URL: http://gitlab.local:8080"
    echo "   Username: root"
    echo "   Password: rootpassword123"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. 🔐 Configure Credentials:"
    echo "   - Edit .env file with your Confluent Cloud credentials"
    echo "   - Or create new environments with: ./scripts/create-confluent-environments.sh"
    echo ""
    echo "2. 🚀 Create GitLab Project:"
    echo "   - Login to http://gitlab.local:8080"
    echo "   - Create new project: 'confluent-test-framework'"
    echo "   - Push code from: ./gitlab-projects/confluent-test-framework/"
    echo ""
    echo "3. ⚙️ Configure CI/CD Variables in GitLab Project:"
    echo "   Go to: Settings > CI/CD > Variables and add:"
    echo "   - CONFLUENT_API_KEY"
    echo "   - CONFLUENT_API_SECRET"  
    echo "   - CONFLUENT_ENVIRONMENT_ID"
    echo "   - CONFLUENT_CLUSTER_ID"
    echo ""
    echo "4. 🧪 Test Pipeline:"
    echo "   - Push .gitlab-ci.yml to trigger pipeline"
    echo "   - Monitor in GitLab: CI/CD > Pipelines"
    echo ""
    echo "🛠️ Useful Commands:"
    echo "   - Manage GitLab: ./scripts/manage-gitlab.sh [start|stop|status|logs]"
    echo "   - Register runners: ./scripts/setup-runners.sh <token>"
    echo "   - Run tests locally: ./scripts/run-unit-tests.sh"
    echo ""
    echo "📚 Documentation:"
    echo "   - Local GitLab Guide: ./LOCAL_GITLAB_SETUP.md"
    echo "   - Framework Guide: ./README.md"
    echo ""
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        print_warning "Don't forget to update the .env file with your actual credentials!"
    fi
}

# Main execution
main() {
    echo ""
    print_header "Confluent Test Framework - Complete Local Setup"
    echo ""
    print_status "This script will set up:"
    echo "   - Local GitLab CE with runners"
    echo "   - Environment configuration"
    echo "   - Confluent Cloud environments (optional)"
    echo "   - GitLab project structure"
    echo ""
    
    read -p "Continue with setup? (Y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi
    
    cd "$PROJECT_ROOT"
    
    check_prerequisites
    setup_environment
    setup_gitlab
    setup_confluent_environments
    setup_gitlab_project
    print_completion_info
    
    print_success "Complete setup finished successfully! 🚀"
}

# Error handling
trap 'print_error "Setup failed at line $LINENO. Check the logs above."' ERR

# Run main function
main "$@"
