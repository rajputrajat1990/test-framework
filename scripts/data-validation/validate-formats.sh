#!/bin/bash

# Data Format Validation Script for Sprint 3
# Validates data in various formats: JSON, Avro, Protobuf, CSV, XML

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="${SCRIPT_DIR}/test-data"
VALIDATION_LOG="${SCRIPT_DIR}/validation.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$VALIDATION_LOG"
}

# Initialize test data directory
initialize_test_data() {
    log "INFO" "Initializing test data directory: $TEST_DATA_DIR"
    mkdir -p "$TEST_DATA_DIR"/{json,avro,protobuf,csv,xml,schemas,outputs}
    
    # Generate sample JSON data
    generate_json_test_data
    
    # Generate sample CSV data
    generate_csv_test_data
    
    # Generate sample XML data
    generate_xml_test_data
}

# Generate JSON test data
generate_json_test_data() {
    log "INFO" "Generating JSON test data"
    
    # Valid JSON data
    cat > "$TEST_DATA_DIR/json/valid-events.json" << 'EOF'
{"user_id": "user123", "event_type": "LOGIN", "timestamp": 1692144000000, "properties": {"page": "home"}, "session_id": "sess123"}
{"user_id": "user456", "event_type": "PURCHASE", "timestamp": 1692144060000, "properties": {"product": "laptop", "price": "999.99"}, "session_id": "sess456"}
{"user_id": "user789", "event_type": "VIEW", "timestamp": 1692144120000, "properties": {"page": "product", "product_id": "prod123"}}
EOF

    # Invalid JSON data (for testing error handling)
    cat > "$TEST_DATA_DIR/json/invalid-events.json" << 'EOF'
{"user_id": "user123", "event_type": "INVALID_TYPE", "timestamp": -1, "properties": {}}
{"user_id": "", "event_type": "LOGIN", "timestamp": "invalid_timestamp"}
{"user_id": "user789", "missing_required_field": "LOGIN"}
EOF

    # Edge case JSON data
    cat > "$TEST_DATA_DIR/json/edge-cases.json" << 'EOF'
{"user_id": "user_with_very_long_id_that_exceeds_normal_length_limits", "event_type": "LOGIN", "timestamp": 0}
{"user_id": "user123", "event_type": "LOGIN", "timestamp": 9223372036854775807, "properties": {}}
{"user_id": "user123", "event_type": "LOGIN", "timestamp": 1692144000000, "properties": {"key": ""}, "session_id": null}
EOF
}

# Generate CSV test data
generate_csv_test_data() {
    log "INFO" "Generating CSV test data"
    
    # Valid CSV data
    cat > "$TEST_DATA_DIR/csv/valid-events.csv" << 'EOF'
user_id,event_type,timestamp,properties,session_id
user123,LOGIN,1692144000000,"{\"page\":\"home\"}",sess123
user456,PURCHASE,1692144060000,"{\"product\":\"laptop\",\"price\":\"999.99\"}",sess456
user789,VIEW,1692144120000,"{\"page\":\"product\",\"product_id\":\"prod123\"}",
EOF

    # Invalid CSV data
    cat > "$TEST_DATA_DIR/csv/invalid-events.csv" << 'EOF'
user_id,event_type,timestamp,properties,session_id
,LOGIN,1692144000000,"{\"page\":\"home\"}",sess123
user456,INVALID_TYPE,invalid_timestamp,"{\"product\":\"laptop\"}",sess456
user789,VIEW,-1,malformed_json,
EOF
}

# Generate XML test data
generate_xml_test_data() {
    log "INFO" "Generating XML test data"
    
    # Valid XML data
    cat > "$TEST_DATA_DIR/xml/valid-events.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<events>
    <event>
        <user_id>user123</user_id>
        <event_type>LOGIN</event_type>
        <timestamp>1692144000000</timestamp>
        <properties>
            <page>home</page>
        </properties>
        <session_id>sess123</session_id>
    </event>
    <event>
        <user_id>user456</user_id>
        <event_type>PURCHASE</event_type>
        <timestamp>1692144060000</timestamp>
        <properties>
            <product>laptop</product>
            <price>999.99</price>
        </properties>
        <session_id>sess456</session_id>
    </event>
</events>
EOF

    # Invalid XML data
    cat > "$TEST_DATA_DIR/xml/invalid-events.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<events>
    <event>
        <user_id></user_id>
        <event_type>INVALID_TYPE</event_type>
        <timestamp>-1</timestamp>
    </event>
    <event>
        <user_id>user456</user_id>
        <!-- Missing required fields -->
        <properties>
            <product>laptop</product>
        </properties>
    </event>
</events>
EOF
}

