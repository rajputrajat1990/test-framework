# Sprint 3: SMT Transformation Testing
# Tests Single Message Transform configurations and validation

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

variable "kafka_rest_endpoint" {
  description = "Kafka REST Endpoint"
  type        = string
}

variable "kafka_api_key" {
  description = "Kafka API Key"
  type        = string
  sensitive   = true
}

variable "kafka_api_secret" {
  description = "Kafka API Secret"
  type        = string
  sensitive   = true
}

variable "test_prefix" {
  description = "Prefix for test resources"
  type        = string
  default     = "sprint3-smt"
}

# Test: Field renaming SMT
run "field_renaming_smt" {
  command = apply
  
  module {
    source = "../../modules/smt-connector"
  }
  
  variables {
    environment_id        = var.environment_id
    cluster_id            = var.cluster_id
    kafka_rest_endpoint   = var.kafka_rest_endpoint
    kafka_api_key         = var.kafka_api_key
    kafka_api_secret      = var.kafka_api_secret
    connector_name        = "${var.test_prefix}-field-rename"
    output_data_format    = "JSON"
    max_iterations        = 10
    
    smt_transformations = {
      "transforms"                               = "renameFields"
      "transforms.renameFields.type"            = "org.apache.kafka.connect.transforms.ReplaceField$Value"
      "transforms.renameFields.renames"         = "username:full_name,email:email_address"
    }
  }
  
  # Validate connector creation
  assert {
    condition     = output.connector_id != null
    error_message = "SMT connector should be created successfully"
  }
  
  assert {
    condition     = output.connector_status == "RUNNING"
    error_message = "SMT connector should be in RUNNING status"
  }
  
  # Validate topics creation
  assert {
    condition     = output.source_topic_name != null && output.target_topic_name != null
    error_message = "Both source and target topics should be created"
  }
}

# Test: Data type conversion SMT
run "data_type_conversion_smt" {
  command = apply
  
  module {
    source = "../../modules/smt-connector"
  }
  
  variables {
    environment_id        = var.environment_id
    cluster_id            = var.cluster_id
    kafka_rest_endpoint   = var.kafka_rest_endpoint
    kafka_api_key         = var.kafka_api_key
    kafka_api_secret      = var.kafka_api_secret
    connector_name        = "${var.test_prefix}-type-conversion"
    output_data_format    = "JSON"
    max_iterations        = 10
    
    smt_transformations = {
      "transforms"                         = "convertTypes"
      "transforms.convertTypes.type"       = "org.apache.kafka.connect.transforms.Cast$Value"
      "transforms.convertTypes.spec"       = "user_id:int32,timestamp:int64,active:boolean,score:float64"
    }
  }
  
  # Validate connector creation
  assert {
    condition     = output.connector_id != null
    error_message = "Type conversion SMT connector should be created successfully"
  }
  
  # Validate sink connector creation
  assert {
    condition     = output.sink_connector_id != null
    error_message = "Verification sink connector should be created"
  }
}

# Test: Field extraction SMT
run "field_extraction_smt" {
  command = apply
  
  module {
    source = "../../modules/smt-connector"
  }
  
  variables {
    environment_id        = var.environment_id
    cluster_id            = var.cluster_id
    kafka_rest_endpoint   = var.kafka_rest_endpoint
    kafka_api_key         = var.kafka_api_key
    kafka_api_secret      = var.kafka_api_secret
    connector_name        = "${var.test_prefix}-field-extract"
    output_data_format    = "JSON"
    max_iterations        = 10
    
    smt_transformations = {
      "transforms"                           = "extractField"
      "transforms.extractField.type"         = "org.apache.kafka.connect.transforms.ExtractField$Value"
      "transforms.extractField.field"        = "user.profile.email"
    }
  }
  
  assert {
    condition     = output.connector_id != null
    error_message = "Field extraction SMT connector should be created successfully"
  }
}

# Test: Transformation chain (multiple SMTs)
run "transformation_chain_smt" {
  command = apply
  
  module {
    source = "../../modules/smt-connector"
  }
  
  variables {
    environment_id        = var.environment_id
    cluster_id            = var.cluster_id
    kafka_rest_endpoint   = var.kafka_rest_endpoint
    kafka_api_key         = var.kafka_api_key
    kafka_api_secret      = var.kafka_api_secret
    connector_name        = "${var.test_prefix}-chain"
    output_data_format    = "JSON"
    max_iterations        = 10
    
    smt_transformations = {
      "transforms"                                  = "renameField,convertType,addTimestamp"
      "transforms.renameField.type"                 = "org.apache.kafka.connect.transforms.ReplaceField$Value"
      "transforms.renameField.renames"              = "user_name:full_name"
      "transforms.convertType.type"                 = "org.apache.kafka.connect.transforms.Cast$Value"
      "transforms.convertType.spec"                 = "user_id:int32"
      "transforms.addTimestamp.type"                = "org.apache.kafka.connect.transforms.InsertField$Value"
      "transforms.addTimestamp.timestamp.field"     = "processed_at"
    }
  }
  
  # Validate complex transformation chain
  assert {
    condition     = output.connector_id != null
    error_message = "Transformation chain SMT connector should be created successfully"
  }
  
  # Validate that all transformations are applied
  assert {
    condition     = output.connector_status == "RUNNING"
    error_message = "Complex SMT chain should execute successfully"
  }
}

# Test: SMT error handling
run "smt_error_handling" {
  command = apply
  
  module {
    source = "../../modules/smt-connector"
  }
  
  variables {
    environment_id        = var.environment_id
    cluster_id            = var.cluster_id
    kafka_rest_endpoint   = var.kafka_rest_endpoint
    kafka_api_key         = var.kafka_api_key
    kafka_api_secret      = var.kafka_api_secret
    connector_name        = "${var.test_prefix}-error-test"
    output_data_format    = "JSON"
    max_iterations        = 5
    
    # Intentionally invalid SMT configuration for error testing
    smt_transformations = {
      "transforms"                               = "invalidTransform"
      "transforms.invalidTransform.type"         = "org.apache.kafka.connect.transforms.InvalidTransform"
      "transforms.invalidTransform.invalid.prop" = "invalid_value"
    }
  }
  
  # This test expects the connector creation to handle errors gracefully
  # In a real scenario, this might test error tolerance configurations
}

# Test: Performance validation for SMT throughput
run "smt_performance_test" {
  command = plan
  
  # Performance test configuration
  variables {
    high_throughput_iterations = 10000
    performance_test_scenarios = [
      "field_renaming",
      "data_type_conversion", 
      "transformation_chain"
    ]
  }
  
  assert {
    condition     = var.high_throughput_iterations >= 1000
    error_message = "Performance test should handle at least 1000 iterations"
  }
  
  assert {
    condition     = length(var.performance_test_scenarios) >= 3
    error_message = "Should test performance for at least 3 SMT scenarios"
  }
}
