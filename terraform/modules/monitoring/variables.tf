# Monitoring Module Variables

variable "environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud cluster ID"
  type        = string
}

variable "organization_id" {
  description = "Confluent Cloud organization ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the Kafka cluster"
  type        = string
}

variable "sumo_collector_id" {
  description = "Sumo Logic collector ID"
  type        = string
}

variable "log_topics" {
  description = "List of topics to stream to Sumo Logic"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "monitoring_config" {
  description = "Monitoring and observability configuration"
  type = object({
    # Sumo Logic connector settings
    connector_tasks     = optional(number, 2)
    batch_size         = optional(number, 100)
    batch_timeout      = optional(number, 5000)
    
    # Topic configuration
    log_partitions     = optional(number, 3)
    log_retention_ms   = optional(number, 604800000)      # 7 days
    metrics_retention_ms = optional(number, 2592000000)   # 30 days
    
    # Metrics collection
    metrics_interval_ms = optional(number, 60000)         # 1 minute
    enable_jmx_metrics = optional(bool, true)
    
    # Alerting
    enable_alerting    = optional(bool, true)
    alert_channels     = optional(list(string), [])
  })
  default = {}
}

# Alert Configuration
variable "alert_config" {
  description = "Alert rules and notification configuration"
  type = object({
    slack_webhook_url    = optional(string, "")
    teams_webhook_url    = optional(string, "")
    pagerduty_key       = optional(string, "")
    email_recipients    = optional(list(string), [])
    alert_channels      = optional(list(string), [])  # Added missing alert_channels
    
    # Alert thresholds
    connector_failure_threshold     = optional(number, 1)
    consumer_lag_threshold         = optional(number, 10000)
    error_rate_threshold           = optional(number, 5)    # percentage
    throughput_drop_threshold      = optional(number, 50)   # percentage
    
    # Notification settings
    notification_cooldown_minutes  = optional(number, 15)
    escalation_delay_minutes       = optional(number, 30)
  })
  default = {}
}

# Dashboard Configuration
variable "dashboard_config" {
  description = "Dashboard and visualization configuration"
  type = object({
    enable_grafana_dashboards = optional(bool, false)
    grafana_url              = optional(string, "")
    grafana_api_key          = optional(string, "")
    
    enable_sumo_dashboards   = optional(bool, true)
    dashboard_folder         = optional(string, "Kafka Monitoring")
    
    # Dashboard components
    include_connector_health = optional(bool, true)
    include_topic_metrics   = optional(bool, true)
    include_consumer_lag    = optional(bool, true)
    include_error_analysis  = optional(bool, true)
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security and access control configuration"
  type = object({
    enable_mtls           = optional(bool, false)
    certificate_authority = optional(string, "")
    client_cert          = optional(string, "")
    client_key           = optional(string, "")
    
    # Access control
    monitoring_principals = optional(list(string), [])
    read_only_access     = optional(bool, true)
  })
  default = {}
}

# Validation Configuration
variable "enable_validation" {
  description = "Enable monitoring setup validation"
  type        = bool
  default     = true
}

variable "validation_config" {
  description = "Validation test configuration"
  type = object({
    test_message_count       = optional(number, 100)
    validation_timeout_minutes = optional(number, 10)
    expected_delivery_rate   = optional(number, 95)  # percentage
    
    # Performance validation
    max_ingestion_latency_ms = optional(number, 30000)  # 30 seconds
    min_throughput_msgs_sec  = optional(number, 10)
  })
  default = {}
}
