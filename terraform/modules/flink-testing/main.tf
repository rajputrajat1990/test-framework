# Sprint 4: Confluent Cloud Flink Testing Module
# Comprehensive Flink transformation testing with multiple scenarios

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Create compute pool for testing
module "flink_compute_pool" {
  source = "../compute-pool"
  
  pool_name        = "${var.test_prefix}-flink-pool"
  environment_id   = var.environment_id
  organization_id  = var.organization_id
  cloud_provider   = var.cloud_provider
  region           = var.region
  max_cfu          = var.max_cfu
  
  tags = merge(var.tags, {
    "Purpose" = "FlinkTesting"
    "Sprint"  = "Sprint4"
  })
}

# Source topics for testing
resource "confluent_kafka_topic" "user_events_source" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-user-events-source"
  partitions_count = var.source_topic_partitions
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "1"
    "segment.ms"          = "86400000"   # 1 day
  }
}

resource "confluent_kafka_topic" "users_lookup" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-users-lookup"
  partitions_count = var.lookup_topic_partitions
  
  config = {
    "cleanup.policy"      = "compact"
    "retention.ms"        = "-1"  # Retain forever for lookup table
    "min.insync.replicas" = "1"
    "segment.ms"          = "86400000"
  }
}

# Target topics for transformation results
resource "confluent_kafka_topic" "user_events_enriched" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-user-events-enriched"
  partitions_count = var.target_topic_partitions
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "259200000"  # 3 days
    "min.insync.replicas" = "1"
  }
}

resource "confluent_kafka_topic" "user_activity_hourly" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-user-activity-hourly"
  partitions_count = var.target_topic_partitions
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "2592000000"  # 30 days
    "min.insync.replicas" = "1"
  }
}

resource "confluent_kafka_topic" "user_activity_sliding" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-user-activity-sliding"
  partitions_count = var.target_topic_partitions
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "86400000"  # 1 day
    "min.insync.replicas" = "1"
  }
}

resource "confluent_kafka_topic" "user_analytics_daily" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-user-analytics-daily"
  partitions_count = var.target_topic_partitions
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "7776000000"  # 90 days
    "min.insync.replicas" = "1"
  }
}

# Error and monitoring topics
resource "confluent_kafka_topic" "transformation_errors" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-transformation-errors"
  partitions_count = 1
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "1"
  }
}

resource "confluent_kafka_topic" "performance_metrics" {
  kafka_cluster {
    id = var.cluster_id
  }
  topic_name       = "${var.test_prefix}-performance-metrics"
  partitions_count = 1
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "259200000"  # 3 days
    "min.insync.replicas" = "1"
  }
}

# Wait for topics to be created
resource "time_sleep" "wait_for_topics" {
  depends_on = [
    confluent_kafka_topic.user_events_source,
    confluent_kafka_topic.users_lookup,
    confluent_kafka_topic.user_events_enriched,
    confluent_kafka_topic.user_activity_hourly,
    confluent_kafka_topic.user_activity_sliding,
    confluent_kafka_topic.user_analytics_daily,
    confluent_kafka_topic.transformation_errors,
    confluent_kafka_topic.performance_metrics,
  ]
  
  create_duration = "30s"
}

# User Enrichment Transformation Job
module "user_enrichment_job" {
  source = "../flink-job"
  
  statement_name      = "${var.test_prefix}-user-enrichment"
  environment_id      = var.environment_id
  cluster_id          = var.cluster_id
  compute_pool_id     = module.flink_compute_pool.compute_pool_id
  service_account_id  = module.flink_compute_pool.service_account_id
  
  sql_file_path = "${path.module}/../../flink/sql/transformations/user-enrichment.sql"
  sql_template_variables = {
    source_topic = confluent_kafka_topic.user_events_source.topic_name
    users_topic  = confluent_kafka_topic.users_lookup.topic_name
    target_topic = confluent_kafka_topic.user_events_enriched.topic_name
  }
  
  source_table_name = confluent_kafka_topic.user_events_source.topic_name
  target_table_name = confluent_kafka_topic.user_events_enriched.topic_name
  
  enable_validation           = var.enable_validation
  validation_sql_file_path    = "${path.module}/../../flink/sql/tests/transformation-tests.sql"
  enable_performance_monitoring = var.enable_performance_monitoring
  
  flink_properties = var.flink_properties
  
  depends_on = [
    module.flink_compute_pool,
    time_sleep.wait_for_topics
  ]
}

# Event Aggregation Job
module "event_aggregation_job" {
  source = "../flink-job"
  
