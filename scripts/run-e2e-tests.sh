#!/bin/bash

# Sprint 2: End-to-End Data Flow Testing Script
# This script orchestrates complete producer -> connector -> consumer data flow tests

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
TEST_RESULTS_DIR="${PROJECT_ROOT}/test-results"
LOGS_DIR="${PROJECT_ROOT}/logs"
TEST_DATA_DIR="${PROJECT_ROOT}/test-data"

# Default values
TEST_TYPE="basic-flow"
ENVIRONMENT="dev"
MESSAGE_COUNT=100
DATA_FORMAT="json"
TIMEOUT=1800  # 30 minutes
DEPLOY_MODE=false
CLEANUP_AFTER=true
VERBOSE=false

# Test configuration
declare -A TEST_CONFIGS
TEST_CONFIGS[basic-flow]="producer,source-connector,sink-connector,consumer"
TEST_CONFIGS[consumer-groups]="producer,consumer-groups,validation"
TEST_CONFIGS[performance]="bulk-producer,performance-consumer,metrics"

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

End-to-End Data Flow Testing for Confluent Cloud

OPTIONS:
    --test-type TYPE        Type of E2E test to run (basic-flow, consumer-groups, performance)
    --env ENVIRONMENT       Environment to test against (dev, staging, production)
    --message-count COUNT   Number of messages to produce (default: 100)
    --data-format FORMAT    Data format to use (json, avro) (default: json)
    --timeout SECONDS       Test timeout in seconds (default: 1800)
    --deploy-mode          Run in deployment mode (no cleanup)
    --no-cleanup           Don't cleanup resources after test
    --verbose              Enable verbose logging
    --help                 Show this help message

EXAMPLES:
    # Run basic data flow test
    $0 --test-type=basic-flow --env=dev

    # Run performance test with 1000 messages
    $0 --test-type=performance --env=staging --message-count=1000

    # Run consumer group test with Avro format
    $0 --test-type=consumer-groups --env=dev --data-format=avro

    # Run in verbose mode without cleanup
    $0 --test-type=basic-flow --env=dev --verbose --no-cleanup

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

# Setup directories
setup_directories() {
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$TEST_DATA_DIR"
    
    # Create log file for this run
    export LOG_FILE="${LOGS_DIR}/e2e-${TEST_TYPE}-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE"
    
    log_info "Log file created: $LOG_FILE"
    log_info "Test results directory: $TEST_RESULTS_DIR"
}

# Validate environment variables
validate_environment() {
    local required_vars=(
        "CONFLUENT_CLOUD_API_KEY"
        "CONFLUENT_CLOUD_API_SECRET"
        "CONFLUENT_ENVIRONMENT_ID"
        "CONFLUENT_CLUSTER_ID"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        exit 1
    fi
    
    log_success "Environment variables validated"
}

# Generate test data
generate_test_data() {
    log_info "Generating test data for $DATA_FORMAT format..."
    
    local data_file="${TEST_DATA_DIR}/test-data-${DATA_FORMAT}-${MESSAGE_COUNT}.json"
    
    case $DATA_FORMAT in
        "json")
            generate_json_test_data "$data_file"
            ;;
        "avro")
            generate_avro_test_data "$data_file"
            ;;
        *)
            log_error "Unsupported data format: $DATA_FORMAT"
            exit 1
            ;;
    esac
    
    export TEST_DATA_FILE="$data_file"
    log_success "Test data generated: $TEST_DATA_FILE"
}

# Generate JSON test data
generate_json_test_data() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
[
$(for i in $(seq 1 $MESSAGE_COUNT); do
    cat << JSON_MSG
  {
    "id": "$i",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "user_id": "user_$(( (RANDOM % 1000) + 1 ))",
    "event_type": "$(shuf -n1 -e 'login' 'logout' 'purchase' 'view' 'click')",
    "session_id": "session_$(date +%s)_$i",
    "properties": {
      "browser": "$(shuf -n1 -e 'Chrome' 'Firefox' 'Safari' 'Edge')",
      "platform": "$(shuf -n1 -e 'web' 'mobile' 'desktop')",
      "version": "$(shuf -n1 -e '1.0.0' '1.1.0' '2.0.0')"
    },
    "value": $(( RANDOM % 1000 )),
    "test_run_id": "${TEST_PREFIX:-test}_${TEST_TYPE}_$(date +%s)"
  }$([ $i -ne $MESSAGE_COUNT ] && echo ",")
JSON_MSG
done)
]
EOF
}

