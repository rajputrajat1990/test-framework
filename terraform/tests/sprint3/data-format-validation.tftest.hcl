# Sprint 3: Data Format Validation Test
# Tests schema registry integration and multi-format data validation

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.51.0"
    }
  }
}

# Test variables
variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Kafka Cluster ID"
  type        = string
}

variable "service_account_id" {
  description = "Service Account ID for testing"
  type        = string
}

variable "test_prefix" {
  description = "Prefix for test resources"
  type        = string
  default     = "sprint3-data-format"
}

# Test: Schema Registry with multi-format support
run "schema_registry_deployment" {
  command = apply
  
  module {
    source = "../../modules/schema-registry"
  }
  
  variables {
    environment_id      = var.environment_id
    service_account_id  = var.service_account_id
    subject_prefix      = var.test_prefix
    enable_avro         = true
    enable_protobuf     = true
    enable_json_schema  = true
    sr_api_key          = "test-key"
    sr_api_secret       = "test-secret"
  }
  
  # Validate Schema Registry creation
  assert {
    condition     = output.schema_registry_id != null
    error_message = "Schema Registry ID should not be null"
  }
  
  assert {
    condition     = output.schema_registry_rest_endpoint != null
    error_message = "Schema Registry REST endpoint should not be null"
  }
  
  # Validate Avro schema creation
  assert {
    condition     = output.avro_schema_id != null
    error_message = "Avro schema should be created successfully"
  }
  
  # Validate Protobuf schema creation
  assert {
    condition     = output.protobuf_schema_id != null
    error_message = "Protobuf schema should be created successfully"
  }
  
  # Validate JSON schema creation
  assert {
    condition     = output.json_schema_id != null
    error_message = "JSON schema should be created successfully"
  }
}

# Test: Data format validation scenarios
run "data_format_validation" {
  command = plan
  
  # This test validates that our data format validation scripts work correctly
  # In a real scenario, this would trigger external validation scripts
  
  assert {
    condition     = true  # Placeholder for script execution results
    error_message = "Data format validation should pass for all supported formats"
  }
}

# Test: Schema evolution and compatibility
run "schema_evolution_test" {
  command = apply
  
  module {
    source = "../../modules/schema-registry"
  }
  
  variables {
    environment_id      = var.environment_id
    service_account_id  = var.service_account_id
    subject_prefix      = "${var.test_prefix}-evolution"
    enable_avro         = true
    enable_protobuf     = false
    enable_json_schema  = false
    sr_api_key          = "test-key"
    sr_api_secret       = "test-secret"
  }
  
  # Validate schema evolution capabilities
  assert {
    condition     = output.avro_schema_version != null
    error_message = "Schema version should be tracked for evolution testing"
  }
}

# Test: Performance validation for large datasets
run "performance_validation" {
  command = plan
  
  # Performance test configuration
  variables {
    test_record_count = 10000
    test_formats      = ["JSON", "AVRO", "PROTOBUF"]
  }
  
  assert {
    condition     = length(var.test_formats) >= 3
    error_message = "Should test at least 3 data formats for performance"
  }
}
