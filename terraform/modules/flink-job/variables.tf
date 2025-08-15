# Sprint 4: Variables for Flink Job Module

variable "statement_name" {
  description = "Name of the Flink statement/job"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.statement_name))
    error_message = "Statement name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka cluster ID"
  type        = string
}

variable "compute_pool_id" {
  description = "Confluent Cloud Flink compute pool ID"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID for Flink operations"
  type        = string
}

# SQL Configuration
variable "sql_file_path" {
  description = "Path to the SQL file containing the Flink statement"
  type        = string
}

variable "sql_template_variables" {
  description = "Template variables to substitute in the SQL file"
  type        = map(string)
  default     = {}
}

variable "source_table_name" {
  description = "Name of the source table for the transformation"
  type        = string
  default     = "user_events_source"
}

variable "target_table_name" {
  description = "Name of the target table for the transformation"
  type        = string
  default     = "user_events_transformed"
}

# Flink Properties
variable "flink_properties" {
  description = "Additional Flink properties for the statement"
  type        = map(string)
  default     = {
    "table.exec.checkpointing.interval" = "10s"
    "table.exec.checkpointing.mode"     = "EXACTLY_ONCE"
    "execution.checkpointing.externalized-checkpoint-retention" = "RETAIN_ON_CANCELLATION"
  }
}

# Statement Configuration
variable "stop_on_error" {
  description = "Whether to stop execution on error"
  type        = bool
  default     = true
}

variable "statement_creation_wait_time" {
  description = "Time to wait after creating the statement"
  type        = string
  default     = "30s"
}

# Validation Configuration
variable "enable_validation" {
  description = "Enable validation job to test transformation results"
  type        = bool
  default     = false
}

variable "validation_sql_file_path" {
  description = "Path to the SQL file containing validation queries"
  type        = string
  default     = ""
}

# Performance Monitoring
variable "enable_performance_monitoring" {
  description = "Enable performance monitoring for the job"
  type        = bool
  default     = false
}

variable "performance_monitoring_interval" {
  description = "Interval for performance monitoring (in minutes)"
  type        = number
  default     = 5
}

# Job Lifecycle Management
variable "auto_start" {
  description = "Automatically start the job after creation"
  type        = bool
  default     = true
}

variable "auto_cleanup" {
  description = "Automatically clean up resources on destroy"
  type        = bool
  default     = true
}

# Error Handling
variable "retry_on_failure" {
  description = "Retry job creation on failure"
  type        = bool
  default     = true
}

variable "max_retries" {
  description = "Maximum number of retries on failure"
  type        = number
  default     = 3
}

# Resource Limits
variable "parallelism" {
  description = "Parallelism for the Flink job"
  type        = number
  default     = 1
}

variable "memory_limit" {
  description = "Memory limit for the Flink job (in MB)"
  type        = number
  default     = 512
}

# Checkpointing Configuration
variable "checkpoint_interval" {
  description = "Checkpoint interval for the job"
  type        = string
  default     = "30s"
}

variable "checkpoint_timeout" {
  description = "Checkpoint timeout for the job"
  type        = string
  default     = "10m"
}

variable "min_pause_between_checkpoints" {
  description = "Minimum pause between checkpoints"
  type        = string
  default     = "5s"
}

# Watermark Configuration
variable "watermark_idle_timeout" {
  description = "Watermark idle timeout"
  type        = string
  default     = "5min"
}

variable "max_out_of_orderness" {
  description = "Maximum out-of-orderness for event time"
  type        = string
  default     = "5s"
}

# Testing Configuration
variable "test_mode" {
  description = "Enable test mode with additional validation"
  type        = bool
  default     = false
}

variable "test_data_size" {
  description = "Size of test data for validation"
  type        = number
  default     = 1000
}

variable "test_timeout" {
  description = "Timeout for test execution"
  type        = string
  default     = "10m"
}

# Tags
variable "tags" {
  description = "Additional tags for the Flink job"
  type        = map(string)
  default     = {}
}
