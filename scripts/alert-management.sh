#!/bin/bash
# Sprint 5: Monitoring Alert Management Script
# Manages alert rules, notifications, and escalation

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
ENVIRONMENT="${ENVIRONMENT:-dev}"
CONFIG_FILE="${PROJECT_ROOT}/config/environments/${ENVIRONMENT}.yaml"
ALERTS_CONFIG="${PROJECT_ROOT}/monitoring/config/alerts.yaml"
LOG_FILE="${PROJECT_ROOT}/logs/alert-management.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Load configuration
load_config() {
    log_info "Loading monitoring configuration for environment: $ENVIRONMENT"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Extract monitoring configuration
    export CONFLUENT_CLUSTER_ID=$(yq eval '.confluent.cluster_id' "$CONFIG_FILE")
    export CONFLUENT_ENVIRONMENT_ID=$(yq eval '.confluent.environment_id' "$CONFIG_FILE")
    export SUMO_LOGIC_ENDPOINT=$(yq eval '.monitoring.sumo_logic.endpoint' "$CONFIG_FILE")
    export SLACK_WEBHOOK_URL=$(yq eval '.alerts.slack.webhook_url' "$CONFIG_FILE" 2>/dev/null || echo "")
    export TEAMS_WEBHOOK_URL=$(yq eval '.alerts.teams.webhook_url' "$CONFIG_FILE" 2>/dev/null || echo "")
    export PAGERDUTY_KEY=$(yq eval '.alerts.pagerduty.api_key' "$CONFIG_FILE" 2>/dev/null || echo "")
    
    log_success "Configuration loaded successfully"
}

# Create Sumo Logic alert rules
create_sumo_alerts() {
    log_info "Creating Sumo Logic alert rules..."
    
    local sumo_api_key="${SUMO_LOGIC_API_KEY:-}"
    local sumo_api_secret="${SUMO_LOGIC_API_SECRET:-}"
    
    if [[ -z "$sumo_api_key" || -z "$sumo_api_secret" ]]; then
        log_warning "Sumo Logic API credentials not found, skipping alert creation"
        return 0
    fi
    
    # High Consumer Lag Alert
    create_consumer_lag_alert
    
    # Connector Failure Alert  
    create_connector_failure_alert
    
    # Error Rate Alert
    create_error_rate_alert
    
    # Throughput Drop Alert
    create_throughput_alert
    
    log_success "Sumo Logic alert rules created"
}

create_consumer_lag_alert() {
    local alert_payload=$(cat << 'EOF'
{
  "name": "High Consumer Lag",
  "description": "Alert when consumer lag exceeds threshold",
  "query": "_sourceCategory=\"kafka/*/metrics\" | json field=_raw \"consumer.lag\" as lag | where lag > 10000 | count by _sourceHost",
  "queryType": "Logs",
  "trigger": {
    "timeRange": "5m",
    "triggerType": "Critical",
    "threshold": 1,
    "thresholdType": "GreaterThan"
  },
  "notifications": [
    {
      "notification": {
        "connectionType": "Slack",
        "connectionId": "slack-notification"
      }
    }
  ],
  "isDisabled": false
}
EOF
)
    
    log_info "Creating consumer lag alert rule..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n "${SUMO_LOGIC_API_KEY}:${SUMO_LOGIC_API_SECRET}" | base64)" \
        -d "$alert_payload" \
        "https://api.sumologic.com/api/v1/monitors")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Consumer lag alert created successfully"
    else
        log_error "Failed to create consumer lag alert: $response"
    fi
}

create_connector_failure_alert() {
    local alert_payload=$(cat << 'EOF'
{
  "name": "Connector Failure",
  "description": "Alert when connector status is not RUNNING",
  "query": "_sourceCategory=\"kafka/*/logs\" | json field=_raw \"status\" as status | where status != \"RUNNING\" | count by connector_name",
  "queryType": "Logs",
  "trigger": {
    "timeRange": "2m",
    "triggerType": "Critical",
    "threshold": 1,
    "thresholdType": "GreaterThanOrEqual"
  },
  "notifications": [
    {
      "notification": {
        "connectionType": "PagerDuty",
        "connectionId": "pagerduty-notification"
      }
    }
  ],
  "isDisabled": false
}
EOF
)
    
    log_info "Creating connector failure alert rule..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n "${SUMO_LOGIC_API_KEY}:${SUMO_LOGIC_API_SECRET}" | base64)" \
        -d "$alert_payload" \
        "https://api.sumologic.com/api/v1/monitors")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Connector failure alert created successfully"
    else
        log_error "Failed to create connector failure alert: $response"
    fi
}