# Generate Avro test data (with schema)
generate_avro_test_data() {
    local output_file="$1"
    
    # Create Avro schema
    local schema_file="${TEST_DATA_DIR}/user-event-schema.avsc"
    cat > "$schema_file" << EOF
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "com.confluent.test",
  "fields": [
    {"name": "id", "type": "string"},
    {"name": "timestamp", "type": "string"},
    {"name": "user_id", "type": "string"},
    {"name": "event_type", "type": "string"},
    {"name": "session_id", "type": "string"},
    {"name": "properties", "type": {
      "type": "record",
      "name": "Properties",
      "fields": [
        {"name": "browser", "type": "string"},
        {"name": "platform", "type": "string"},
        {"name": "version", "type": "string"}
      ]
    }},
    {"name": "value", "type": "int"},
    {"name": "test_run_id", "type": "string"}
  ]
}
EOF
    
    export AVRO_SCHEMA_FILE="$schema_file"
    generate_json_test_data "$output_file"  # Generate JSON data that matches Avro schema
}

# Setup test infrastructure using Terraform
setup_test_infrastructure() {
    log_info "Setting up test infrastructure for $TEST_TYPE..."
    
    cd "$PROJECT_ROOT"
    
    # Set test-specific variables
    export TEST_PREFIX="e2e-${TEST_TYPE}"
    export TEST_SUFFIX="${ENVIRONMENT}-$(date +%s)"
    export TF_VAR_message_count="$MESSAGE_COUNT"
    export TF_VAR_data_format="$DATA_FORMAT"
    
    # Initialize Terraform
    cd terraform
    terraform init
    
    # Create test-specific Terraform configuration
    create_e2e_test_config
    
    # Apply infrastructure
    if terraform apply -auto-approve -var-file="../config/environments/${ENVIRONMENT}.yaml"; then
        log_success "Test infrastructure created successfully"
        
        # Extract important outputs
        export KAFKA_TOPIC_NAME=$(terraform output -raw kafka_topic_name)
        export S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name || echo "")
        export DATABASE_URL=$(terraform output -raw database_url || echo "")
        
        log_info "Created topic: $KAFKA_TOPIC_NAME"
    else
        log_error "Failed to create test infrastructure"
        exit 1
    fi
}

# Create E2E test-specific Terraform configuration
create_e2e_test_config() {
    local test_config_file="e2e-${TEST_TYPE}.tf"
    
    case $TEST_TYPE in
        "basic-flow")
            create_basic_flow_config "$test_config_file"
            ;;
        "consumer-groups")
            create_consumer_groups_config "$test_config_file"
            ;;
        "performance")
            create_performance_config "$test_config_file"
            ;;
    esac
}

# Create basic flow test configuration
create_basic_flow_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
# E2E Basic Flow Test Configuration
# Producer -> Source Connector -> Topic -> Sink Connector -> Consumer

resource "confluent_kafka_topic" "e2e_input" {
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  topic_name       = "\${var.test_prefix}-input-topic"
  partitions_count = 3
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "3600000"  # 1 hour for tests
    "min.insync.replicas" = "2"
  }
}

resource "confluent_kafka_topic" "e2e_output" {
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  topic_name       = "\${var.test_prefix}-output-topic"
  partitions_count = 3
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "3600000"
    "min.insync.replicas" = "2"
  }
}

# S3 Source Connector
resource "confluent_connector" "s3_source" {
  environment {
    id = var.confluent_environment_id
  }
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  
  config_sensitive = {}
  config_nonsensitive = {
    "connector.class"          = "S3Source"
    "name"                    = "\${var.test_prefix}-s3-source"
    "kafka.api.key"           = var.confluent_cloud_api_key
    "kafka.api.secret"        = var.confluent_cloud_api_secret
    "aws.access.key.id"       = var.aws_access_key_id
    "aws.secret.access.key"   = var.aws_secret_access_key
    "s3.bucket.name"          = var.test_s3_bucket
    "topics"                  = confluent_kafka_topic.e2e_input.topic_name
    "format.class"            = "io.confluent.connect.s3.format.json.JsonFormat"
    "flush.size"              = "10"
    "tasks.max"               = "1"
  }
  
  depends_on = [confluent_kafka_topic.e2e_input]
}

# PostgreSQL Sink Connector
resource "confluent_connector" "postgres_sink" {
  environment {
    id = var.confluent_environment_id
  }
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  
  config_sensitive = {}
  config_nonsensitive = {
    "connector.class"         = "PostgresSink"
    "name"                   = "\${var.test_prefix}-postgres-sink"
    "kafka.api.key"          = var.confluent_cloud_api_key
    "kafka.api.secret"       = var.confluent_cloud_api_secret
    "connection.url"         = var.test_database_url
    "connection.user"        = var.test_database_user
    "connection.password"    = var.test_database_password
    "topics"                 = confluent_kafka_topic.e2e_output.topic_name
    "auto.create"            = "true"
    "auto.evolve"            = "true"
    "insert.mode"            = "upsert"
    "pk.fields"              = "id"
    "tasks.max"              = "1"
  }
  
  depends_on = [confluent_kafka_topic.e2e_output]
}

