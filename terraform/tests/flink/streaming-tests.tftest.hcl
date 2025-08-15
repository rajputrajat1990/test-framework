# Sprint 4: Flink Streaming Transformation Tests
# Tests for Flink-based data transformations and stream processing

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.51.0"
    }
  }
}

# Test: Basic Flink Compute Pool Creation
run "test_flink_compute_pool_creation" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-basic"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    cloud_provider   = "AWS"
    region          = "us-west-2"
    max_cfu         = 5
    
    enable_validation = false
    enable_performance_monitoring = false
    enable_performance_validation = false
  }

  assert {
    condition     = module.flink_testing.compute_pool_id != ""
    error_message = "Flink compute pool was not created successfully"
  }

  assert {
    condition     = module.flink_testing.service_account_id != ""
    error_message = "Flink service account was not created"
  }

  assert {
    condition     = module.flink_testing.compute_pool_info.cloud == "AWS"
    error_message = "Compute pool cloud provider does not match expected value"
  }

  assert {
    condition     = module.flink_testing.compute_pool_info.max_cfu == 5
    error_message = "Compute pool max CFU does not match expected value"
  }
}

# Test: Topic Creation for Flink Testing
run "test_flink_topics_creation" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-topics"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    source_topic_partitions = 6
    target_topic_partitions = 3
    lookup_topic_partitions = 3
    
    enable_validation = false
    enable_performance_monitoring = false
  }

  assert {
    condition     = length(module.flink_testing.source_topics) == 2
    error_message = "Expected 2 source topics to be created"
  }

  assert {
    condition     = length(module.flink_testing.target_topics) == 4
    error_message = "Expected 4 target topics to be created"
  }

  assert {
    condition     = module.flink_testing.source_topics.user_events_source.partitions == 6
    error_message = "Source topic partitions do not match expected value"
  }

  assert {
    condition     = module.flink_testing.target_topics.user_events_enriched.partitions == 3
    error_message = "Target topic partitions do not match expected value"
  }

  assert {
    condition = alltrue([
      for topic_name, topic_info in module.flink_testing.source_topics :
      startswith(topic_info.topic_name, "tftest-flink-topics")
    ])
    error_message = "Source topics do not have correct naming prefix"
  }
}

# Test: Flink Job Creation and Execution
run "test_flink_jobs_creation" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-jobs"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    max_cfu         = 10
    
    test_scenarios = ["user_enrichment", "event_aggregation", "windowed_analytics"]
    enable_validation = true
    enable_performance_monitoring = true
  }

  assert {
    condition     = module.flink_testing.job_status_summary.total_jobs == 3
    error_message = "Expected 3 Flink jobs to be created"
  }

  assert {
    condition     = module.flink_testing.job_status_summary.jobs_created == true
    error_message = "Not all Flink jobs were created successfully"
  }

  assert {
    condition = alltrue([
      for job_name, job_info in module.flink_testing.flink_jobs :
      job_info.statement_id != "" && job_info.statement_name != ""
    ])
    error_message = "Some Flink jobs are missing required properties"
  }

  # Verify job names follow naming convention
  assert {
    condition = alltrue([
      for job_name, job_info in module.flink_testing.flink_jobs :
      startswith(job_info.statement_name, "tftest-flink-jobs")
    ])
    error_message = "Flink jobs do not follow correct naming convention"
  }
}

# Test: Flink Job Status Validation
run "test_flink_job_status" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-status"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_validation = true
    enable_performance_monitoring = true
  }

  # Wait for jobs to be fully deployed
  provisioner "local-exec" {
    command = "sleep 60"
  }

  assert {
    condition = alltrue([
      for job_name, status in module.flink_testing.job_status_summary.individual_status :
      contains(["RUNNING", "PENDING", "STARTING"], status)
    ])
    error_message = "Some Flink jobs are not in expected status (RUNNING, PENDING, or STARTING)"
  }
}

# Test: Validation Configuration
run "test_validation_configuration" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-validation"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_validation = true
    enable_performance_monitoring = true
    enable_performance_validation = true
    
    performance_thresholds = {
      min_throughput_events_per_second = 500
      max_latency_seconds = 10
      max_checkpoint_duration_seconds = 60
      min_success_rate_percentage = 95
    }
    
    quality_gates = {
      min_data_completeness_percentage = 99.5
      max_error_rate_percentage = 0.5
      min_join_success_rate_percentage = 90
      max_late_data_percentage = 10
    }
  }

  assert {
    condition     = module.flink_testing.validation_info.validation_enabled == true
    error_message = "Validation should be enabled"
  }

  assert {
    condition     = module.flink_testing.validation_info.performance_monitoring_enabled == true
    error_message = "Performance monitoring should be enabled"
  }

  assert {
    condition     = module.flink_testing.validation_info.performance_validation_enabled == true
    error_message = "Performance validation should be enabled"
  }

  assert {
    condition     = module.flink_testing.job_status_summary.total_jobs == 4
    error_message = "Expected 4 jobs including performance validation job"
  }

  # Verify performance thresholds are set correctly
  assert {
    condition = (
      module.flink_testing.performance_thresholds.min_throughput_events_per_second == 500 &&
      module.flink_testing.performance_thresholds.max_latency_seconds == 10
    )
    error_message = "Performance thresholds are not set correctly"
  }

  # Verify quality gates are set correctly
  assert {
    condition = (
      module.flink_testing.quality_gates.min_data_completeness_percentage == 99.5 &&
      module.flink_testing.quality_gates.max_error_rate_percentage == 0.5
    )
    error_message = "Quality gates are not set correctly"
  }
}

