#!/bin/bash

# Sprint 2: Test Notifications Script
# Sends notifications about test results via Slack, email, or other channels

set -e
set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
STATUS=""
PIPELINE_ID=""
NOTIFICATION_CHANNELS=()
DRY_RUN=false
VERBOSE=false

# Notification configuration
SLACK_WEBHOOK="${TEST_NOTIFICATION_WEBHOOK:-}"
EMAIL_SMTP_SERVER="${EMAIL_SMTP_SERVER:-}"
EMAIL_RECIPIENTS="${EMAIL_RECIPIENTS:-}"
TEAMS_WEBHOOK="${TEAMS_WEBHOOK:-}"

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Send notifications about test results

OPTIONS:
    --status STATUS       Test status (success, failure, warning)
    --pipeline-id ID      Pipeline ID for context
    --channel CHANNEL     Notification channel (slack, email, teams, all)
    --dry-run            Show what notifications would be sent
    --verbose            Enable verbose logging
    --help               Show this help message

EXAMPLES:
    # Send success notification to Slack
    $0 --status=success --pipeline-id=12345 --channel=slack

    # Send failure notification to all channels
    $0 --status=failure --pipeline-id=12345 --channel=all

    # Dry run to see what would be sent
    $0 --status=success --pipeline-id=12345 --dry-run

ENVIRONMENT VARIABLES:
    TEST_NOTIFICATION_WEBHOOK    Slack webhook URL
    EMAIL_SMTP_SERVER           SMTP server for email notifications
    EMAIL_RECIPIENTS            Comma-separated list of email recipients
    TEAMS_WEBHOOK               Microsoft Teams webhook URL

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Gather test results and metrics
gather_test_metrics() {
    log_info "Gathering test metrics and results..."
    
    local test_results_dir="${PROJECT_ROOT}/test-results"
    local logs_dir="${PROJECT_ROOT}/logs"
    
    # Initialize metrics
    export TOTAL_TESTS=0
    export PASSED_TESTS=0
    export FAILED_TESTS=0
    export TEST_DURATION="0"
    export TEST_COVERAGE="0"
    export PIPELINE_URL="${CI_PIPELINE_URL:-}"
    export PROJECT_NAME="${CI_PROJECT_NAME:-Confluent Cloud Test Framework}"
    export BRANCH_NAME="${CI_COMMIT_REF_NAME:-main}"
    export COMMIT_SHA="${CI_COMMIT_SHORT_SHA:-unknown}"
    export COMMIT_MESSAGE="${CI_COMMIT_MESSAGE:-}"
    
    # Parse JUnit XML files if they exist
    if [[ -d "$test_results_dir" ]]; then
        local junit_files=($(find "$test_results_dir" -name "*.xml" 2>/dev/null || true))
        
        for junit_file in "${junit_files[@]}"; do
            if [[ -f "$junit_file" ]]; then
                parse_junit_file "$junit_file"
            fi
        done
    fi
    
    # Get test duration from logs
    if [[ -d "$logs_dir" && -n "$PIPELINE_ID" ]]; then
        local pipeline_logs=($(find "$logs_dir" -name "*${PIPELINE_ID}*" 2>/dev/null || true))
        if [[ ${#pipeline_logs[@]} -gt 0 ]]; then
            calculate_test_duration "${pipeline_logs[@]}"
        fi
    fi
    
    # Get coverage information
    get_test_coverage
    
    log_info "Test metrics gathered: $TOTAL_TESTS total, $PASSED_TESTS passed, $FAILED_TESTS failed"
}

# Parse JUnit XML file for test results
parse_junit_file() {
    local junit_file="$1"
    
    if command -v xmllint &> /dev/null; then
        local file_tests=$(xmllint --xpath "string(//testsuite/@tests)" "$junit_file" 2>/dev/null || echo "0")
        local file_failures=$(xmllint --xpath "string(//testsuite/@failures)" "$junit_file" 2>/dev/null || echo "0")
        
        TOTAL_TESTS=$((TOTAL_TESTS + ${file_tests:-0}))
        FAILED_TESTS=$((FAILED_TESTS + ${file_failures:-0}))
        PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
    else
        # Fallback: basic grep parsing
        local file_tests=$(grep -o 'tests="[0-9]*"' "$junit_file" | head -1 | grep -o '[0-9]*' || echo "0")
        local file_failures=$(grep -o 'failures="[0-9]*"' "$junit_file" | head -1 | grep -o '[0-9]*' || echo "0")
        
        TOTAL_TESTS=$((TOTAL_TESTS + ${file_tests:-0}))
        FAILED_TESTS=$((FAILED_TESTS + ${file_failures:-0}))
        PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
    fi
}

# Calculate test duration from logs
calculate_test_duration() {
    local log_files=("$@")
    local start_time=""
    local end_time=""
    
    # Find earliest start time and latest end time
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local file_start=$(head -1 "$log_file" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || true)
            local file_end=$(tail -1 "$log_file" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || true)
            
            if [[ -n "$file_start" && ( -z "$start_time" || "$file_start" < "$start_time" ) ]]; then
                start_time="$file_start"
            fi
            
            if [[ -n "$file_end" && ( -z "$end_time" || "$file_end" > "$end_time" ) ]]; then
                end_time="$file_end"
            fi
        fi
    done
    
    # Calculate duration
    if [[ -n "$start_time" && -n "$end_time" ]]; then
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
        local end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
        
        if [[ $start_epoch -gt 0 && $end_epoch -gt 0 && $end_epoch -gt $start_epoch ]]; then
            TEST_DURATION=$((end_epoch - start_epoch))
        fi
    fi
}

# Get test coverage information
get_test_coverage() {
    local coverage_file="${PROJECT_ROOT}/test-results/coverage.xml"
    
    if [[ -f "$coverage_file" ]]; then
        if command -v xmllint &> /dev/null; then
            TEST_COVERAGE=$(xmllint --xpath "string(//coverage/@line-rate)" "$coverage_file" 2>/dev/null || echo "0")
            # Convert to percentage
            TEST_COVERAGE=$(echo "$TEST_COVERAGE * 100" | bc -l 2>/dev/null | cut -d. -f1 || echo "0")
        else
            # Fallback parsing
            TEST_COVERAGE=$(grep -o 'line-rate="[0-9.]*"' "$coverage_file" | head -1 | grep -o '[0-9.]*' || echo "0")
            TEST_COVERAGE=$(echo "$TEST_COVERAGE * 100" | bc -l 2>/dev/null | cut -d. -f1 || echo "0")
        fi
    fi
}

# Format duration for display
format_duration() {
    local duration="$1"
    
    if [[ $duration -lt 60 ]]; then
        echo "${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"
    fi
}

# Get status emoji and color
get_status_indicators() {
    case "$STATUS" in
        "success")
            export STATUS_EMOJI="✅"
            export STATUS_COLOR="good"
            export STATUS_COLOR_HEX="#36a64f"
            ;;
        "failure")
            export STATUS_EMOJI="❌"
            export STATUS_COLOR="danger"
            export STATUS_COLOR_HEX="#ff0000"
            ;;
        "warning")
            export STATUS_EMOJI="⚠️"
            export STATUS_COLOR="warning"
            export STATUS_COLOR_HEX="#ff9900"
            ;;
        *)
            export STATUS_EMOJI="ℹ️"
            export STATUS_COLOR=""
            export STATUS_COLOR_HEX="#0099ff"
            ;;
    esac
}