create_error_rate_alert() {
    local alert_payload=$(cat << 'EOF'
{
  "name": "High Error Rate",
  "description": "Alert when error rate exceeds 5%",
  "query": "_sourceCategory=\"kafka/*/logs\" | json field=_raw \"level\" as level | timeslice 5m | if(level=\"ERROR\", 1, 0) as error_count | if(level!=\"\", 1, 0) as total_count | sum(error_count) as errors, sum(total_count) as total by _timeslice | (errors/total)*100 as error_rate | where error_rate > 5",
  "queryType": "Logs",
  "trigger": {
    "timeRange": "10m",
    "triggerType": "Warning",
    "threshold": 1,
    "thresholdType": "GreaterThanOrEqual"
  },
  "notifications": [
    {
      "notification": {
        "connectionType": "Email",
        "connectionId": "email-notification"
      }
    }
  ],
  "isDisabled": false
}
EOF
)
    
    log_info "Creating error rate alert rule..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n "${SUMO_LOGIC_API_KEY}:${SUMO_LOGIC_API_SECRET}" | base64)" \
        -d "$alert_payload" \
        "https://api.sumologic.com/api/v1/monitors")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Error rate alert created successfully"
    else
        log_error "Failed to create error rate alert: $response"
    fi
}

create_throughput_alert() {
    local alert_payload=$(cat << 'EOF'
{
  "name": "Throughput Drop",
  "description": "Alert when throughput drops significantly",
  "query": "_sourceCategory=\"kafka/*/metrics\" | json field=_raw \"throughput\" as current_throughput | timeslice 5m | avg(current_throughput) as avg_throughput by _timeslice | compare with timeshift -1h | (avg_throughput - avg_throughput_1h)/avg_throughput_1h * 100 as throughput_change | where throughput_change < -50",
  "queryType": "Logs",
  "trigger": {
    "timeRange": "15m",
    "triggerType": "Critical",
    "threshold": 1,
    "thresholdType": "GreaterThanOrEqual"
  },
  "notifications": [
    {
      "notification": {
        "connectionType": "Slack",
        "connectionId": "slack-notification"
      }
    }
  ],
  "isDisabled": false
}
EOF
)
    
    log_info "Creating throughput drop alert rule..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n "${SUMO_LOGIC_API_KEY}:${SUMO_LOGIC_API_SECRET}" | base64)" \
        -d "$alert_payload" \
        "https://api.sumologic.com/api/v1/monitors")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Throughput drop alert created successfully"
    else
        log_error "Failed to create throughput drop alert: $response"
    fi
}

# Send test alert
send_test_alert() {
    local alert_type="${1:-test}"
    local message="${2:-Test alert from monitoring system}"
    
    log_info "Sending test alert: $alert_type"
    
    # Send to Slack if configured
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        send_slack_alert "$alert_type" "$message"
    fi
    
    # Send to Teams if configured
    if [[ -n "$TEAMS_WEBHOOK_URL" ]]; then
        send_teams_alert "$alert_type" "$message"
    fi
    
    # Send to PagerDuty if configured
    if [[ -n "$PAGERDUTY_KEY" ]]; then
        send_pagerduty_alert "$alert_type" "$message"
    fi
}

send_slack_alert() {
    local alert_type="$1"
    local message="$2"
    local color="warning"
    
    case "$alert_type" in
        "critical"|"error") color="danger" ;;
        "warning") color="warning" ;;
        *) color="good" ;;
    esac
    
    local slack_payload=$(cat << EOF
{
    "username": "Confluent Monitoring",
    "icon_emoji": ":warning:",
    "attachments": [{
        "color": "$color",
        "title": "🚨 Alert: $alert_type",
        "text": "$message",
        "fields": [{
            "title": "Environment",
            "value": "$ENVIRONMENT",
            "short": true
        }, {
            "title": "Cluster",
            "value": "$CONFLUENT_CLUSTER_ID",
            "short": true
        }, {
            "title": "Timestamp",
            "value": "$(date -u '+%Y-%m-%d %H:%M:%S UTC')",
            "short": true
        }],
        "footer": "Confluent Test Framework",
        "ts": $(date +%s)
    }]
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$slack_payload" \
        "$SLACK_WEBHOOK_URL")
    
    if [[ "$response" == "ok" ]]; then
        log_success "Slack alert sent successfully"
    else
        log_error "Failed to send Slack alert: $response"
    fi
}

send_teams_alert() {
    local alert_type="$1"
    local message="$2"
    local color="FF8C00"  # Orange
    
    case "$alert_type" in
        "critical"|"error") color="FF0000" ;;  # Red
        "warning") color="FF8C00" ;;           # Orange
        *) color="00FF00" ;;                   # Green
    esac
    
    local teams_payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$color",
    "summary": "Alert: $alert_type",
    "sections": [{
        "activityTitle": "🚨 Confluent Monitoring Alert",
        "activitySubtitle": "$alert_type",
        "activityImage": "https://docs.confluent.io/platform/current/_static/confluent-logo-300.png",
        "facts": [{
            "name": "Alert Type",
            "value": "$alert_type"
        }, {
            "name": "Message",
            "value": "$message"
        }, {
            "name": "Environment",
            "value": "$ENVIRONMENT"
        }, {
            "name": "Cluster ID",
            "value": "$CONFLUENT_CLUSTER_ID"
        }, {
            "name": "Timestamp",
            "value": "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        }],
        "markdown": true
    }],
    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View Sumo Logic Dashboard",
        "targets": [{
            "os": "default",
            "uri": "$SUMO_LOGIC_ENDPOINT"
        }]
    }]
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$teams_payload" \
        "$TEAMS_WEBHOOK_URL")
    
    if [[ "$response" == "1" ]]; then
        log_success "Teams alert sent successfully"
    else
        log_error "Failed to send Teams alert: $response"
    fi
}

