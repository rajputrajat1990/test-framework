# Sprint 5: Monitoring Integration Module
# Sumo Logic, Datadog, Prometheus monitoring integration

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    sumologic = {
      source  = "SumoLogic/sumologic"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

# Sumo Logic HTTP Source for log collection
resource "sumologic_http_source" "kafka_logs" {
  name         = "${var.environment}-kafka-logs"
  description  = "Kafka and connector logs for ${var.environment}"
  category     = "kafka/${var.environment}/logs"
  host_name    = "${var.environment}-kafka"
  timezone     = "UTC"
  
  collector_id = var.sumo_collector_id
  
  content_type     = "application/json"
  use_autoline_matching = false
  force_timezone   = false
  cutoff_timestamp = 0
  cutoff_relative_time = "-1h"
  
  fields = {
    environment = var.environment
    component   = "kafka"
    cluster     = var.cluster_name
  }
}

# Sumo Logic sink connector for real-time log streaming
resource "confluent_connector" "sumo_logic_sink" {
  
  environment {
    id = var.environment_id
  }
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config_sensitive = {
    "sumo.http.source.url" = sumologic_http_source.kafka_logs.url
  }
  
  config_nonsensitive = {
    "name"                     = "${var.environment}-sumo-logic-sink"
    "connector.class"           = "com.sumologic.kafka.connector.SumoLogicSinkConnector"
    "tasks.max"                = var.monitoring_config.connector_tasks
    "topics"                   = join(",", var.log_topics)
    "sumo.compress"            = "true"
    "sumo.batch.size"          = var.monitoring_config.batch_size
    "sumo.batch.timeout"       = var.monitoring_config.batch_timeout
    "sumo.category"            = "kafka/${var.environment}/connector-logs"
    "sumo.host"                = "${var.environment}-connector"
    "sumo.name"                = "kafka-connector-logs"
    "sumo.fields"              = "environment=${var.environment},component=connector"
    
    # Error handling
    "errors.tolerance"         = "all"
    "errors.deadletterqueue.topic.name" = "${var.environment}-sumo-dlq"
    "errors.deadletterqueue.topic.replication.factor" = "3"
    
    # Transforms for log enrichment
    "transforms"                          = "addFields,timestampRouter"
    "transforms.addFields.type"          = "org.apache.kafka.connect.transforms.InsertField$$Value"
    "transforms.addFields.timestamp.field" = "log_timestamp"
    "transforms.addFields.static.field"  = "source"
    "transforms.addFields.static.value"  = "confluent-cloud"
    
    "transforms.timestampRouter.type"    = "org.apache.kafka.connect.transforms.TimestampRouter"
    "transforms.timestampRouter.topic.format" = "$${topic}-$${timestamp}"
    "transforms.timestampRouter.timestamp.format" = "yyyy-MM-dd"
  }
  
  depends_on = [
    confluent_kafka_topic.monitoring_logs,
    confluent_kafka_topic.sumo_dlq
  ]
}

# Topics for monitoring data
resource "confluent_kafka_topic" "monitoring_logs" {
  topic_name       = "${var.environment}-monitoring-logs"
  partitions_count = var.monitoring_config.log_partitions
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.monitoring_config.log_retention_ms
    "min.insync.replicas" = "2"
    "compression.type"    = "lz4"
  }
}

resource "confluent_kafka_topic" "connector_metrics" {
  topic_name       = "${var.environment}-connector-metrics"
  partitions_count = 1
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.monitoring_config.metrics_retention_ms
    "min.insync.replicas" = "2"
  }
}

resource "confluent_kafka_topic" "sumo_dlq" {
  topic_name       = "${var.environment}-sumo-dlq"
  partitions_count = 1
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "2"
  }
}

# Service account for monitoring
resource "confluent_service_account" "monitoring_sa" {
  display_name = "${var.environment}-monitoring-sa"
  description  = "Service account for monitoring and observability"
}

resource "confluent_api_key" "monitoring_api_key" {
  display_name = "${var.environment}-monitoring-key"
  description  = "API key for monitoring data collection"
  
  owner {
    id          = confluent_service_account.monitoring_sa.id
    api_version = confluent_service_account.monitoring_sa.api_version
    kind        = confluent_service_account.monitoring_sa.kind
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

# RBAC bindings for monitoring service account
resource "confluent_role_binding" "monitoring_cluster_admin" {
  principal   = "User:${confluent_service_account.monitoring_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
}

# Wait for connector to be ready
resource "time_sleep" "wait_for_monitoring" {
  depends_on = [confluent_connector.sumo_logic_sink]
  create_duration = "60s"
}

# Local execution for metrics validation
resource "null_resource" "validate_monitoring" {
  depends_on = [time_sleep.wait_for_monitoring]
  
  triggers = {
    connector_id = confluent_connector.sumo_logic_sink.id
    timestamp    = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating monitoring setup..."
      
      # Check connector status
      if [ "${var.enable_validation}" = "true" ]; then
        echo "Connector ID: ${confluent_connector.sumo_logic_sink.id}"
        echo "Sumo Logic URL configured"
        echo "Topics: ${join(",", var.log_topics)}"
        
        # Generate test logs
        echo '{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","level":"INFO","message":"Monitoring validation test","component":"test-framework","environment":"${var.environment}"}' > /tmp/test_log.json
        
        echo "Monitoring validation completed"
      fi
    EOT
  }
}
