#!/bin/bash
# GitLab Management Script
# Provides common operations for local GitLab instance

set -e

# Configuration
GITLAB_HOST="gitlab.local"
GITLAB_PORT="8080"
COMPOSE_FILE="docker-compose.gitlab.yml"

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

# Show help
show_help() {
    cat << EOF
GitLab Local Management Script

Usage: $0 <command> [options]

Commands:
    start           Start GitLab services
    stop            Stop GitLab services
    restart         Restart GitLab services
    status          Show service status
    logs            Show GitLab logs
    backup          Create backup of GitLab data
    restore         Restore from backup
    reset           Reset GitLab (removes all data)
    url             Show GitLab access URL
    token           Get registration token
    runners         Show runner status
    cleanup         Remove unused Docker resources
    update          Update GitLab to latest version

Options:
    -f, --follow    Follow logs output (for logs command)
    -h, --help      Show this help message

Examples:
    $0 start                    # Start GitLab
    $0 logs -f                 # Follow GitLab logs
    $0 backup                  # Create backup
    $0 reset                   # Reset everything
EOF
}

# Check if compose file exists
check_compose_file() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker compose file not found: $COMPOSE_FILE"
        print_status "Make sure you're in the correct directory"
        exit 1
    fi
}

# Start services
start_services() {
    print_status "Starting GitLab services..."
    check_compose_file
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_success "GitLab services started"
    print_status "GitLab will be available at: http://$GITLAB_HOST:$GITLAB_PORT"
    print_status "Initial login: root / rootpassword123"
}

# Stop services
stop_services() {
    print_status "Stopping GitLab services..."
    check_compose_file
    
    docker-compose -f "$COMPOSE_FILE" down
    
    print_success "GitLab services stopped"
}

# Restart services
restart_services() {
    print_status "Restarting GitLab services..."
    check_compose_file
    
    docker-compose -f "$COMPOSE_FILE" restart
    
    print_success "GitLab services restarted"
}

# Show service status
show_status() {
    print_status "GitLab service status:"
    check_compose_file
    
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    print_status "GitLab health check:"
    if curl -s -f "http://$GITLAB_HOST:$GITLAB_PORT/-/readiness" > /dev/null 2>&1; then
        print_success "GitLab is healthy and ready"
    else
        print_warning "GitLab is not ready or not responding"
    fi
}

# Show logs
show_logs() {
    local follow_flag=""
    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        follow_flag="-f"
    fi
    
    print_status "Showing GitLab logs..."
    check_compose_file
    
    docker-compose -f "$COMPOSE_FILE" logs $follow_flag gitlab
}

# Create backup
create_backup() {
    print_status "Creating GitLab backup..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Create GitLab backup
    docker exec gitlab-ce gitlab-backup create BACKUP=manual_$(date +%s)
    
    # Copy backup files
    docker cp gitlab-ce:/var/opt/gitlab/backups "$backup_dir/"
    docker cp gitlab-ce:/etc/gitlab "$backup_dir/config"
    
    # Create Docker volumes backup
    docker run --rm -v gitlab-data:/data -v "$PWD/$backup_dir":/backup alpine tar czf /backup/gitlab-data.tar.gz -C /data .
    docker run --rm -v gitlab-config:/data -v "$PWD/$backup_dir":/backup alpine tar czf /backup/gitlab-config.tar.gz -C /data .
    docker run --rm -v gitlab-logs:/data -v "$PWD/$backup_dir":/backup alpine tar czf /backup/gitlab-logs.tar.gz -C /data .
    
    print_success "Backup created in: $backup_dir"
}

# Restore from backup
restore_backup() {
    local backup_dir="$1"
    
    if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
        print_error "Usage: $0 restore <backup_directory>"
        exit 1
    fi
    
    print_warning "This will replace all current GitLab data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Backup restore cancelled"
        exit 0
    fi
    
    print_status "Restoring GitLab from backup: $backup_dir"
    
    # Stop services
    docker-compose -f "$COMPOSE_FILE" down
    
    # Restore volumes
    if [ -f "$backup_dir/gitlab-data.tar.gz" ]; then
        docker run --rm -v gitlab-data:/data -v "$PWD/$backup_dir":/backup alpine tar xzf /backup/gitlab-data.tar.gz -C /data
    fi
    
    if [ -f "$backup_dir/gitlab-config.tar.gz" ]; then
        docker run --rm -v gitlab-config:/data -v "$PWD/$backup_dir":/backup alpine tar xzf /backup/gitlab-config.tar.gz -C /data
    fi
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_success "Backup restored successfully"
}

# Reset GitLab (remove all data)
reset_gitlab() {
    print_warning "This will PERMANENTLY DELETE all GitLab data!"
    print_warning "This includes: projects, users, issues, pipelines, etc."
    read -p "Type 'RESET' to confirm: " confirmation
    
    if [ "$confirmation" != "RESET" ]; then
        print_status "Reset cancelled"
        exit 0
    fi
    
    print_status "Resetting GitLab..."
    
    # Stop and remove containers
    docker-compose -f "$COMPOSE_FILE" down -v
    
    # Remove volumes
    docker volume rm -f gitlab-data gitlab-config gitlab-logs
    docker volume rm -f gitlab-runner-config gitlab-runner-docker-config gitlab-runner-k8s-config
    
    print_success "GitLab reset completed"
    print_status "Run '$0 start' to start fresh GitLab instance"
}

# Show GitLab URL
show_url() {
    echo "GitLab URL: http://$GITLAB_HOST:$GITLAB_PORT"
    echo "Username: root"
    echo "Password: rootpassword123"
    echo "Registry: http://$GITLAB_HOST:5050"
}

# Get registration token
get_token() {
    print_status "Getting runner registration token..."
    
    local token=$(docker exec gitlab-ce gitlab-rails runner -e production "puts Gitlab::CurrentSettings.runners_registration_token" 2>/dev/null)
    
    if [ -n "$token" ]; then
        print_success "Registration token: $token"
        echo ""
        print_status "Use this token to register runners:"
        echo "./scripts/setup-runners.sh $token"
    else
        print_error "Could not retrieve registration token"
        print_status "Get it manually from: http://$GITLAB_HOST:$GITLAB_PORT/admin/runners"
    fi
}

# Show runner status
show_runners() {
    print_status "Runner status:"
    
    echo ""
    echo "Shell Runner:"
    docker exec gitlab-runner-shell gitlab-runner list 2>/dev/null || echo "  Not registered"
    
    echo ""
    echo "Docker Runner:"
    docker exec gitlab-runner-docker gitlab-runner list 2>/dev/null || echo "  Not registered"
    
    echo ""
    echo "Kubernetes Runner:"
    docker exec gitlab-runner-k8s gitlab-runner list 2>/dev/null || echo "  Not registered"
}

# Cleanup unused resources
cleanup_resources() {
    print_status "Cleaning up unused Docker resources..."
    
    docker system prune -f
    docker volume prune -f
    
    print_success "Cleanup completed"
}

# Update GitLab
update_gitlab() {
    print_status "Updating GitLab to latest version..."
    
    # Pull latest images
    docker-compose -f "$COMPOSE_FILE" pull
    
    # Recreate containers
    docker-compose -f "$COMPOSE_FILE" up -d --force-recreate
    
    print_success "GitLab updated"
}

# Main command processing
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    backup)
        create_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    reset)
        reset_gitlab
        ;;
    url)
        show_url
        ;;
    token)
        get_token
        ;;
    runners)
        show_runners
        ;;
    cleanup)
        cleanup_resources
        ;;
    update)
        update_gitlab
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