  statement_name      = "${var.test_prefix}-event-aggregation"
  environment_id      = var.environment_id
  cluster_id          = var.cluster_id
  compute_pool_id     = module.flink_compute_pool.compute_pool_id
  service_account_id  = module.flink_compute_pool.service_account_id
  
  sql_file_path = "${path.module}/../../flink/sql/transformations/event-aggregation.sql"
  sql_template_variables = {
    source_topic = confluent_kafka_topic.user_events_source.topic_name
    hourly_topic = confluent_kafka_topic.user_activity_hourly.topic_name
    sliding_topic = confluent_kafka_topic.user_activity_sliding.topic_name
  }
  
  source_table_name = confluent_kafka_topic.user_events_source.topic_name
  target_table_name = confluent_kafka_topic.user_activity_hourly.topic_name
  
  enable_validation = var.enable_validation
  validation_sql_file_path = "${path.module}/../../flink/sql/tests/transformation-tests.sql"
  
  flink_properties = merge(var.flink_properties, {
    "table.exec.state.ttl" = "86400000"  # 1 day state TTL for aggregations
  })
  
  depends_on = [
    module.user_enrichment_job
  ]
}

# Windowed Analytics Job
module "windowed_analytics_job" {
  source = "../flink-job"
  
  statement_name      = "${var.test_prefix}-windowed-analytics"
  environment_id      = var.environment_id
  cluster_id          = var.cluster_id
  compute_pool_id     = module.flink_compute_pool.compute_pool_id
  service_account_id  = module.flink_compute_pool.service_account_id
  
  sql_file_path = "${path.module}/../../flink/sql/transformations/windowed-analytics.sql"
  sql_template_variables = {
    source_topic = confluent_kafka_topic.user_events_source.topic_name
    daily_topic  = confluent_kafka_topic.user_analytics_daily.topic_name
  }
  
  source_table_name = confluent_kafka_topic.user_events_source.topic_name
  target_table_name = confluent_kafka_topic.user_analytics_daily.topic_name
  
  enable_validation = var.enable_validation
  validation_sql_file_path = "${path.module}/../../flink/sql/tests/validation-queries.sql"
  
  flink_properties = merge(var.flink_properties, {
    "table.exec.state.ttl" = "259200000"  # 3 days state TTL for daily aggregations
  })
  
  depends_on = [
    module.event_aggregation_job
  ]
}

# Performance Validation Job (runs validation queries)
module "performance_validation_job" {
  count = var.enable_performance_validation ? 1 : 0
  
  source = "../flink-job"
  
  statement_name      = "${var.test_prefix}-performance-validation"
  environment_id      = var.environment_id
  cluster_id          = var.cluster_id
  compute_pool_id     = module.flink_compute_pool.compute_pool_id
  service_account_id  = module.flink_compute_pool.service_account_id
  
  sql_file_path = "${path.module}/../../flink/sql/tests/validation-queries.sql"
  sql_template_variables = {
    enriched_topic = confluent_kafka_topic.user_events_enriched.topic_name
    hourly_topic   = confluent_kafka_topic.user_activity_hourly.topic_name
    metrics_topic  = confluent_kafka_topic.performance_metrics.topic_name
  }
  
  source_table_name = confluent_kafka_topic.user_events_enriched.topic_name
  target_table_name = confluent_kafka_topic.performance_metrics.topic_name
  
  stop_on_error = false  # Allow validation to continue even with errors
  
  depends_on = [
    module.windowed_analytics_job
  ]
}

# Local values for output processing
locals {
  all_jobs_created = (
    module.user_enrichment_job.statement_id != "" &&
    module.event_aggregation_job.statement_id != "" &&
    module.windowed_analytics_job.statement_id != ""
  )
  
  topic_summary = {
    source_topics = [
      confluent_kafka_topic.user_events_source.topic_name,
      confluent_kafka_topic.users_lookup.topic_name
    ]
    target_topics = [
      confluent_kafka_topic.user_events_enriched.topic_name,
      confluent_kafka_topic.user_activity_hourly.topic_name,
      confluent_kafka_topic.user_activity_sliding.topic_name,
      confluent_kafka_topic.user_analytics_daily.topic_name
    ]
    monitoring_topics = [
      confluent_kafka_topic.transformation_errors.topic_name,
      confluent_kafka_topic.performance_metrics.topic_name
    ]
  }
  
  job_summary = {
    user_enrichment = module.user_enrichment_job.statement_id
    event_aggregation = module.event_aggregation_job.statement_id
    windowed_analytics = module.windowed_analytics_job.statement_id
    performance_validation = var.enable_performance_validation ? try(module.performance_validation_job[0].statement_id, null) : null
  }
}