# Outputs for test execution
output "kafka_topic_name" {
  value = confluent_kafka_topic.e2e_input.topic_name
}

output "s3_bucket_name" {
  value = var.test_s3_bucket
}

output "database_url" {
  value = var.test_database_url
  sensitive = true
}
EOF
}

# Create consumer groups test configuration  
create_consumer_groups_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
# E2E Consumer Groups Test Configuration
# Tests multiple consumer groups consuming from the same topic

resource "confluent_kafka_topic" "consumer_groups_test" {
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  topic_name       = "\${var.test_prefix}-consumer-groups-topic"
  partitions_count = 6  # More partitions for consumer group testing
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "3600000"
    "min.insync.replicas" = "2"
  }
}

output "kafka_topic_name" {
  value = confluent_kafka_topic.consumer_groups_test.topic_name
}
EOF
}

# Create performance test configuration
create_performance_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
# E2E Performance Test Configuration
# High-throughput producer-consumer testing

resource "confluent_kafka_topic" "performance_test" {
  kafka_cluster {
    id = var.confluent_cluster_id
  }
  topic_name       = "\${var.test_prefix}-performance-topic"
  partitions_count = 12  # More partitions for better parallelism
  
  config = {
    "cleanup.policy"       = "delete"
    "retention.ms"         = "3600000"
    "min.insync.replicas"  = "2"
    "segment.ms"           = "300000"   # 5 minutes
    "compression.type"     = "snappy"
  }
}

output "kafka_topic_name" {
  value = confluent_kafka_topic.performance_test.topic_name
}
EOF
}

# Execute the specific test type
execute_test() {
    log_info "Executing $TEST_TYPE test..."
    
    case $TEST_TYPE in
        "basic-flow")
            execute_basic_flow_test
            ;;
        "consumer-groups")
            execute_consumer_groups_test
            ;;
        "performance")
            execute_performance_test
            ;;
    esac
}

# Execute basic flow test
execute_basic_flow_test() {
    log_info "Running basic data flow test: Producer -> Source Connector -> Sink Connector -> Consumer"
    
    # Step 1: Upload test data to S3 (simulating source)
    upload_test_data_to_s3
    
    # Step 2: Wait for source connector to process data
    wait_for_source_connector
    
    # Step 3: Verify data in Kafka topic
    verify_kafka_topic_data
    
    # Step 4: Wait for sink connector to process data
    wait_for_sink_connector
    
    # Step 5: Verify data in sink (database)
    verify_sink_data
    
    # Step 6: Run consumer to validate end-to-end flow
    run_consumer_validation
    
    log_success "Basic flow test completed successfully"
}

# Execute consumer groups test
execute_consumer_groups_test() {
    log_info "Running consumer groups test with multiple consumer groups"
    
    # Step 1: Produce test data directly to Kafka
    produce_test_data_to_kafka
    
    # Step 2: Start multiple consumer groups
    start_multiple_consumer_groups
    
    # Step 3: Validate consumer group behavior
    validate_consumer_groups
    
    log_success "Consumer groups test completed successfully"
}

# Execute performance test
execute_performance_test() {
    log_info "Running performance test with $MESSAGE_COUNT messages"
    
    # Step 1: Start performance monitoring
    start_performance_monitoring
    
    # Step 2: Run high-throughput producer
    run_bulk_producer
    
    # Step 3: Run high-throughput consumer
    run_performance_consumer
    
    # Step 4: Collect performance metrics
    collect_performance_metrics
    
    log_success "Performance test completed successfully"
}

