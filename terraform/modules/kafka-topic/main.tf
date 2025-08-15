terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Input variables
variable "topic_name" {
  description = "Name of the Kafka topic"
  type        = string
}

variable "partitions" {
  description = "Number of partitions for the topic"
  type        = number
  default     = 3
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  type        = string
}

variable "topic_config" {
  description = "Topic configuration settings"
  type        = map(string)
  default = {
    "cleanup.policy"                = "delete"
    "retention.ms"                 = "604800000"  # 7 days
    "segment.ms"                   = "86400000"   # 1 day
    "min.insync.replicas"          = "2"
  }
}

variable "rest_endpoint" {
  description = "REST endpoint of the Kafka cluster"
  type        = string
  default     = ""
}

variable "credentials" {
  description = "Kafka cluster credentials"
  type = object({
    key    = string
    secret = string
  })
  sensitive = true
  default = {
    key    = ""
    secret = ""
  }
}

# Data source to get cluster information
data "confluent_kafka_cluster" "cluster" {
  count = var.rest_endpoint == "" ? 1 : 0
  id = var.cluster_id
  environment {
    id = var.environment_id
  }
}

# Create Kafka topic
resource "confluent_kafka_topic" "main" {
  kafka_cluster {
    id = var.cluster_id
  }
  
  topic_name       = var.topic_name
  partitions_count = var.partitions
  
  rest_endpoint = var.rest_endpoint != "" ? var.rest_endpoint : data.confluent_kafka_cluster.cluster[0].rest_endpoint
  
  dynamic "credentials" {
    for_each = var.credentials.key != "" ? [1] : []
    content {
      key    = var.credentials.key
      secret = var.credentials.secret
    }
  }
  
  config = var.topic_config
}

# Outputs
output "topic_name" {
  description = "Name of the created topic"
  value       = confluent_kafka_topic.main.topic_name
}

output "topic_id" {
  description = "ID of the created topic"
  value       = confluent_kafka_topic.main.id
}

output "partitions_count" {
  description = "Number of partitions"
  value       = confluent_kafka_topic.main.partitions_count
}

output "config" {
  description = "Topic configuration"
  value       = confluent_kafka_topic.main.config
}

output "rest_endpoint" {
  description = "REST endpoint used"
  value       = confluent_kafka_topic.main.rest_endpoint
}

# Resource validation outputs
output "validation_data" {
  description = "Data for resource validation"
  value = {
    resource_count = 1
    resource_type  = "confluent_kafka_topic"
    expected_properties = {
      topic_name       = var.topic_name
      partitions_count = var.partitions
      config           = var.topic_config
    }
    created_properties = {
      topic_name       = confluent_kafka_topic.main.topic_name
      partitions_count = confluent_kafka_topic.main.partitions_count
      config           = confluent_kafka_topic.main.config
    }
  }
}
