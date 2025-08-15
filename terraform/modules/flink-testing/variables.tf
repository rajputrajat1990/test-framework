# Sprint 4: Variables for Flink Testing Module

variable "test_prefix" {
  description = "Prefix for all test resources"
  type        = string
  default     = "flink-test"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.test_prefix))
    error_message = "Test prefix must contain only alphanumeric characters, hyphens, and underscores."
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

variable "organization_id" {
  description = "Confluent Cloud organization ID"
  type        = string
  default     = null
}

# Compute Pool Configuration
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
  default     = 10
  validation {
    condition     = var.max_cfu >= 1 && var.max_cfu <= 100
    error_message = "Max CFU must be between 1 and 100."
  }
}

# Topic Configuration
variable "source_topic_partitions" {
  description = "Number of partitions for source topics"
  type        = number
  default     = 6
}

variable "target_topic_partitions" {
  description = "Number of partitions for target topics"
  type        = number
  default     = 3
}

variable "lookup_topic_partitions" {
  description = "Number of partitions for lookup topics"
  type        = number
  default     = 3
}

# Flink Properties
variable "flink_properties" {
  description = "Flink properties for all jobs"
  type        = map(string)
  default = {
    "table.exec.checkpointing.interval"     = "30s"
    "table.exec.checkpointing.mode"         = "EXACTLY_ONCE"
    "execution.checkpointing.externalized-checkpoint-retention" = "RETAIN_ON_CANCELLATION"
    "table.exec.state.ttl"                  = "3600000"  # 1 hour
    "table.optimizer.join-reorder-enabled"  = "true"
    "pipeline.watermark-alignment.alignment-group" = "default"
    "pipeline.watermark-alignment.max-drift" = "30s"
  }
}

# Testing Configuration
variable "enable_validation" {
  description = "Enable validation jobs for testing transformation accuracy"
  type        = bool
  default     = true
}

variable "enable_performance_monitoring" {
  description = "Enable performance monitoring for all jobs"
  type        = bool
  default     = true
}

variable "enable_performance_validation" {
  description = "Enable dedicated performance validation job"
  type        = bool
  default     = false
}

# Test Data Configuration
variable "test_data_config" {
  description = "Configuration for test data generation"
  type = object({
    users_count           = optional(number, 1000)
    events_per_user       = optional(number, 100)
    time_span_hours       = optional(number, 24)
    late_data_percentage  = optional(number, 5)
    error_rate_percentage = optional(number, 1)
  })
  default = {}
}

# Performance Thresholds
variable "performance_thresholds" {
  description = "Performance thresholds for validation"
  type = object({
    min_throughput_events_per_second = optional(number, 1000)
    max_latency_seconds             = optional(number, 5)
    max_checkpoint_duration_seconds = optional(number, 30)
    min_success_rate_percentage     = optional(number, 99)
  })
  default = {}
}

# Quality Gates
variable "quality_gates" {
  description = "Quality gates for transformation validation"
  type = object({
    min_data_completeness_percentage = optional(number, 99.9)
    max_error_rate_percentage        = optional(number, 0.1)
    min_join_success_rate_percentage = optional(number, 95)
    max_late_data_percentage         = optional(number, 5)
  })
  default = {}
}

# Monitoring Configuration
variable "monitoring_config" {
  description = "Configuration for monitoring and alerting"
  type = object({
    enable_alerts                = optional(bool, true)
    alert_cpu_threshold         = optional(number, 80)
    alert_memory_threshold      = optional(number, 85)
    alert_checkpoint_failure_threshold = optional(number, 3)
    metrics_collection_interval = optional(string, "1m")
  })
  default = {}
}

# Resource Limits
variable "resource_limits" {
  description = "Resource limits for Flink jobs"
  type = object({
    max_parallelism    = optional(number, 10)
    memory_per_slot_mb = optional(number, 1024)
    network_memory_mb  = optional(number, 128)
    managed_memory_mb  = optional(number, 256)
  })
  default = {}
}

# Checkpointing Configuration
variable "checkpointing_config" {
  description = "Checkpointing configuration for all jobs"
  type = object({
    interval_seconds           = optional(number, 30)
    timeout_seconds           = optional(number, 600)
    min_pause_between_seconds = optional(number, 5)
    max_concurrent_checkpoints = optional(number, 1)
    cleanup_mode              = optional(string, "RETAIN_ON_CANCELLATION")
  })
  default = {}
}

# Watermark Configuration
variable "watermark_config" {
  description = "Watermark configuration for event time processing"
  type = object({
    max_out_of_orderness_seconds = optional(number, 5)
    idle_source_timeout_seconds  = optional(number, 300)
    alignment_timeout_seconds    = optional(number, 30)
    alignment_max_drift_seconds  = optional(number, 30)
  })
  default = {}
}

# Error Handling Configuration
variable "error_handling_config" {
  description = "Error handling configuration"
  type = object({
    enable_dead_letter_queue = optional(bool, true)
    max_retry_attempts       = optional(number, 3)
    retry_delay_seconds      = optional(number, 10)
    stop_on_error           = optional(bool, false)
  })
  default = {}
}

# Test Scenarios
variable "test_scenarios" {
  description = "List of test scenarios to execute"
  type        = list(string)
  default     = ["user_enrichment", "event_aggregation", "windowed_analytics"]
  validation {
    condition = alltrue([
      for scenario in var.test_scenarios : 
      contains(["user_enrichment", "event_aggregation", "windowed_analytics", "stream_joins", "anomaly_detection"], scenario)
    ])
    error_message = "Invalid test scenario. Must be one of: user_enrichment, event_aggregation, windowed_analytics, stream_joins, anomaly_detection."
  }
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# Cleanup Configuration
variable "cleanup_config" {
  description = "Configuration for resource cleanup"
  type = object({
    auto_cleanup_on_destroy = optional(bool, true)
    retain_logs            = optional(bool, true)
    cleanup_timeout_minutes = optional(number, 30)
  })
  default = {}
}