send_pagerduty_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="warning"
    
    case "$alert_type" in
        "critical"|"error") severity="critical" ;;
        "warning") severity="warning" ;;
        *) severity="info" ;;
    esac
    
    local pagerduty_payload=$(cat << EOF
{
    "routing_key": "$PAGERDUTY_KEY",
    "event_action": "trigger",
    "dedup_key": "confluent-monitoring-$(date +%s)",
    "payload": {
        "summary": "$message",
        "severity": "$severity",
        "source": "Confluent Test Framework",
        "component": "monitoring",
        "group": "kafka-cluster",
        "class": "$alert_type",
        "custom_details": {
            "environment": "$ENVIRONMENT",
            "cluster_id": "$CONFLUENT_CLUSTER_ID",
            "timestamp": "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        }
    }
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$pagerduty_payload" \
        "https://events.pagerduty.com/v2/enqueue")
    
    if echo "$response" | jq -e '.status' > /dev/null 2>&1; then
        log_success "PagerDuty alert sent successfully"
    else
        log_error "Failed to send PagerDuty alert: $response"
    fi
}

# Validate monitoring setup
validate_monitoring() {
    log_info "Validating monitoring setup..."
    
    local validation_errors=0
    
    # Check Sumo Logic connectivity
    if [[ -n "$SUMO_LOGIC_ENDPOINT" ]]; then
        log_info "Testing Sumo Logic connectivity..."
        
        local test_log='{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","level":"INFO","message":"Monitoring validation test","component":"alert-management","environment":"'$ENVIRONMENT'"}'
        
        local response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$test_log" \
            "$SUMO_LOGIC_ENDPOINT")
        
        if [[ $? -eq 0 ]]; then
            log_success "Sumo Logic connectivity test passed"
        else
            log_error "Sumo Logic connectivity test failed"
            ((validation_errors++))
        fi
    else
        log_warning "Sumo Logic endpoint not configured"
    fi
    
    # Check notification channels
    log_info "Testing notification channels..."
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        send_slack_alert "test" "Monitoring validation test"
    else
        log_warning "Slack webhook not configured"
    fi
    
    if [[ -n "$TEAMS_WEBHOOK_URL" ]]; then
        send_teams_alert "test" "Monitoring validation test"
    else
        log_warning "Teams webhook not configured"
    fi
    
    # Return validation result
    if [[ $validation_errors -eq 0 ]]; then
        log_success "Monitoring validation completed successfully"
        return 0
    else
        log_error "Monitoring validation failed with $validation_errors errors"
        return 1
    fi
}

# List active alerts
list_active_alerts() {
    log_info "Listing active alert rules..."
    
    if [[ -z "${SUMO_LOGIC_API_KEY:-}" || -z "${SUMO_LOGIC_API_SECRET:-}" ]]; then
        log_warning "Sumo Logic API credentials not found"
        return 1
    fi
    
    local response=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "${SUMO_LOGIC_API_KEY}:${SUMO_LOGIC_API_SECRET}" | base64)" \
        "https://api.sumologic.com/api/v1/monitors")
    
    echo "$response" | jq -r '.data[] | "ID: \(.id) | Name: \(.name) | Status: \(if .isDisabled then "Disabled" else "Enabled" end)"'
}

# Main execution
main() {
    log_info "Starting alert management for environment: $ENVIRONMENT"
    
    case "${1:-validate}" in
        "create")
            load_config
            create_sumo_alerts
            ;;
        "test")
            load_config
            send_test_alert "${2:-test}" "${3:-Test alert from alert management script}"
            ;;
        "validate")
            load_config
            validate_monitoring
            ;;
        "list")
            load_config
            list_active_alerts
            ;;
        *)
            echo "Usage: $0 {create|test|validate|list} [alert_type] [message]"
            echo ""
            echo "Commands:"
            echo "  create   - Create alert rules in Sumo Logic"
            echo "  test     - Send test alert to configured channels"
            echo "  validate - Validate monitoring setup and connectivity"
            echo "  list     - List active alert rules"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