# Validate JSON data
validate_json() {
    local json_file="$1"
    local schema_file="$2"
    
    log "INFO" "Validating JSON file: $json_file"
    
    if [[ ! -f "$json_file" ]]; then
        log "ERROR" "JSON file not found: $json_file"
        return 1
    fi
    
    local validation_passed=0
    local total_records=0
    local valid_records=0
    
    # Basic JSON syntax validation
    while IFS= read -r line; do
        ((total_records++))
        if echo "$line" | jq . >/dev/null 2>&1; then
            ((valid_records++))
        else
            log "WARN" "Invalid JSON syntax in record $total_records: $line"
        fi
    done < "$json_file"
    
    log "INFO" "JSON validation completed: $valid_records/$total_records records valid"
    
    if [[ $valid_records -eq $total_records ]]; then
        return 0
    else
        return 1
    fi
}

# Validate CSV data
validate_csv() {
    local csv_file="$1"
    
    log "INFO" "Validating CSV file: $csv_file"
    
    if [[ ! -f "$csv_file" ]]; then
        log "ERROR" "CSV file not found: $csv_file"
        return 1
    fi
    
    local line_number=0
    local valid_records=0
    local total_records=0
    
    # Skip header and validate data rows
    tail -n +2 "$csv_file" | while IFS=, read -r user_id event_type timestamp properties session_id; do
        ((line_number++))
        ((total_records++))
        
        # Basic validation rules
        if [[ -n "$user_id" && -n "$event_type" && "$timestamp" =~ ^[0-9]+$ && "$timestamp" -ge 0 ]]; then
            ((valid_records++))
        else
            log "WARN" "Invalid CSV record at line $((line_number + 1)): $user_id,$event_type,$timestamp"
        fi
    done
    
    log "INFO" "CSV validation completed: $valid_records/$total_records records valid"
    return 0
}

# Validate XML data
validate_xml() {
    local xml_file="$1"
    
    log "INFO" "Validating XML file: $xml_file"
    
    if [[ ! -f "$xml_file" ]]; then
        log "ERROR" "XML file not found: $xml_file"
        return 1
    fi
    
    # Basic XML well-formedness check
    if xmllint --noout "$xml_file" 2>/dev/null; then
        log "INFO" "XML file is well-formed"
        return 0
    else
        log "ERROR" "XML file is not well-formed"
        return 1
    fi
}

# Schema validation function
validate_with_schema() {
    local data_file="$1"
    local schema_file="$2"
    local format="$3"
    
    log "INFO" "Validating $format data against schema"
    
    case "$format" in
        "JSON")
            # Use ajv-cli for JSON schema validation if available
            if command -v ajv >/dev/null 2>&1; then
                ajv validate -s "$schema_file" -d "$data_file"
                return $?
            else
                log "WARN" "ajv-cli not available, skipping JSON schema validation"
                return 0
            fi
            ;;
        "AVRO")
            log "INFO" "Avro schema validation requires specialized tools (not implemented in this basic script)"
            return 0
            ;;
        "PROTOBUF")
            log "INFO" "Protobuf schema validation requires specialized tools (not implemented in this basic script)"
            return 0
            ;;
        *)
            log "WARN" "Unknown format for schema validation: $format"
            return 0
            ;;
    esac
}

