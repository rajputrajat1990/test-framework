# Service Account Configuration Variables
variable "service_account_name" {
  description = "Name of the service account to create"
  type        = string
  validation {
    condition     = length(var.service_account_name) > 0
    error_message = "Service account name cannot be empty."
  }
}

variable "service_account_description" {
  description = "Description of the service account"
  type        = string
  default     = "Automated service account for Confluent Cloud operations"
}

# Confluent Cloud Resource IDs
variable "organization_id" {
  description = "Confluent Cloud Organization ID"
  type        = string
  validation {
    condition     = length(var.organization_id) > 0
    error_message = "Organization ID cannot be empty."
  }
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

# RBAC Configuration
variable "rbac_roles" {
  description = "Map of RBAC roles to assign to the service account"
  type = map(object({
    role_name   = string
    crn_pattern = string
  }))
  default = {}
  
  validation {
    condition = alltrue([
      for k, v in var.rbac_roles : contains([
        "OrganizationAdmin",
        "EnvironmentAdmin", 
        "CloudClusterAdmin",
        "DeveloperManage",
        "DeveloperWrite",
        "DeveloperRead",
        "ResourceOwner",
        "Operator",
        "MetricsViewer"
      ], v.role_name)
    ])
    error_message = "Invalid role name. Must be one of the supported Confluent Cloud roles."
  }
}

# API Key Configuration
variable "create_cloud_api_key" {
  description = "Whether to create a cloud-level API key for organization-wide operations"
  type        = bool
  default     = true
}

variable "create_cluster_api_key" {
  description = "Whether to create a cluster-level API key for cluster-specific operations"
  type        = bool
  default     = false
}

# Advanced Configuration
variable "tags" {
  description = "Tags to apply to the service account and API keys"
  type        = map(string)
  default     = {}
}