# Send Slack notification
send_slack_notification() {
    log_info "Sending Slack notification..."
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        log_warning "Slack webhook not configured, skipping Slack notification"
        return 0
    fi
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    local formatted_duration=$(format_duration "$TEST_DURATION")
    
    # Create Slack payload
    local slack_payload=$(cat << EOF
{
  "username": "Confluent Test Bot",
  "icon_emoji": ":test_tube:",
  "attachments": [
    {
      "color": "$STATUS_COLOR",
      "title": "$STATUS_EMOJI Test Results - $PROJECT_NAME",
      "title_link": "$PIPELINE_URL",
      "fields": [
        {
          "title": "Status",
          "value": "$(echo "$STATUS" | tr '[:lower:]' '[:upper:]')",
          "short": true
        },
        {
          "title": "Branch",
          "value": "$BRANCH_NAME",
          "short": true
        },
        {
          "title": "Tests",
          "value": "$TOTAL_TESTS total, $PASSED_TESTS passed, $FAILED_TESTS failed",
          "short": true
        },
        {
          "title": "Success Rate",
          "value": "${success_rate}%",
          "short": true
        },
        {
          "title": "Duration",
          "value": "$formatted_duration",
          "short": true
        },
        {
          "title": "Coverage",
          "value": "${TEST_COVERAGE}%",
          "short": true
        }
      ],
      "footer": "Pipeline #${PIPELINE_ID:-unknown}",
      "footer_icon": "https://confluent.io/favicon.ico",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
    
    # Add commit information if available
    if [[ -n "$COMMIT_MESSAGE" ]]; then
        slack_payload=$(echo "$slack_payload" | jq --arg msg "$COMMIT_MESSAGE" --arg sha "$COMMIT_SHA" '.attachments[0].fields += [{"title": "Commit", "value": "\(.sha): \(.msg)", "short": false}]')
    fi
    
    # Add failure details if status is failure
    if [[ "$STATUS" == "failure" && $FAILED_TESTS -gt 0 ]]; then
        local failure_details=$(get_failure_details)
        if [[ -n "$failure_details" ]]; then
            slack_payload=$(echo "$slack_payload" | jq --arg details "$failure_details" '.attachments[0].fields += [{"title": "Failed Tests", "value": $details, "short": false}]')
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would send Slack notification:"
        echo "$slack_payload" | jq .
        return 0
    fi
    
    # Send notification
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$slack_payload" \
        "$SLACK_WEBHOOK")
    
    if [[ "$response" == "ok" ]]; then
        log_success "Slack notification sent successfully"
        return 0
    else
        log_error "Failed to send Slack notification: $response"
        return 1
    fi
}

# Get failure details for notifications
get_failure_details() {
    local failure_details=""
    local test_results_dir="${PROJECT_ROOT}/test-results"
    
    if [[ -d "$test_results_dir" ]]; then
        local junit_files=($(find "$test_results_dir" -name "*.xml" 2>/dev/null || true))
        
        for junit_file in "${junit_files[@]}"; do
            if [[ -f "$junit_file" ]]; then
                local failures
                if command -v xmllint &> /dev/null; then
                    failures=$(xmllint --xpath "//testcase[failure]/@name" "$junit_file" 2>/dev/null | sed 's/name="//g' | sed 's/"//g' || true)
                else
                    failures=$(grep -A 1 '<failure' "$junit_file" | grep 'name=' | sed 's/.*name="//g' | sed 's/".*//g' || true)
                fi
                
                if [[ -n "$failures" ]]; then
                    failure_details="${failure_details}\n• $(basename "$junit_file" .xml): $failures"
                fi
            fi
        done
    fi
    
    echo -e "$failure_details"
}

# Send email notification
send_email_notification() {
    log_info "Sending email notification..."
    
    if [[ -z "$EMAIL_SMTP_SERVER" || -z "$EMAIL_RECIPIENTS" ]]; then
        log_warning "Email configuration not complete, skipping email notification"
        return 0
    fi
    
    local subject="$STATUS_EMOJI Test Results - $PROJECT_NAME [$STATUS]"
    local formatted_duration=$(format_duration "$TEST_DURATION")
    local success_rate=0
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    # Create HTML email content
    local email_body=$(cat << EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: $STATUS_COLOR_HEX; color: white; padding: 10px; border-radius: 5px; }
        .metrics { margin: 20px 0; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background-color: #f5f5f5; border-radius: 3px; }
        .failure-details { background-color: #fff2f2; padding: 10px; border-left: 4px solid #ff0000; margin: 10px 0; }
        .footer { font-size: 12px; color: #666; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="header">
        <h2>$STATUS_EMOJI Test Results - $PROJECT_NAME</h2>
        <p>Status: $(echo "$STATUS" | tr '[:lower:]' '[:upper:]')</p>
    </div>
    
    <div class="metrics">
        <div class="metric">
            <strong>Branch:</strong> $BRANCH_NAME
        </div>
        <div class="metric">
            <strong>Tests:</strong> $TOTAL_TESTS total, $PASSED_TESTS passed, $FAILED_TESTS failed
        </div>
        <div class="metric">
            <strong>Success Rate:</strong> ${success_rate}%
        </div>
        <div class="metric">
            <strong>Duration:</strong> $formatted_duration
        </div>
        <div class="metric">
            <strong>Coverage:</strong> ${TEST_COVERAGE}%
        </div>
    </div>
    
    $(if [[ -n "$COMMIT_MESSAGE" ]]; then echo "<p><strong>Commit:</strong> $COMMIT_SHA - $COMMIT_MESSAGE</p>"; fi)
    
    $(if [[ "$STATUS" == "failure" && $FAILED_TESTS -gt 0 ]]; then
        echo '<div class="failure-details">'
        echo '<h3>Failed Tests:</h3>'
        echo '<pre>'"$(get_failure_details)"'</pre>'
        echo '</div>'
    fi)
    
    <div class="footer">
        <p>Pipeline #${PIPELINE_ID:-unknown}</p>
        $(if [[ -n "$PIPELINE_URL" ]]; then echo "<p><a href=\"$PIPELINE_URL\">View Pipeline</a></p>"; fi)
        <p>Generated at $(date)</p>
    </div>
</body>
</html>
EOF
)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would send email notification:"
        log_info "Subject: $subject"
        log_info "Recipients: $EMAIL_RECIPIENTS"
        return 0
    fi
    
    # Send email using sendmail or mail command
    if command -v sendmail &> /dev/null; then
        (
            echo "To: $EMAIL_RECIPIENTS"
            echo "Subject: $subject"
            echo "Content-Type: text/html; charset=UTF-8"
            echo ""
            echo "$email_body"
        ) | sendmail -t
        
        log_success "Email notification sent successfully"
        return 0
    elif command -v mail &> /dev/null; then
        echo "$email_body" | mail -s "$subject" "$EMAIL_RECIPIENTS"
        log_success "Email notification sent successfully"
        return 0
    else
        log_error "No email sending capability found (sendmail or mail)"
        return 1
    fi
}

# Send Microsoft Teams notification
send_teams_notification() {
    log_info "Sending Microsoft Teams notification..."
    
    if [[ -z "$TEAMS_WEBHOOK" ]]; then
        log_warning "Teams webhook not configured, skipping Teams notification"
        return 0
    fi
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    local formatted_duration=$(format_duration "$TEST_DURATION")
    
    # Create Teams payload (Adaptive Card format)
    local teams_payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$STATUS_COLOR_HEX",
    "summary": "Test Results - $PROJECT_NAME",
    "sections": [{
        "activityTitle": "$STATUS_EMOJI Test Results - $PROJECT_NAME",
        "activitySubtitle": "Branch: $BRANCH_NAME",
        "facts": [{
            "name": "Status",
            "value": "$(echo "$STATUS" | tr '[:lower:]' '[:upper:]')"
        }, {
            "name": "Tests",
            "value": "$TOTAL_TESTS total, $PASSED_TESTS passed, $FAILED_TESTS failed"
        }, {
            "name": "Success Rate",
            "value": "${success_rate}%"
        }, {
            "name": "Duration",
            "value": "$formatted_duration"
        }, {
            "name": "Coverage",
            "value": "${TEST_COVERAGE}%"
        }],
        "markdown": true
    }],
    "potentialActions": [{
        "@type": "OpenUri",
        "name": "View Pipeline",
        "targets": [{
            "os": "default",
            "uri": "$PIPELINE_URL"
        }]
    }]
}
EOF
)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would send Teams notification:"
        echo "$teams_payload" | jq .
        return 0
    fi
    
    # Send notification
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$teams_payload" \
        "$TEAMS_WEBHOOK")
    
    if [[ "$response" == "1" ]]; then
        log_success "Teams notification sent successfully"
        return 0
    else
        log_error "Failed to send Teams notification: $response"
        return 1
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status=*)
                STATUS="${1#*=}"
                shift
                ;;
            --pipeline-id=*)
                PIPELINE_ID="${1#*=}"
                shift
                ;;
            --channel=*)
                IFS=',' read -ra CHANNELS <<< "${1#*=}"
                for channel in "${CHANNELS[@]}"; do
                    NOTIFICATION_CHANNELS+=("$channel")
                done
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Main execution function
main() {
    log_info "Starting test notifications..."
    
    # Validate required parameters
    if [[ -z "$STATUS" ]]; then
        log_error "Status is required. Use --status=success|failure|warning"
        exit 1
    fi
    
    # Set default channels if none specified
    if [[ ${#NOTIFICATION_CHANNELS[@]} -eq 0 ]]; then
        NOTIFICATION_CHANNELS=("slack")
    fi
    
    # Handle "all" channel
    if [[ " ${NOTIFICATION_CHANNELS[*]} " =~ " all " ]]; then
        NOTIFICATION_CHANNELS=("slack" "email" "teams")
    fi
    
    # Gather test metrics and results
    gather_test_metrics
    get_status_indicators
    
    # Send notifications to each configured channel
    local successful_notifications=0
    local failed_notifications=0
    
    for channel in "${NOTIFICATION_CHANNELS[@]}"; do
        log_info "Sending notification via $channel..."
        
        case "$channel" in
            "slack")
                if send_slack_notification; then
                    ((successful_notifications++))
                else
                    ((failed_notifications++))
                fi
                ;;
            "email")
                if send_email_notification; then
                    ((successful_notifications++))
                else
                    ((failed_notifications++))
                fi
                ;;
            "teams")
                if send_teams_notification; then
                    ((successful_notifications++))
                else
                    ((failed_notifications++))
                fi
                ;;
            *)
                log_warning "Unknown notification channel: $channel"
                ((failed_notifications++))
                ;;
        esac
    done
    
    # Summary
    log_info "Notification Summary:"
    log_info "  Successful: $successful_notifications"
    log_info "  Failed: $failed_notifications"
    log_info "  Total Channels: ${#NOTIFICATION_CHANNELS[@]}"
    
    if [[ $failed_notifications -eq 0 ]]; then
        log_success "All notifications sent successfully!"
        exit 0
    else
        log_warning "Some notifications failed to send"
        exit 1
    fi
}

# Parse arguments and run main function
parse_arguments "$@"
main
