# Sprint 4: Flink Transformation Validation Tests
# Tests for validating Flink SQL transformation accuracy and performance

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.51.0"
    }
  }
}

# Test: User Enrichment Transformation Validation
run "test_user_enrichment_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-enrichment"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    test_scenarios = ["user_enrichment"]
    enable_validation = true
    enable_performance_monitoring = true
    
    quality_gates = {
      min_data_completeness_percentage = 99.0
      max_error_rate_percentage = 1.0
      min_join_success_rate_percentage = 90.0
      max_late_data_percentage = 10.0
    }
  }

  # Validate user enrichment job exists and is properly configured
  assert {
    condition = (
      module.flink_testing.flink_jobs.user_enrichment.statement_id != "" &&
      module.flink_testing.flink_jobs.user_enrichment.statement_name == "${var.test_prefix}-user-enrichment"
    )
    error_message = "User enrichment job is not properly configured"
  }

  # Validate source and target tables are correctly mapped
  assert {
    condition = (
      module.flink_testing.flink_jobs.user_enrichment.source_table != "" &&
      module.flink_testing.flink_jobs.user_enrichment.target_table != ""
    )
    error_message = "User enrichment job source/target tables are not configured"
  }

  # Validate validation is enabled for enrichment job
  assert {
    condition     = module.flink_testing.validation_info.validation_jobs.user_enrichment == true
    error_message = "Validation is not enabled for user enrichment job"
  }
}

# Test: Event Aggregation Transformation Validation
run "test_event_aggregation_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-aggregation"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    test_scenarios = ["event_aggregation"]
    enable_validation = true
    
    # Specific configuration for aggregation testing
    flink_properties = {
      "table.exec.checkpointing.interval" = "30s"
      "table.exec.checkpointing.mode" = "EXACTLY_ONCE"
      "table.exec.state.ttl" = "86400000"  # 1 day for aggregation state
      "table.optimizer.join-reorder-enabled" = "true"
    }
    
    performance_thresholds = {
      min_throughput_events_per_second = 800
      max_latency_seconds = 8
      max_checkpoint_duration_seconds = 60
      min_success_rate_percentage = 95
    }
  }

  # Validate aggregation job configuration
  assert {
    condition = (
      module.flink_testing.flink_jobs.event_aggregation.statement_id != "" &&
      contains(["RUNNING", "PENDING", "STARTING"], module.flink_testing.flink_jobs.event_aggregation.job_status)
    )
    error_message = "Event aggregation job is not running properly"
  }

  # Validate multiple target topics exist for aggregation outputs
  assert {
    condition = (
      module.flink_testing.target_topics.user_activity_hourly.topic_name != "" &&
      module.flink_testing.target_topics.user_activity_sliding.topic_name != ""
    )
    error_message = "Aggregation target topics are not created properly"
  }

  # Validate state TTL configuration for aggregations
  assert {
    condition = (
      module.flink_testing.test_configuration.flink_properties["table.exec.state.ttl"] == "86400000"
    )
    error_message = "State TTL is not configured correctly for aggregation jobs"
  }
}

# Test: Windowed Analytics Validation
run "test_windowed_analytics_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-windowed"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    test_scenarios = ["windowed_analytics"]
    enable_validation = true
    enable_performance_monitoring = true
    
    # Configuration for windowed operations
    checkpointing_config = {
      interval_seconds = 45
      timeout_seconds = 900
      min_pause_between_seconds = 10
      max_concurrent_checkpoints = 1
      cleanup_mode = "RETAIN_ON_CANCELLATION"
    }
    
    watermark_config = {
      max_out_of_orderness_seconds = 10
      idle_source_timeout_seconds = 600
      alignment_timeout_seconds = 60
      alignment_max_drift_seconds = 60
    }
  }

  # Validate windowed analytics job
  assert {
    condition = (
      module.flink_testing.flink_jobs.windowed_analytics.statement_id != "" &&
      module.flink_testing.flink_jobs.windowed_analytics.statement_name == "${var.test_prefix}-windowed-analytics"
    )
    error_message = "Windowed analytics job is not properly configured"
  }

  # Validate daily analytics target topic
  assert {
    condition = (
      module.flink_testing.target_topics.user_analytics_daily.topic_name != "" &&
      module.flink_testing.target_topics.user_analytics_daily.partitions >= 1
    )
    error_message = "Daily analytics target topic is not configured properly"
  }

  # Validate performance monitoring for windowed job
  assert {
    condition     = module.flink_testing.validation_info.performance_jobs.windowed_analytics == true
    error_message = "Performance monitoring is not enabled for windowed analytics job"
  }
}

