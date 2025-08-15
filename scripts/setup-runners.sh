#!/bin/bash
# GitLab Runners Setup Script
# Registers runners with GitLab instance

set -e

# Configuration
GITLAB_URL="http://gitlab.local"
REGISTRATION_TOKEN="$1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -z "$REGISTRATION_TOKEN" ]; then
    print_error "Usage: $0 <registration-token>"
    echo ""
    echo "To get the registration token:"
    echo "1. Login to GitLab: http://gitlab.local:8080"
    echo "2. Go to Admin Area > CI/CD > Runners"
    echo "3. Copy the registration token"
    exit 1
fi

print_status "Registering GitLab Runners with token: $REGISTRATION_TOKEN"

# Register Shell Runner
print_status "Registering Shell Runner..."
docker exec gitlab-runner-shell gitlab-runner register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "shell" \
    --description "Shell Runner for Terraform Commands" \
    --tag-list "shell,terraform,linux,confluent" \
    --run-untagged="true" \
    --locked="false" \
    --access-level="not_protected"

# Register Docker Runner
print_status "Registering Docker Runner..."
docker exec gitlab-runner-docker gitlab-runner register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "docker" \
    --description "Docker Runner for Containerized Tests" \
    --tag-list "docker,tests,containers,confluent" \
    --run-untagged="true" \
    --locked="false" \
    --access-level="not_protected" \
    --docker-image "hashicorp/terraform:1.6.0" \
    --docker-privileged="true" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-volumes "/cache:/cache"

# Register Kubernetes Runner (if kubectl is available)
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    print_status "Registering Kubernetes Runner..."
    docker exec gitlab-runner-k8s gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "kubernetes" \
        --description "Kubernetes Runner for Scalable Testing" \
        --tag-list "k8s,kubernetes,advanced,confluent" \
        --run-untagged="false" \
        --locked="false" \
        --access-level="not_protected"
    print_success "Kubernetes Runner registered"
else
    print_status "Kubernetes not available, skipping K8s runner"
fi

print_success "All available runners registered successfully!"
print_status "You can verify registration in GitLab: Admin Area > CI/CD > Runners"
