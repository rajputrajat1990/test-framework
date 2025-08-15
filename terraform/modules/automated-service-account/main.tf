terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Variables
variable "service_account_name" {
  description = "Name of the service account to create"
  type        = string
}

variable "service_account_description" {
  description = "Description of the service account"
  type        = string
  default     = "Automated service account for Confluent Cloud operations"
}

variable "organization_id" {
  description = "Confluent Cloud Organization ID"
  type        = string
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID (optional, for scoped keys)"
  type        = string
  default     = ""
}

variable "cluster_id" {
  description = "Confluent Cloud Cluster ID (optional, for cluster-scoped keys)"
  type        = string
  default     = ""
}

variable "rbac_roles" {
  description = "Map of RBAC roles to assign to the service account"
  type = map(object({
    role_name   = string
    crn_pattern = string
  }))
  default = {}
}

variable "create_cloud_api_key" {
  description = "Whether to create a cloud-level API key"
  type        = bool
  default     = true
}

variable "create_cluster_api_key" {
  description = "Whether to create a cluster-level API key"
  type        = bool
  default     = false
}

# Service Account
resource "confluent_service_account" "main" {
  display_name = var.service_account_name
  description  = var.service_account_description
}

# RBAC Role Bindings
resource "confluent_role_binding" "main" {
  for_each = var.rbac_roles

  principal   = "User:${confluent_service_account.main.id}"
  role_name   = each.value.role_name
  crn_pattern = each.value.crn_pattern
}

# Cloud-level API Key (for organization-wide operations)
resource "confluent_api_key" "cloud" {
  count = var.create_cloud_api_key ? 1 : 0

  display_name = "${var.service_account_name}-cloud-key"
  description  = "Cloud API key for ${var.service_account_name}"
  
  owner {
    id          = confluent_service_account.main.id
    api_version = confluent_service_account.main.api_version
    kind        = confluent_service_account.main.kind
  }
}

# Cluster-level API Key (for cluster-specific operations)
resource "confluent_api_key" "cluster" {
  count = var.create_cluster_api_key && var.cluster_id != "" ? 1 : 0

  display_name = "${var.service_account_name}-cluster-key"
  description  = "Cluster API key for ${var.service_account_name}"
  
  owner {
    id          = confluent_service_account.main.id
    api_version = confluent_service_account.main.api_version
    kind        = confluent_service_account.main.kind
  }

  managed_resource {
    id               = var.cluster_id
    api_version      = "cmk/v2"
    kind             = "Cluster"
    environment {
      id = var.environment_id
    }
  }
}