# Test: Performance Validation Job
run "test_performance_validation_job" {
  command = apply

  variables {
    test_prefix      = "tftest-performance"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_validation = true
    enable_performance_monitoring = true
    enable_performance_validation = true
    
    performance_thresholds = {
      min_throughput_events_per_second = 1500
      max_latency_seconds = 5
      max_checkpoint_duration_seconds = 30
      min_success_rate_percentage = 98
    }
  }

  # Validate performance validation job is created when enabled
  assert {
    condition = (
      module.flink_testing.flink_jobs.performance_validation != null &&
      module.flink_testing.flink_jobs.performance_validation.statement_id != ""
    )
    error_message = "Performance validation job should be created when enabled"
  }

  # Validate total job count includes performance validation
  assert {
    condition     = module.flink_testing.job_status_summary.total_jobs == 4
    error_message = "Total job count should be 4 including performance validation job"
  }

  # Validate performance thresholds are configured
  assert {
    condition = (
      module.flink_testing.performance_thresholds.min_throughput_events_per_second == 1500 &&
      module.flink_testing.performance_thresholds.max_latency_seconds == 5
    )
    error_message = "Performance thresholds are not configured correctly"
  }
}

# Test: Data Quality and Accuracy Validation
run "test_data_quality_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-quality"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_validation = true
    
    # Strict quality gates for testing
    quality_gates = {
      min_data_completeness_percentage = 99.9
      max_error_rate_percentage = 0.1
      min_join_success_rate_percentage = 98.0
      max_late_data_percentage = 2.0
    }
    
    test_data_config = {
      users_count = 2000
      events_per_user = 150
      time_span_hours = 24
      late_data_percentage = 1
      error_rate_percentage = 0.1
    }
  }

  # Validate quality gates are properly configured
  assert {
    condition = (
      module.flink_testing.quality_gates.min_data_completeness_percentage == 99.9 &&
      module.flink_testing.quality_gates.max_error_rate_percentage == 0.1 &&
      module.flink_testing.quality_gates.min_join_success_rate_percentage == 98.0
    )
    error_message = "Quality gates are not configured with correct values"
  }

  # Validate monitoring topics exist for error tracking
  assert {
    condition = (
      module.flink_testing.monitoring_topics.transformation_errors.topic_name != "" &&
      module.flink_testing.monitoring_topics.performance_metrics.topic_name != ""
    )
    error_message = "Monitoring topics for error tracking are not created"
  }
}

# Test: Complex Transformation Chain Validation
run "test_transformation_chain_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-chain"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    # Test all transformation scenarios in sequence
    test_scenarios = ["user_enrichment", "event_aggregation", "windowed_analytics"]
    enable_validation = true
    enable_performance_monitoring = true
    
    # Higher resource allocation for complex transformations
    max_cfu = 15
    source_topic_partitions = 8
    target_topic_partitions = 4
    
    flink_properties = {
      "table.exec.checkpointing.interval" = "60s"
      "table.exec.checkpointing.mode" = "EXACTLY_ONCE"
      "table.exec.state.ttl" = "7200000"
      "table.optimizer.join-reorder-enabled" = "true"
      "pipeline.watermark-alignment.alignment-group" = "default"
      "pipeline.watermark-alignment.max-drift" = "60s"
    }
    
    resource_limits = {
      max_parallelism = 12
      memory_per_slot_mb = 1536
      network_memory_mb = 192
      managed_memory_mb = 384
    }
  }

  # Validate all jobs in the transformation chain
  assert {
    condition = (
      module.flink_testing.flink_jobs.user_enrichment.statement_id != "" &&
      module.flink_testing.flink_jobs.event_aggregation.statement_id != "" &&
      module.flink_testing.flink_jobs.windowed_analytics.statement_id != ""
    )
    error_message = "Not all jobs in transformation chain were created"
  }

  # Validate resource allocation is sufficient
  assert {
    condition = (
      module.flink_testing.compute_pool_info.max_cfu == 15 &&
      module.flink_testing.resource_info.resource_limits.max_parallelism == 12
    )
    error_message = "Resource allocation is not sufficient for complex transformation chain"
  }

  # Validate all validation jobs are enabled
  assert {
    condition = alltrue([
      module.flink_testing.validation_info.validation_jobs.user_enrichment,
      module.flink_testing.validation_info.validation_jobs.event_aggregation,
      module.flink_testing.validation_info.validation_jobs.windowed_analytics
    ])
    error_message = "Validation is not enabled for all jobs in transformation chain"
  }

  # Validate proper topic partitioning for scalability
  assert {
    condition = (
      module.flink_testing.source_topics.user_events_source.partitions == 8 &&
      module.flink_testing.target_topics.user_events_enriched.partitions == 4
    )
    error_message = "Topic partitioning is not configured correctly for scalability"
  }
}