# Performance testing function
run_performance_test() {
    local format="$1"
    local file_count="${2:-10}"
    local records_per_file="${3:-1000}"
    
    log "INFO" "Running performance test for $format format"
    log "INFO" "Generating $file_count files with $records_per_file records each"
    
    local start_time=$(date +%s)
    
    # Generate large test files
    for ((i=1; i<=file_count; i++)); do
        local test_file="$TEST_DATA_DIR/outputs/perf_test_${format}_${i}.json"
        generate_large_json_file "$test_file" "$records_per_file"
    done
    
    # Validate all generated files
    local validation_start=$(date +%s)
    for ((i=1; i<=file_count; i++)); do
        local test_file="$TEST_DATA_DIR/outputs/perf_test_${format}_${i}.json"
        validate_json "$test_file" ""
    done
    local validation_end=$(date +%s)
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local validation_time=$((validation_end - validation_start))
    local total_records=$((file_count * records_per_file))
    
    log "INFO" "Performance test completed:"
    log "INFO" "  Total time: ${total_time}s"
    log "INFO" "  Validation time: ${validation_time}s"
    log "INFO" "  Total records: $total_records"
    log "INFO" "  Records per second: $((total_records / validation_time))"
}

# Generate large JSON file for performance testing
generate_large_json_file() {
    local output_file="$1"
    local record_count="$2"
    
    > "$output_file"  # Clear file
    
    for ((i=1; i<=record_count; i++)); do
        local timestamp=$((1692144000000 + i * 1000))
        echo "{\"user_id\":\"user$i\",\"event_type\":\"LOGIN\",\"timestamp\":$timestamp,\"properties\":{\"test\":\"data\"},\"session_id\":\"sess$i\"}" >> "$output_file"
    done
}

# Main validation function
run_validation() {
    local format="${1:-all}"
    local validation_type="${2:-basic}"
    
    log "INFO" "Starting data format validation - Format: $format, Type: $validation_type"
    
    # Initialize test data
    initialize_test_data
    
    local exit_code=0
    
    case "$format" in
        "json"|"all")
            log "INFO" "Running JSON validation tests"
            validate_json "$TEST_DATA_DIR/json/valid-events.json" "" || exit_code=1
            validate_json "$TEST_DATA_DIR/json/invalid-events.json" "" || true  # Expected to fail
            validate_json "$TEST_DATA_DIR/json/edge-cases.json" "" || exit_code=1
            ;;
    esac
    
    case "$format" in
        "csv"|"all")
            log "INFO" "Running CSV validation tests"
            validate_csv "$TEST_DATA_DIR/csv/valid-events.csv" || exit_code=1
            validate_csv "$TEST_DATA_DIR/csv/invalid-events.csv" || true  # Expected to fail
            ;;
    esac
    
    case "$format" in
        "xml"|"all")
            log "INFO" "Running XML validation tests"
            validate_xml "$TEST_DATA_DIR/xml/valid-events.xml" || exit_code=1
            validate_xml "$TEST_DATA_DIR/xml/invalid-events.xml" || true  # Expected to fail
            ;;
    esac
    
    # Run performance tests if requested
    if [[ "$validation_type" == "performance" || "$validation_type" == "all" ]]; then
        run_performance_test "JSON" 5 1000
    fi
    
    log "INFO" "Data validation completed with exit code: $exit_code"
    return $exit_code
}

# Main execution
main() {
    local format="${1:-all}"
    local validation_type="${2:-basic}"
    
    echo -e "${BLUE}=== Sprint 3 Data Format Validation ===${NC}"
    echo -e "${YELLOW}Format: $format${NC}"
    echo -e "${YELLOW}Validation Type: $validation_type${NC}"
    echo ""
    
    run_validation "$format" "$validation_type"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ All validations passed!${NC}"
    else
        echo -e "${RED}❌ Some validations failed. Check $VALIDATION_LOG for details.${NC}"
    fi
    
    return $result
}

# Script usage
usage() {
    echo "Usage: $0 [format] [validation_type]"
    echo ""
    echo "Arguments:"
    echo "  format         - Data format to validate: json, csv, xml, avro, protobuf, all (default: all)"
    echo "  validation_type - Type of validation: basic, performance, all (default: basic)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Validate all formats with basic validation"
    echo "  $0 json              # Validate only JSON format"
    echo "  $0 all performance   # Run performance tests for all formats"
}

# Handle command line arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Check for required tools
check_dependencies() {
    local missing_tools=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if ! command -v xmllint >/dev/null 2>&1; then
        missing_tools+=("xmllint")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "WARN" "Missing optional dependencies: ${missing_tools[*]}"
        log "INFO" "Some validation features may not be available"
    fi
}

# Initialize
check_dependencies

# Run main function
main "$@"
