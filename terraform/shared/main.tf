terraform {
  required_version = ">= 1.12.2"
  
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

# Confluent Cloud Provider Configuration
provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Automated Service Account and API Key Generation
# This creates a service account with orgadmin privileges to automate API key creation
module "automated_api_key_manager" {
  source = "../modules/automated-service-account"

  service_account_name        = "test-framework-api-manager-${random_string.test_suffix.result}"
  service_account_description = "Service account with orgadmin privileges for automated API key generation"
  
  organization_id = var.organization_id
  environment_id  = var.environment_id
  cluster_id      = var.cluster_id
  
  # Grant OrganizationAdmin role for full automation capabilities
  rbac_roles = {
    orgadmin = {
      role_name   = "OrganizationAdmin"
      crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}"
    }
  }
  
  create_cloud_api_key    = true
  create_cluster_api_key  = true
}

# Variables for authentication
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (initial bootstrap key)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret (initial bootstrap key)"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "Confluent Cloud Organization ID"
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

variable "test_execution_mode" {
  description = "Test execution mode: apply or plan"
  type        = string
  default     = "apply"
}

variable "test_prefix" {
  description = "Prefix for test resources"
  type        = string
  default     = "tftest"
}

# Random suffix for test resources
resource "random_string" "test_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Time tracking for test execution
resource "time_static" "test_start" {}

# Outputs for use in modules
output "test_suffix" {
  description = "Random suffix for test resources"
  value       = random_string.test_suffix.result
}

output "test_prefix" {
  description = "Prefix for test resources"
  value       = var.test_prefix
}

output "environment_id" {
  description = "Confluent Cloud Environment ID"
  value       = var.environment_id
}

output "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  value       = var.cluster_id
}

output "test_resource_name" {
  description = "Full test resource name with prefix and suffix"
  value       = "${var.test_prefix}-${random_string.test_suffix.result}"
}

# Automated API Key outputs
output "automated_service_account_id" {
  description = "ID of the automated service account with orgadmin privileges"
  value       = module.automated_api_key_manager.service_account_id
}

output "automated_cloud_api_key_id" {
  description = "ID of the automated cloud API key"
  value       = module.automated_api_key_manager.cloud_api_key_id
  sensitive   = true
}

output "automated_cloud_api_key_secret" {
  description = "Secret of the automated cloud API key"
  value       = module.automated_api_key_manager.cloud_api_key_secret
  sensitive   = true
}

output "automated_cluster_api_key_id" {
  description = "ID of the automated cluster API key"
  value       = module.automated_api_key_manager.cluster_api_key_id
  sensitive   = true
}

output "automated_cluster_api_key_secret" {
  description = "Secret of the automated cluster API key"
  value       = module.automated_api_key_manager.cluster_api_key_secret
  sensitive   = true
}
