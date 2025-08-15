terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Input variables
variable "principal" {
  description = "Principal (User or Service Account) for the role binding"
  type        = string
}

variable "role" {
  description = "Role to assign (e.g., CloudClusterAdmin, DeveloperRead, DeveloperWrite)"
  type        = string
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  type        = string
  default     = ""
}

variable "connector_id" {
  description = "Confluent Cloud Connector ID (for connector-specific permissions)"
  type        = string
  default     = ""
}

variable "topic_name" {
  description = "Topic name for topic-specific permissions"
  type        = string
  default     = ""
}

variable "crn_pattern" {
  description = "Custom CRN pattern for resource-specific permissions"
  type        = string
  default     = ""
}

# Data sources for resource CRN construction
data "confluent_environment" "env" {
  id = var.environment_id
}

data "confluent_kafka_cluster" "cluster" {
  count = var.cluster_id != "" ? 1 : 0
  id = var.cluster_id
  environment {
    id = var.environment_id
  }
}

# Local values for CRN construction
locals {
  # Base CRN patterns
  environment_crn = data.confluent_environment.env.resource_name
  cluster_crn     = var.cluster_id != "" ? data.confluent_kafka_cluster.cluster[0].resource_name : ""
  
  # Determine the appropriate CRN pattern based on inputs
  resource_crn = var.crn_pattern != "" ? var.crn_pattern : (
    var.topic_name != "" && var.cluster_id != "" ? "${local.cluster_crn}/kafka=${var.cluster_id}/topic=${var.topic_name}" : (
      var.connector_id != "" ? "crn://confluent.cloud/organization=*/environment=${var.environment_id}/cloud-cluster=*/connector=${var.connector_id}" : (
        var.cluster_id != "" ? local.cluster_crn : local.environment_crn
      )
    )
  )
}

# Create role binding
resource "confluent_role_binding" "main" {
  principal   = var.principal
  role_name   = var.role
  crn_pattern = local.resource_crn
}

# Outputs
output "role_binding_id" {
  description = "ID of the created role binding"
  value       = confluent_role_binding.main.id
}

output "principal" {
  description = "Principal assigned to the role"
  value       = confluent_role_binding.main.principal
}

output "role_name" {
  description = "Role name assigned"
  value       = confluent_role_binding.main.role_name
}

output "crn_pattern" {
  description = "CRN pattern for the resource"
  value       = confluent_role_binding.main.crn_pattern
}

# Resource validation outputs
output "validation_data" {
  description = "Data for resource validation"
  value = {
    resource_count = 1
    resource_type  = "confluent_role_binding"
    expected_properties = {
      principal   = var.principal
      role_name   = var.role
      crn_pattern = local.resource_crn
    }
    created_properties = {
      principal   = confluent_role_binding.main.principal
      role_name   = confluent_role_binding.main.role_name
      crn_pattern = confluent_role_binding.main.crn_pattern
    }
  }
}
