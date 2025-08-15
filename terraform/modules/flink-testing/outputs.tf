# Sprint 4: Outputs for Flink Testing Module

# Compute Pool Outputs
output "compute_pool_id" {
  description = "ID of the Flink compute pool"
  value       = module.flink_compute_pool.compute_pool_id
}

output "compute_pool_info" {
  description = "Information about the compute pool"
  value       = module.flink_compute_pool.configuration_summary
}

output "connection_info" {
  description = "Connection information for external tools"
  value = {
    environment_id   = var.environment_id
    cluster_id       = var.cluster_id
    compute_pool_id  = module.flink_compute_pool.compute_pool_id
    service_account  = module.flink_compute_pool.service_account_id
    
    # pool_endpoint contains id, api_version, kind (no rest_endpoint available in this provider version)
    pool_endpoint = module.flink_compute_pool.pool_endpoint
    
    # Topics for data producers/consumers
    source_topics = local.topic_summary.source_topics
    target_topics = local.topic_summary.target_topics
  }
}

output "service_account_id" {
  description = "ID of the Flink service account"
  value       = module.flink_compute_pool.service_account_id
}

output "flink_api_key_id" {
  description = "ID of the Flink API key"
  value       = module.flink_compute_pool.flink_api_key_id
  sensitive   = true
}

output "flink_api_key_secret" {
  description = "Secret of the Flink API key"
  value       = module.flink_compute_pool.flink_api_key_secret
  sensitive   = true
}

# Topic Outputs
output "source_topics" {
  description = "List of source topics created"
  value = {
    user_events_source = {
      id           = confluent_kafka_topic.user_events_source.id
      topic_name   = confluent_kafka_topic.user_events_source.topic_name
      partitions   = confluent_kafka_topic.user_events_source.partitions_count
    }
    users_lookup = {
      id           = confluent_kafka_topic.users_lookup.id
      topic_name   = confluent_kafka_topic.users_lookup.topic_name
      partitions   = confluent_kafka_topic.users_lookup.partitions_count
    }
  }
}

output "target_topics" {
  description = "List of target topics created"
  value = {
    user_events_enriched = {
      id           = confluent_kafka_topic.user_events_enriched.id
      topic_name   = confluent_kafka_topic.user_events_enriched.topic_name
      partitions   = confluent_kafka_topic.user_events_enriched.partitions_count
    }
    user_activity_hourly = {
      id           = confluent_kafka_topic.user_activity_hourly.id
      topic_name   = confluent_kafka_topic.user_activity_hourly.topic_name
      partitions   = confluent_kafka_topic.user_activity_hourly.partitions_count
    }
    user_activity_sliding = {
      id           = confluent_kafka_topic.user_activity_sliding.id
      topic_name   = confluent_kafka_topic.user_activity_sliding.topic_name
      partitions   = confluent_kafka_topic.user_activity_sliding.partitions_count
    }
    user_analytics_daily = {
      id           = confluent_kafka_topic.user_analytics_daily.id
      topic_name   = confluent_kafka_topic.user_analytics_daily.topic_name
      partitions   = confluent_kafka_topic.user_analytics_daily.partitions_count
    }
  }
}

output "monitoring_topics" {
  description = "List of monitoring topics created"
  value = {
    transformation_errors = {
      id           = confluent_kafka_topic.transformation_errors.id
      topic_name   = confluent_kafka_topic.transformation_errors.topic_name
      partitions   = confluent_kafka_topic.transformation_errors.partitions_count
    }
    performance_metrics = {
      id           = confluent_kafka_topic.performance_metrics.id
      topic_name   = confluent_kafka_topic.performance_metrics.topic_name
      partitions   = confluent_kafka_topic.performance_metrics.partitions_count
    }
  }
}

# Flink Job Outputs
output "flink_jobs" {
  description = "Information about all Flink jobs created"
  value = {
    user_enrichment = {
      statement_id   = module.user_enrichment_job.statement_id
      statement_name = module.user_enrichment_job.statement_name
      job_status     = module.user_enrichment_job.job_status
      source_table   = module.user_enrichment_job.table_info.source_table
      target_table   = module.user_enrichment_job.table_info.target_table
    }
    event_aggregation = {
      statement_id   = module.event_aggregation_job.statement_id
      statement_name = module.event_aggregation_job.statement_name
      job_status     = module.event_aggregation_job.job_status
      source_table   = module.event_aggregation_job.table_info.source_table
      target_table   = module.event_aggregation_job.table_info.target_table
    }
    windowed_analytics = {
      statement_id   = module.windowed_analytics_job.statement_id
      statement_name = module.windowed_analytics_job.statement_name
      job_status     = module.windowed_analytics_job.job_status
      source_table   = module.windowed_analytics_job.table_info.source_table
      target_table   = module.windowed_analytics_job.table_info.target_table
    }
    performance_validation = var.enable_performance_validation ? {
      statement_id   = try(module.performance_validation_job[0].statement_id, null)
      statement_name = try(module.performance_validation_job[0].statement_name, null)
      job_status     = try(module.performance_validation_job[0].job_status, null)
    } : null
  }
}

