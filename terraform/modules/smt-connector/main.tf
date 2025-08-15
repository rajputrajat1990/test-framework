terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Source topic for SMT testing
resource "confluent_kafka_topic" "smt_source" {
  kafka_cluster {
    id = var.cluster_id
  }
  
  topic_name       = "${var.connector_name}-source"
  partitions_count = var.partitions
  rest_endpoint    = var.kafka_rest_endpoint
  
  credentials {
    key    = var.kafka_api_key
    secret = var.kafka_api_secret
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "2"
  }
}

# Target topic for SMT testing
resource "confluent_kafka_topic" "smt_target" {
  kafka_cluster {
    id = var.cluster_id
  }
  
  topic_name       = "${var.connector_name}-target"
  partitions_count = var.partitions
  rest_endpoint    = var.kafka_rest_endpoint
  
  credentials {
    key    = var.kafka_api_key
    secret = var.kafka_api_secret
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "2"
  }
}

# File Stream Source Connector with SMT transformations
resource "confluent_connector" "smt_test_connector" {
  environment {
    id = var.environment_id
  }
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  display_name = var.connector_name
  
  config_sensitive = {
    "kafka.api.key"    = var.kafka_api_key
    "kafka.api.secret" = var.kafka_api_secret
  }
  
  config_nonsensitive = merge(
    {
      "connector.class"          = "io.confluent.connect.datagen.DatagenConnector"
      "kafka.topic"              = confluent_kafka_topic.smt_target.topic_name
      "output.data.format"       = var.output_data_format
      "quickstart"               = "users"
      "tasks.max"                = "1"
      "max.interval"             = "1000"
      "iterations"               = var.max_iterations
    },
    var.smt_transformations
  )
  
  depends_on = [
    confluent_kafka_topic.smt_source,
    confluent_kafka_topic.smt_target
  ]
}

# Sink connector to verify transformations
resource "confluent_connector" "smt_verification_sink" {
  count = var.enable_verification_sink ? 1 : 0
  
  environment {
    id = var.environment_id
  }
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  display_name = "${var.connector_name}-sink"
  
  config_sensitive = {
    "kafka.api.key"    = var.kafka_api_key
    "kafka.api.secret" = var.kafka_api_secret
  }
  
  config_nonsensitive = {
    "connector.class"    = "org.apache.kafka.connect.file.FileStreamSinkConnector"
    "topics"             = confluent_kafka_topic.smt_target.topic_name
    "file"               = "/tmp/smt-output-${var.connector_name}.txt"
    "tasks.max"          = "1"
    "value.converter"    = var.value_converter
    "key.converter"      = var.key_converter
  }
  
  depends_on = [
    confluent_connector.smt_test_connector
  ]
}