# Test: Error Handling and Recovery Validation
run "test_error_handling_validation" {
  command = apply

  variables {
    test_prefix      = "tftest-errors"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_validation = true
    
    # Configuration for error handling testing
    error_handling_config = {
      enable_dead_letter_queue = true
      max_retry_attempts = 3
      retry_delay_seconds = 15
      stop_on_error = false
    }
    
    test_data_config = {
      users_count = 1000
      events_per_user = 100
      time_span_hours = 12
      late_data_percentage = 8
      error_rate_percentage = 2
    }
  }

  # Validate error handling topics are created
  assert {
    condition = (
      module.flink_testing.monitoring_topics.transformation_errors.topic_name != "" &&
      module.flink_testing.monitoring_topics.transformation_errors.partitions >= 1
    )
    error_message = "Error handling topic is not configured properly"
  }

  # Validate all jobs are configured to not stop on error (for testing)
  assert {
    condition = alltrue([
      for job_name, job_info in module.flink_testing.flink_jobs :
      job_info.statement_id != ""
    ])
    error_message = "Some jobs failed to start despite error handling configuration"
  }
}

# Test: Performance Benchmarking Validation
run "test_performance_benchmarking" {
  command = apply

  variables {
    test_prefix      = "tftest-benchmark"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_performance_monitoring = true
    enable_performance_validation = true
    
    # High-performance configuration for benchmarking
    max_cfu = 25
    source_topic_partitions = 16
    target_topic_partitions = 8
    
    performance_thresholds = {
      min_throughput_events_per_second = 3000
      max_latency_seconds = 2
      max_checkpoint_duration_seconds = 20
      min_success_rate_percentage = 99.5
    }
    
    test_data_config = {
      users_count = 10000
      events_per_user = 500
      time_span_hours = 72
      late_data_percentage = 1
      error_rate_percentage = 0.1
    }
  }

  # Validate high-performance resource allocation
  assert {
    condition = (
      module.flink_testing.compute_pool_info.max_cfu == 25 &&
      module.flink_testing.source_topics.user_events_source.partitions == 16
    )
    error_message = "High-performance resource allocation is not configured correctly"
  }

  # Validate performance monitoring is enabled for all jobs
  assert {
    condition = alltrue([
      for job_name, enabled in module.flink_testing.validation_info.performance_jobs :
      enabled == true
    ])
    error_message = "Performance monitoring is not enabled for all jobs"
  }

  # Validate performance validation job exists
  assert {
    condition = (
      module.flink_testing.flink_jobs.performance_validation != null &&
      module.flink_testing.validation_info.performance_validation_enabled == true
    )
    error_message = "Performance validation job is not configured for benchmarking"
  }

  # Validate performance metrics topic has sufficient capacity
  assert {
    condition = (
      module.flink_testing.monitoring_topics.performance_metrics.topic_name != "" &&
      module.flink_testing.monitoring_topics.performance_metrics.partitions >= 1
    )
    error_message = "Performance metrics topic is not configured for high-throughput monitoring"
  }
}
