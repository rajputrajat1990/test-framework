terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Input variables
variable "connector_name" {
  description = "Name of the S3 Source connector"
  type        = string
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "topics_dir" {
  description = "Directory in S3 where topics are located"
  type        = string
  default     = "topics"
}

variable "input_data_format" {
  description = "Input data format (JSON, AVRO, etc.)"
  type        = string
  default     = "JSON"
}

variable "output_data_format" {
  description = "Output data format (JSON, AVRO, etc.)"
  type        = string
  default     = "JSON"
}

variable "kafka_auth_mode" {
  description = "Kafka authentication mode"
  type        = string
  default     = "KAFKA_API_KEY"
}

variable "kafka_api_key" {
  description = "Kafka API Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kafka_api_secret" {
  description = "Kafka API Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tasks_max" {
  description = "Maximum number of tasks"
  type        = number
  default     = 1
}

# Data source to get cluster information
data "confluent_kafka_cluster" "cluster" {
  id = var.cluster_id
  environment {
    id = var.environment_id
  }
}

# Create S3 Source connector
resource "confluent_connector" "s3_source" {
  environment {
    id = var.environment_id
  }
  
  kafka_cluster {
    id = var.cluster_id
  }

  config_sensitive = {
    "aws.access.key.id"     = var.aws_access_key_id
    "aws.secret.access.key" = var.aws_secret_access_key
    "kafka.api.key"         = var.kafka_api_key != "" ? var.kafka_api_key : ""
    "kafka.api.secret"      = var.kafka_api_secret != "" ? var.kafka_api_secret : ""
  }

  config_nonsensitive = {
    "connector.class"          = "S3Source"
    "name"                     = var.connector_name
    "kafka.auth.mode"          = var.kafka_auth_mode
    "s3.bucket.name"           = var.s3_bucket
    "topics.dir"               = var.topics_dir
    "input.data.format"        = var.input_data_format
    "output.data.format"       = var.output_data_format
    "tasks.max"                = tostring(var.tasks_max)
    "file.reader.settings"     = jsonencode({})
    "schema.registry.auth.mode" = "AUTO"
  }

  depends_on = [
    data.confluent_kafka_cluster.cluster
  ]
}

# Outputs
output "connector_id" {
  description = "ID of the created connector"
  value       = confluent_connector.s3_source.id
}

output "connector_name" {
  description = "Name of the created connector"
  value       = confluent_connector.s3_source.config_nonsensitive["name"]
}

output "connector_status" {
  description = "Status of the connector"
  value       = confluent_connector.s3_source.status
}

output "connector_class" {
  description = "Connector class"
  value       = confluent_connector.s3_source.config_nonsensitive["connector.class"]
}

# Resource validation outputs
output "validation_data" {
  description = "Data for resource validation"
  value = {
    resource_count = 1
    resource_type  = "confluent_connector"
    expected_properties = {
      connector_name  = var.connector_name
      connector_class = "S3Source"
      s3_bucket      = var.s3_bucket
      tasks_max      = var.tasks_max
    }
    created_properties = {
      connector_name  = confluent_connector.s3_source.config_nonsensitive["name"]
      connector_class = confluent_connector.s3_source.config_nonsensitive["connector.class"]
      s3_bucket      = confluent_connector.s3_source.config_nonsensitive["s3.bucket.name"]
      tasks_max      = tonumber(confluent_connector.s3_source.config_nonsensitive["tasks.max"])
    }
    api_verification = {
      check_connector_exists = true
      verify_connector_status = ["RUNNING", "PAUSED"]
    }
  }
}
