# Multi-module integration test
# Tests dependencies and module interactions

# Setup test environment with shared resources
run "setup_shared_resources" {
  command = apply

  module {
    source = "../../shared"
  }

  variables {
    confluent_cloud_api_key    = var.confluent_cloud_api_key
    confluent_cloud_api_secret = var.confluent_cloud_api_secret
    environment_id             = var.environment_id
    cluster_id                = var.cluster_id
    test_execution_mode       = "apply"
    test_prefix              = "integration"
  }
}

# Test 1: Create Kafka Topic
run "create_kafka_topic" {
  command = apply

  module {
    source = "../../modules/kafka-topic"
  }

  variables {
    topic_name     = "${run.setup_shared_resources.test_resource_name}-topic"
    partitions     = 3
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
    
    topic_config = {
      "cleanup.policy"       = "delete"
      "retention.ms"         = "604800000"
      "min.insync.replicas" = "2"
    }
  }

  assert {
    condition     = output.topic_name == "${run.setup_shared_resources.test_resource_name}-topic"
    error_message = "Topic name validation failed"
  }

  assert {
    condition     = output.partitions_count == 3
    error_message = "Partition count validation failed"
  }
}

# Test 2: Create RBAC for cluster admin
run "create_cluster_admin_rbac" {
  command = apply

  module {
    source = "../../modules/rbac"
  }

  variables {
    principal      = var.test_service_account != "" ? var.test_service_account : "User:test@example.com"
    role           = "CloudClusterAdmin"
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
  }

  assert {
    condition     = output.role_name == "CloudClusterAdmin"
    error_message = "Role name validation failed"
  }

  assert {
    condition     = output.principal == (var.test_service_account != "" ? var.test_service_account : "User:test@example.com")
    error_message = "Principal validation failed"
  }
}

# Test 3: Create topic-specific RBAC (depends on topic creation)
run "create_topic_rbac" {
  command = apply

  module {
    source = "../../modules/rbac"
  }

  variables {
    principal      = var.test_service_account != "" ? var.test_service_account : "User:test@example.com"
    role           = "DeveloperWrite"
    environment_id = var.environment_id
    cluster_id     = var.cluster_id
    topic_name     = run.create_kafka_topic.topic_name
  }

  assert {
    condition     = output.role_name == "DeveloperWrite"
    error_message = "Topic RBAC role validation failed"
  }

  assert {
    condition     = contains(output.crn_pattern, run.create_kafka_topic.topic_name)
    error_message = "Topic RBAC CRN pattern should contain topic name"
  }
}

# Test 4: Validate all resources exist together
run "validate_integration" {
  command = plan

  module {
    source = "./validation"
  }

  variables {
    topic_name          = run.create_kafka_topic.topic_name
    topic_id            = run.create_kafka_topic.topic_id
    cluster_admin_rbac  = run.create_cluster_admin_rbac.role_binding_id
    topic_rbac          = run.create_topic_rbac.role_binding_id
    environment_id      = var.environment_id
    cluster_id          = var.cluster_id
  }
}

# Test variables
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

variable "test_service_account" {
  description = "Service account for RBAC testing"
  type        = string
  default     = ""
}
