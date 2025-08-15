# Sprint 4: Variables for Flink Compute Pool Module

variable "pool_name" {
  description = "Name of the Flink compute pool"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.pool_name))
    error_message = "Pool name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "organization_id" {
  description = "Confluent Cloud organization ID"
  type        = string
  default     = null
}

variable "cloud_provider" {
  description = "Cloud provider for the compute pool"
  type        = string
  default     = "AWS"
  validation {
    condition     = contains(["AWS", "GCP", "AZURE"], var.cloud_provider)
    error_message = "Cloud provider must be one of: AWS, GCP, AZURE."
  }
}

variable "region" {
  description = "Cloud region for the compute pool"
  type        = string
  default     = "us-west-2"
}

variable "max_cfu" {
  description = "Maximum Confluent Flink Units (CFU) for the compute pool"
  type        = number
  default     = 5
  validation {
    condition     = var.max_cfu >= 1 && var.max_cfu <= 100
    error_message = "Max CFU must be between 1 and 100."
  }
}

variable "tags" {
  description = "Additional tags for the compute pool"
  type        = map(string)
  default     = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a dedicated service account for Flink operations"
  type        = bool
  default     = true
}

variable "service_account_description" {
  description = "Description for the Flink service account"
  type        = string
  default     = "Service account for Flink compute pool operations"
}

# Role Binding Configuration
variable "additional_roles" {
  description = "Additional roles to bind to the Flink service account"
  type = list(object({
    role_name   = string
    crn_pattern = string
  }))
  default = []
}

# API Key Configuration
variable "api_key_description" {
  description = "Description for the Flink API key"
  type        = string
  default     = "API key for Flink compute pool access"
}

# Monitoring and Alerting
variable "enable_monitoring" {
  description = "Enable monitoring for the compute pool"
  type        = bool
  default     = true
}

variable "alert_thresholds" {
  description = "Alert thresholds for compute pool monitoring"
  type = object({
    cpu_utilization    = optional(number, 80)
    memory_utilization = optional(number, 85)
    cfu_utilization    = optional(number, 90)
  })
  default = {}
}

# Timeout Configuration
variable "creation_timeout" {
  description = "Timeout for compute pool creation"
  type        = string
  default     = "10m"
}

variable "deletion_timeout" {
  description = "Timeout for compute pool deletion"
  type        = string
  default     = "5m"
}

# Testing Configuration
variable "test_mode" {
  description = "Enable test mode with additional validation"
  type        = bool
  default     = false
}

variable "test_prefix" {
  description = "Prefix for test resources"
  type        = string
  default     = "test"
}
