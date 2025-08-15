#!/bin/bash
# GitLab Local Setup Script
# Sets up GitLab CE with runners for local CI/CD testing

set -e

echo "🚀 Setting up Local GitLab CE Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITLAB_HOST="gitlab.local"
GITLAB_PORT="8080"
ROOT_PASSWORD="rootpassword123"
ADMIN_TOKEN=""

# Function to print colored output
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

# Check if Docker and Docker Compose are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Add GitLab hostname to /etc/hosts
setup_hostname() {
    print_status "Setting up hostname..."
    
    if ! grep -q "$GITLAB_HOST" /etc/hosts; then
        echo "127.0.0.1 $GITLAB_HOST" | sudo tee -a /etc/hosts
        print_success "Added $GITLAB_HOST to /etc/hosts"
    else
        print_warning "$GITLAB_HOST already exists in /etc/hosts"
    fi
}

# Start GitLab services
start_gitlab() {
    print_status "Starting GitLab services..."
    
    # Stop any existing services
    docker-compose -f docker-compose.gitlab.yml down
    
    # Start services
    docker-compose -f docker-compose.gitlab.yml up -d
    
    print_success "GitLab services started"
    print_status "GitLab is starting up... This may take 5-10 minutes"
    print_status "You can check the logs with: docker-compose -f docker-compose.gitlab.yml logs -f gitlab"
}

# Wait for GitLab to be ready
wait_for_gitlab() {
    print_status "Waiting for GitLab to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://$GITLAB_HOST:$GITLAB_PORT/-/readiness" > /dev/null 2>&1; then
            print_success "GitLab is ready!"
            break
        fi
        
        echo -n "."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "GitLab failed to start within expected time"
        print_status "Check logs: docker-compose -f docker-compose.gitlab.yml logs gitlab"
        exit 1
    fi
}

# Get registration token
get_registration_token() {
    print_status "Getting runner registration token..."
    
    # Wait a bit more for GitLab internal setup
    sleep 30
    
    # Get the registration token from GitLab container
    REGISTRATION_TOKEN=$(docker exec gitlab-ce gitlab-rails runner -e production "puts Gitlab::CurrentSettings.runners_registration_token" 2>/dev/null)
    
    if [ -z "$REGISTRATION_TOKEN" ]; then
        print_warning "Could not get registration token automatically"
        print_status "You'll need to get it manually from GitLab Admin > CI/CD > Runners"
        print_status "GitLab URL: http://$GITLAB_HOST:$GITLAB_PORT"
        print_status "Username: root"
        print_status "Password: $ROOT_PASSWORD"
        return 1
    fi
    
    print_success "Registration token: $REGISTRATION_TOKEN"
}

# Register GitLab Runners
register_runners() {
    print_status "Registering GitLab Runners..."
    
    if [ -z "$REGISTRATION_TOKEN" ]; then
        print_warning "No registration token available. Skipping runner registration."
        print_status "You can register runners manually later using the setup_runners.sh script"
        return
    fi
    
    # Register Shell Runner
    print_status "Registering shell runner..."
    docker exec gitlab-runner-shell gitlab-runner register \
        --non-interactive \
        --url "http://gitlab.local" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "shell" \
        --description "Shell Runner for Terraform" \
        --tag-list "shell,terraform,linux" \
        --run-untagged="true" \
        --locked="false" \
        --access-level="not_protected"
    
    # Register Docker Runner
    print_status "Registering docker runner..."
    docker exec gitlab-runner-docker gitlab-runner register \
        --non-interactive \
        --url "http://gitlab.local" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "docker" \
        --description "Docker Runner for Tests" \
        --tag-list "docker,tests,containers" \
        --run-untagged="true" \
        --locked="false" \
        --access-level="not_protected" \
        --docker-image "alpine:latest" \
        --docker-privileged="true" \
        --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"
    
    # Register Kubernetes Runner (if minikube is available)
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        print_status "Registering kubernetes runner..."
        docker exec gitlab-runner-k8s gitlab-runner register \
            --non-interactive \
            --url "http://gitlab.local" \
            --registration-token "$REGISTRATION_TOKEN" \
            --executor "kubernetes" \
            --description "Kubernetes Runner for Advanced Tests" \
            --tag-list "k8s,kubernetes,advanced" \
            --run-untagged="false" \
            --locked="false" \
            --access-level="not_protected"
    else
        print_warning "Kubernetes not available, skipping k8s runner registration"
    fi
    
    print_success "Runners registered successfully"
}

# Create initial project
setup_initial_project() {
    print_status "Setting up initial project..."
    
    # Create project directory structure
    mkdir -p gitlab-projects/confluent-test-framework
    
    # Copy the test framework files (if they exist)
    if [ -d "terraform" ] && [ -f ".gitlab-ci.yml" ]; then
        print_status "Copying test framework to GitLab project directory..."
        cp -r . gitlab-projects/confluent-test-framework/
        
        # Initialize git repo
        cd gitlab-projects/confluent-test-framework
        git init
        git add .
        git commit -m "Initial commit - Confluent Test Framework"
        cd ../..
        
        print_success "Project structure created"
    else
        print_warning "Test framework files not found in current directory"
    fi
}

# Print setup completion info
print_completion_info() {
    echo ""
    print_success "GitLab Local Environment Setup Complete!"
    echo ""
    echo "📋 Access Information:"
    echo "   GitLab URL: http://$GITLAB_HOST:$GITLAB_PORT"
    echo "   Username: root"
    echo "   Password: $ROOT_PASSWORD"
    echo ""
    echo "🏃‍♂️ Runners Available:"
    echo "   - Shell Runner (Tags: shell, terraform, linux)"
    echo "   - Docker Runner (Tags: docker, tests, containers)"
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        echo "   - Kubernetes Runner (Tags: k8s, kubernetes, advanced)"
    fi
    echo ""
    echo "📂 Container Registry: http://$GITLAB_HOST:5050"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   Start services: docker-compose -f docker-compose.gitlab.yml up -d"
    echo "   Stop services: docker-compose -f docker-compose.gitlab.yml down"
    echo "   View logs: docker-compose -f docker-compose.gitlab.yml logs -f"
    echo "   Restart GitLab: docker-compose -f docker-compose.gitlab.yml restart gitlab"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Access GitLab at http://$GITLAB_HOST:$GITLAB_PORT"
    echo "   2. Login with root/$ROOT_PASSWORD"
    echo "   3. Create a new project or import existing repository"
    echo "   4. Configure CI/CD variables in Project > Settings > CI/CD"
    echo "   5. Add your .gitlab-ci.yml file to trigger pipelines"
    echo ""
    
    if [ -z "$REGISTRATION_TOKEN" ]; then
        print_warning "Runner registration was skipped"
        echo "   To register runners manually:"
        echo "   1. Get registration token from Admin Area > CI/CD > Runners"
        echo "   2. Run: ./scripts/setup_runners.sh <token>"
    fi
}

# Main execution
main() {
    echo "🔧 GitLab CE Local Setup"
    echo "======================="
    echo ""
    
    check_prerequisites
    setup_hostname
    start_gitlab
    wait_for_gitlab
    
    if get_registration_token; then
        register_runners
    fi
    
    setup_initial_project
    print_completion_info
}

# Run main function
main "$@"
