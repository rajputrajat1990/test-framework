# Monitoring Module Outputs

# Sumo Logic Integration
output "sumo_logic_integration" {
  description = "Sumo Logic integration details"
  value = {
    http_source_id      = sumologic_http_source.kafka_logs.id
    http_source_url     = sumologic_http_source.kafka_logs.url
    connector_id        = confluent_connector.sumo_logic_sink.id
    connector_status    = confluent_connector.sumo_logic_sink.status
    category           = sumologic_http_source.kafka_logs.category
  }
}

# Monitoring Topics
output "monitoring_topics" {
  description = "Monitoring and logging topics"
  value = {
    logs_topic = {
      id           = confluent_kafka_topic.monitoring_logs.id
      topic_name   = confluent_kafka_topic.monitoring_logs.topic_name
      partitions   = confluent_kafka_topic.monitoring_logs.partitions_count
    }
    metrics_topic = {
      id           = confluent_kafka_topic.connector_metrics.id
      topic_name   = confluent_kafka_topic.connector_metrics.topic_name
      partitions   = confluent_kafka_topic.connector_metrics.partitions_count
    }
    dlq_topic = {
      id           = confluent_kafka_topic.sumo_dlq.id
      topic_name   = confluent_kafka_topic.sumo_dlq.topic_name
      partitions   = confluent_kafka_topic.sumo_dlq.partitions_count
    }
  }
}

# Service Account and API Key
output "monitoring_credentials" {
  description = "Monitoring service account and credentials"
  value = {
    service_account_id   = confluent_service_account.monitoring_sa.id
    service_account_name = confluent_service_account.monitoring_sa.display_name
    api_key_id          = confluent_api_key.monitoring_api_key.id
  }
  sensitive = true
}

# Cluster Metrics
output "cluster_metrics_info" {
  description = "Available cluster metrics information"
  value = {
    cluster_id           = var.cluster_id
    monitoring_enabled   = true
    metrics_collection   = var.monitoring_config.enable_jmx_metrics
    metrics_interval_ms  = var.monitoring_config.metrics_interval_ms
  }
}

# Monitoring Endpoints
output "monitoring_endpoints" {
  description = "Monitoring and observability endpoints"
  value = {
    confluent_metrics_api = "https://api.confluent.cloud/v1/metrics/cloud/clusters/${var.cluster_id}"
    sumo_logic_search    = "https://service.sumologic.com/ui/#/search?q=_sourceCategory%3D%22kafka%2F${var.environment}%2Flogs%22"
    
    # Dashboard URLs (when configured)
    dashboards = {
      cluster_overview    = var.dashboard_config.enable_sumo_dashboards ? "https://service.sumologic.com/ui/#/dashboard" : null
      connector_health    = var.dashboard_config.include_connector_health ? "https://service.sumologic.com/ui/#/dashboard/connector-health" : null
      topic_metrics      = var.dashboard_config.include_topic_metrics ? "https://service.sumologic.com/ui/#/dashboard/topic-metrics" : null
    }
  }
}

# Alert Configuration Status
output "alerting_status" {
  description = "Alert configuration and status"
  value = {
    alerting_enabled = var.monitoring_config.enable_alerting
    configured_channels = length(var.alert_config.alert_channels)
    
    thresholds = {
      connector_failure = var.alert_config.connector_failure_threshold
      consumer_lag     = var.alert_config.consumer_lag_threshold
      error_rate       = var.alert_config.error_rate_threshold
      throughput_drop  = var.alert_config.throughput_drop_threshold
    }
    
    notification_settings = {
      cooldown_minutes    = var.alert_config.notification_cooldown_minutes
      escalation_minutes  = var.alert_config.escalation_delay_minutes
      email_count        = length(var.alert_config.email_recipients)
    }
  }
}

# Validation Results
output "validation_results" {
  description = "Monitoring setup validation results"
  value = {
    validation_enabled = var.enable_validation
    
    connector_validation = {
      connector_created = confluent_connector.sumo_logic_sink.id != ""
      status_check     = confluent_connector.sumo_logic_sink.status
    }
    
    topic_validation = {
      topics_created = [
        confluent_kafka_topic.monitoring_logs.topic_name,
        confluent_kafka_topic.connector_metrics.topic_name,
        confluent_kafka_topic.sumo_dlq.topic_name
      ]
      partition_counts = {
        logs_topic    = confluent_kafka_topic.monitoring_logs.partitions_count
        metrics_topic = confluent_kafka_topic.connector_metrics.partitions_count
        dlq_topic     = confluent_kafka_topic.sumo_dlq.partitions_count
      }
    }
  }
}

# Performance Metrics
output "performance_info" {
  description = "Performance and capacity information"
  value = {
    configuration = {
      batch_size           = var.monitoring_config.batch_size
      batch_timeout        = var.monitoring_config.batch_timeout
      connector_tasks      = var.monitoring_config.connector_tasks
      metrics_interval     = var.monitoring_config.metrics_interval_ms
    }
    
    capacity_planning = {
      log_retention_days    = var.monitoring_config.log_retention_ms / (1000 * 60 * 60 * 24)
      metrics_retention_days = var.monitoring_config.metrics_retention_ms / (1000 * 60 * 60 * 24)
      estimated_daily_volume = "Based on topic configuration and retention"
    }
  }
}

# Integration Summary
output "integration_summary" {
  description = "Complete monitoring integration summary"
  value = {
    environment     = var.environment
    cluster_id      = var.cluster_id
    
    components = {
      sumo_logic_connector = confluent_connector.sumo_logic_sink.id != ""
      monitoring_topics   = length([
        confluent_kafka_topic.monitoring_logs.id,
        confluent_kafka_topic.connector_metrics.id,
        confluent_kafka_topic.sumo_dlq.id
      ])
      service_account    = confluent_service_account.monitoring_sa.id != ""
      rbac_configured    = length(confluent_role_binding.monitoring_cluster_admin.id) > 0
    }
    
    status = "Monitoring integration deployed successfully"
    next_steps = [
      "Configure Sumo Logic dashboards",
      "Set up alert rules and notifications",
      "Test log ingestion and parsing",
      "Validate metrics collection"
    ]
  }
}