# Utility function to produce test data directly to Kafka
produce_test_data_to_kafka() {
    log_info "Producing test data directly to Kafka topic: $KAFKA_TOPIC_NAME"
    
    # Create a simple producer script
    cat > "${TEST_DATA_DIR}/kafka-producer.py" << 'EOF'
#!/usr/bin/env python3

import json
import sys
import os
from kafka import KafkaProducer
import time

def main():
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS')
    topic = os.environ.get('KAFKA_TOPIC_NAME')
    data_file = os.environ.get('TEST_DATA_FILE')
    
    if not all([bootstrap_servers, topic, data_file]):
        print("Missing required environment variables")
        sys.exit(1)
    
    producer = KafkaProducer(
        bootstrap_servers=bootstrap_servers,
        security_protocol='SASL_SSL',
        sasl_mechanism='PLAIN',
        sasl_plain_username=os.environ.get('CONFLUENT_CLOUD_API_KEY'),
        sasl_plain_password=os.environ.get('CONFLUENT_CLOUD_API_SECRET'),
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )
    
    with open(data_file, 'r') as f:
        test_data = json.load(f)
    
    messages_sent = 0
    for message in test_data:
        try:
            future = producer.send(topic, message)
            future.get(timeout=10)
            messages_sent += 1
            if messages_sent % 10 == 0:
                print(f"Sent {messages_sent} messages")
        except Exception as e:
            print(f"Failed to send message: {e}")
    
    producer.close()
    print(f"Successfully sent {messages_sent} messages to topic {topic}")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "${TEST_DATA_DIR}/kafka-producer.py"
    
    # Install required Python packages and run producer
    pip3 install kafka-python
    
    export KAFKA_BOOTSTRAP_SERVERS="${CONFLUENT_CLUSTER_ENDPOINT}"
    python3 "${TEST_DATA_DIR}/kafka-producer.py"
}

# Create JUnit XML report
create_junit_report() {
    local test_result="$1"  # "passed" or "failed"
    local test_name="e2e-${TEST_TYPE}-${ENVIRONMENT}"
    local report_file="${TEST_RESULTS_DIR}/${test_name}.xml"
    
    local end_time=$(date +%s)
    local duration=$((end_time - ${START_TIME:-$(date +%s)}))
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="$test_name" tests="1" failures="$([[ $test_result == "failed" ]] && echo "1" || echo "0")" time="$duration">
  <testcase name="$test_name" classname="E2ETests" time="$duration">
    $([[ $test_result == "failed" ]] && echo '<failure message="E2E test failed">Test execution failed</failure>')
  </testcase>
  <system-out><![CDATA[
Test Type: $TEST_TYPE
Environment: $ENVIRONMENT
Message Count: $MESSAGE_COUNT
Data Format: $DATA_FORMAT
Duration: ${duration}s
Log File: $LOG_FILE
  ]]></system-out>
</testsuite>
EOF
    
    log_info "JUnit report created: $report_file"
}

# Cleanup test resources
cleanup_test_resources() {
    if [[ "$CLEANUP_AFTER" == "true" && "$DEPLOY_MODE" == "false" ]]; then
        log_info "Cleaning up test resources..."
        
        cd "$PROJECT_ROOT/terraform"
        
        if terraform destroy -auto-approve -var-file="../config/environments/${ENVIRONMENT}.yaml"; then
            log_success "Test resources cleaned up successfully"
        else
            log_warning "Some test resources may not have been cleaned up properly"
        fi
    else
        log_info "Skipping cleanup (cleanup disabled or deploy mode active)"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-type=*)
                TEST_TYPE="${1#*=}"
                shift
                ;;
            --env=*)
                ENVIRONMENT="${1#*=}"
                shift
                ;;
            --message-count=*)
                MESSAGE_COUNT="${1#*=}"
                shift
                ;;
            --data-format=*)
                DATA_FORMAT="${1#*=}"
                shift
                ;;
            --timeout=*)
                TIMEOUT="${1#*=}"
                shift
                ;;
            --deploy-mode)
                DEPLOY_MODE=true
                CLEANUP_AFTER=false
                shift
                ;;
            --no-cleanup)
                CLEANUP_AFTER=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                set -x
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
    local START_TIME=$(date +%s)
    export START_TIME
    
    log_info "Starting E2E Data Flow Test"
    log_info "Test Type: $TEST_TYPE"
    log_info "Environment: $ENVIRONMENT"
    log_info "Message Count: $MESSAGE_COUNT"
    log_info "Data Format: $DATA_FORMAT"
    
    # Validate test type
    if [[ -z "${TEST_CONFIGS[$TEST_TYPE]:-}" ]]; then
        log_error "Invalid test type: $TEST_TYPE"
        log_error "Available test types: ${!TEST_CONFIGS[*]}"
        exit 1
    fi
    
    # Set up trap for cleanup on exit
    trap cleanup_test_resources EXIT
    
    # Execute test pipeline
    setup_directories
    validate_environment
    generate_test_data
    setup_test_infrastructure
    
    # Execute test with timeout
    if timeout "${TIMEOUT}" bash -c "execute_test"; then
        log_success "E2E test completed successfully"
        create_junit_report "passed"
        exit 0
    else
        log_error "E2E test failed or timed out"
        create_junit_report "failed"
        exit 1
    fi
}

# Parse arguments and run main function
parse_arguments "$@"
main
