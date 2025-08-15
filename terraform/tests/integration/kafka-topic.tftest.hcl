# Integration test for Kafka Topic module
# This test uses terraform test with apply operations to validate
# Kafka topic creation and configuration

# Test configuration
run "setup_test_environment" {
  command = apply

  # Use the shared configuration for test setup
  module {
    source = "../../shared"
  }

  variables {
    confluent_cloud_api_key    = var.confluent_cloud_api_key
    confluent_cloud_api_secret = var.confluent_cloud_api_secret
    environment_id             = var.environment_id
    cluster_id                = var.cluster_id
    test_execution_mode       = "apply"
    test_prefix              = "tftest-topic"
  }
}

# Test Kafka topic creation
run "create_kafka_topic" {
  command = apply

  module {
    source = "../../modules/kafka-topic"
  }

  variables {
    topic_name     = "${run.setup_test_environment.test_resource_name}"
    partitions     = 3
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
    
    topic_config = {
      "cleanup.policy"       = "delete"
      "retention.ms"         = "604800000"
      "min.insync.replicas" = "2"
      "segment.ms"          = "86400000"
    }
  }

  # Validation assertions
  assert {
    condition     = output.topic_name == "${run.setup_test_environment.test_resource_name}"
    error_message = "Topic name does not match expected value"
  }

  assert {
    condition     = output.partitions_count == 3
    error_message = "Partition count does not match expected value of 3"
  }

  assert {
    condition     = output.config["cleanup.policy"] == "delete"
    error_message = "Cleanup policy does not match expected value 'delete'"
  }

  assert {
    condition     = output.config["retention.ms"] == "604800000"
    error_message = "Retention policy does not match expected value"
  }

  assert {
    condition     = can(output.topic_id) && output.topic_id != ""
    error_message = "Topic ID should be generated and not empty"
  }
}

# Test topic validation data
run "validate_topic_data" {
  command = plan

  module {
    source = "../../modules/kafka-topic"
  }

  variables {
    topic_name     = run.create_kafka_topic.topic_name
    partitions     = 3
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
    
    topic_config = {
      "cleanup.policy"       = "delete"
      "retention.ms"         = "604800000"
      "min.insync.replicas" = "2"
      "segment.ms"          = "86400000"
    }
  }

  # Validate the validation_data output structure
  assert {
    condition     = output.validation_data.resource_count == 1
    error_message = "Validation data should indicate 1 resource"
  }

  assert {
    condition     = output.validation_data.resource_type == "confluent_kafka_topic"
    error_message = "Resource type should be confluent_kafka_topic"
  }

  assert {
    condition     = output.validation_data.expected_properties.partitions_count == 3
    error_message = "Expected partitions should be 3"
  }
}

# Test with different configuration
run "create_topic_with_custom_config" {
  command = apply

  module {
    source = "../../modules/kafka-topic"
  }

  variables {
    topic_name     = "${run.setup_test_environment.test_resource_name}-custom"
    partitions     = 6
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
    
    topic_config = {
      "cleanup.policy"       = "compact"
      "retention.ms"         = "1209600000"  # 14 days
      "min.insync.replicas" = "1"
      "compression.type"    = "gzip"
    }
  }

  # Validation for custom configuration
  assert {
    condition     = output.partitions_count == 6
    error_message = "Custom partition count should be 6"
  }

  assert {
    condition     = output.config["cleanup.policy"] == "compact"
    error_message = "Custom cleanup policy should be 'compact'"
  }

  assert {
    condition     = output.config["compression.type"] == "gzip"
    error_message = "Compression type should be 'gzip'"
  }
}

# Variables for the test
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  type        = string
}