# Job Status Summary
output "job_status_summary" {
  description = "Summary of all job statuses"
  value = {
    total_jobs = length([
      module.user_enrichment_job.statement_id,
      module.event_aggregation_job.statement_id,
      module.windowed_analytics_job.statement_id
    ]) + (var.enable_performance_validation ? 1 : 0)
    
    jobs_created = local.all_jobs_created
    
    individual_status = {
      user_enrichment     = module.user_enrichment_job.job_status
      event_aggregation   = module.event_aggregation_job.job_status  
      windowed_analytics  = module.windowed_analytics_job.job_status
      performance_validation = var.enable_performance_validation ? try(module.performance_validation_job[0].job_status, null) : "DISABLED"
    }
  }
}

# Validation Outputs
output "validation_info" {
  description = "Information about validation configuration"
  value = {
    validation_enabled           = var.enable_validation
    performance_monitoring_enabled = var.enable_performance_monitoring
    performance_validation_enabled = var.enable_performance_validation
    
    validation_jobs = {
      user_enrichment = module.user_enrichment_job.validation_enabled
      event_aggregation = module.event_aggregation_job.validation_enabled
      windowed_analytics = module.windowed_analytics_job.validation_enabled
    }
    
    performance_jobs = {
      user_enrichment = module.user_enrichment_job.performance_monitoring_enabled
      event_aggregation = module.event_aggregation_job.performance_monitoring_enabled
      windowed_analytics = module.windowed_analytics_job.performance_monitoring_enabled
    }
  }
}

# Configuration Summary
output "test_configuration" {
  description = "Summary of test configuration"
  value = {
    test_prefix              = var.test_prefix
    environment_id          = var.environment_id
    cluster_id              = var.cluster_id
    cloud_provider          = var.cloud_provider
    region                  = var.region
    max_cfu                 = var.max_cfu
    source_topic_partitions = var.source_topic_partitions
    target_topic_partitions = var.target_topic_partitions
    test_scenarios          = var.test_scenarios
    flink_properties        = var.flink_properties
  }
}

# Topic Summary
output "topic_summary" {
  description = "Summary of all topics created"
  value = local.topic_summary
}

# Job Summary  
output "job_summary" {
  description = "Summary of all jobs created"
  value = local.job_summary
}

# Monitoring Information
output "monitoring_info" {
  description = "Information for monitoring Flink jobs"
  value = {
    compute_pool_id = module.flink_compute_pool.compute_pool_id
    service_account = module.flink_compute_pool.service_account_id
    
    jobs_to_monitor = {
      user_enrichment = module.user_enrichment_job.monitoring_info
      event_aggregation = module.event_aggregation_job.monitoring_info
      windowed_analytics = module.windowed_analytics_job.monitoring_info
      performance_validation = var.enable_performance_validation ? try(module.performance_validation_job[0].monitoring_info, null) : null
    }
    
    monitoring_topics = {
      errors = confluent_kafka_topic.transformation_errors.topic_name
      metrics = confluent_kafka_topic.performance_metrics.topic_name
    }
  }
}

# Performance Thresholds
output "performance_thresholds" {
  description = "Performance thresholds for validation"
  value = var.performance_thresholds
}

# Quality Gates
output "quality_gates" {
  description = "Quality gates for transformation validation"
  value = var.quality_gates
}

# Resource Information
output "resource_info" {
  description = "Resource usage and configuration information"
  value = {
    compute_pool_max_cfu = var.max_cfu
    total_topics_created = length([
      confluent_kafka_topic.user_events_source.topic_name,
      confluent_kafka_topic.users_lookup.topic_name,
      confluent_kafka_topic.user_events_enriched.topic_name,
      confluent_kafka_topic.user_activity_hourly.topic_name,
      confluent_kafka_topic.user_activity_sliding.topic_name,
      confluent_kafka_topic.user_analytics_daily.topic_name,
      confluent_kafka_topic.transformation_errors.topic_name,
      confluent_kafka_topic.performance_metrics.topic_name
    ])
    
    total_partitions = (
      var.source_topic_partitions * 2 +  # source and lookup topics
      var.target_topic_partitions * 4 +  # 4 target topics
      2  # error and metrics topics (1 partition each)
    )
    
    resource_limits = var.resource_limits
  }
}