# Test: Resource Configuration and Limits
run "test_resource_configuration" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-resources"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    max_cfu         = 15
    
    source_topic_partitions = 12
    target_topic_partitions = 6
    lookup_topic_partitions = 3
    
    resource_limits = {
      max_parallelism = 8
      memory_per_slot_mb = 2048
      network_memory_mb = 256
      managed_memory_mb = 512
    }
    
    flink_properties = {
      "table.exec.checkpointing.interval" = "60s"
      "table.exec.checkpointing.mode" = "EXACTLY_ONCE"
      "table.exec.state.ttl" = "7200000"
    }
  }

  assert {
    condition     = module.flink_testing.compute_pool_info.max_cfu == 15
    error_message = "Compute pool max CFU does not match configuration"
  }

  assert {
    condition     = module.flink_testing.resource_info.total_partitions == 41
    error_message = "Total partition count calculation is incorrect"
  }

  assert {
    condition = (
      module.flink_testing.resource_info.resource_limits.max_parallelism == 8 &&
      module.flink_testing.resource_info.resource_limits.memory_per_slot_mb == 2048
    )
    error_message = "Resource limits are not configured correctly"
  }
}

# Test: Monitoring and Error Handling
run "test_monitoring_configuration" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-monitoring"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    
    enable_performance_monitoring = true
    
    monitoring_config = {
      enable_alerts = true
      alert_cpu_threshold = 85
      alert_memory_threshold = 90
      alert_checkpoint_failure_threshold = 5
      metrics_collection_interval = "30s"
    }
    
    error_handling_config = {
      enable_dead_letter_queue = true
      max_retry_attempts = 5
      retry_delay_seconds = 30
      stop_on_error = false
    }
  }

  assert {
    condition     = length(module.flink_testing.monitoring_topics) == 2
    error_message = "Expected 2 monitoring topics (errors and metrics)"
  }

  assert {
    condition = (
      module.flink_testing.monitoring_topics.transformation_errors.topic_name != "" &&
      module.flink_testing.monitoring_topics.performance_metrics.topic_name != ""
    )
    error_message = "Monitoring topics are not created properly"
  }

  assert {
    condition = alltrue([
      for job_name, monitoring_info in module.flink_testing.monitoring_info.jobs_to_monitor :
      monitoring_info.statement_id != ""
    ])
    error_message = "Monitoring information is incomplete for some jobs"
  }
}

# Test: End-to-End Configuration
run "test_end_to_end_flink_testing" {
  command = apply

  variables {
    test_prefix      = "tftest-flink-e2e"
    environment_id   = var.confluent_environment_id
    cluster_id       = var.confluent_cluster_id
    organization_id  = var.confluent_organization_id
    max_cfu         = 20
    
    # Enable all features
    enable_validation = true
    enable_performance_monitoring = true
    enable_performance_validation = true
    
    # All test scenarios
    test_scenarios = ["user_enrichment", "event_aggregation", "windowed_analytics"]
    
    # Comprehensive configuration
    test_data_config = {
      users_count = 5000
      events_per_user = 200
      time_span_hours = 48
      late_data_percentage = 3
      error_rate_percentage = 0.5
    }
    
    performance_thresholds = {
      min_throughput_events_per_second = 2000
      max_latency_seconds = 3
      max_checkpoint_duration_seconds = 45
      min_success_rate_percentage = 99
    }
    
    quality_gates = {
      min_data_completeness_percentage = 99.8
      max_error_rate_percentage = 0.2
      min_join_success_rate_percentage = 95
      max_late_data_percentage = 5
    }
  }

  # Comprehensive validation of all components
  assert {
    condition = (
      module.flink_testing.compute_pool_id != "" &&
      module.flink_testing.service_account_id != "" &&
      length(module.flink_testing.source_topics) == 2 &&
      length(module.flink_testing.target_topics) == 4 &&
      length(module.flink_testing.monitoring_topics) == 2
    )
    error_message = "End-to-end test failed: Not all required resources were created"
  }

  assert {
    condition     = module.flink_testing.job_status_summary.total_jobs == 4
    error_message = "End-to-end test failed: Expected 4 total jobs including validation"
  }

  assert {
    condition     = module.flink_testing.job_status_summary.jobs_created == true
    error_message = "End-to-end test failed: Not all jobs were created successfully"
  }

  # Verify monitoring is fully configured
  assert {
    condition = (
      module.flink_testing.monitoring_info.compute_pool_id != "" &&
      module.flink_testing.monitoring_info.service_account != "" &&
      length(module.flink_testing.monitoring_info.jobs_to_monitor) >= 3
    )
    error_message = "End-to-end test failed: Monitoring configuration incomplete"
  }
}
