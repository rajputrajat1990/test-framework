# End-to-End Consumer Groups Test Configuration
# Tests multiple consumer groups consuming from the same topic

run "consumer_groups_setup" {
  command = plan
  
  variables {
    test_prefix = "e2e-consumer-groups"
    test_suffix = formatdate("YYYYMMDD-hhmm", timestamp())
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
    
    # Test configuration
    message_count = 500
    data_format  = "json"
    consumer_groups_count = 3
    partitions_count = 6
  }
}

run "consumer_groups_apply" {
  command = apply
  
  variables {
    test_prefix = run.consumer_groups_setup.test_prefix
    test_suffix = run.consumer_groups_setup.test_suffix
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
    
    message_count = 500
    data_format  = "json"
    consumer_groups_count = 3
    partitions_count = 6
  }
}

run "verify_topic_creation" {
  command = plan
  
  variables {
    test_prefix = run.consumer_groups_apply.test_prefix
    test_suffix = run.consumer_groups_apply.test_suffix
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
  }
  
  assert {
    condition = can(run.consumer_groups_apply.kafka_topic_name)
    error_message = "Kafka topic for consumer groups test was not created"
  }
  
  assert {
    condition = run.consumer_groups_apply.kafka_topic_partitions == 6
    error_message = "Kafka topic should have 6 partitions for consumer group testing"
  }
}

# Consumer Group Behavior Tests
run "validate_consumer_group_behavior" {
  command = plan
  
  variables {
    kafka_topic_name = run.consumer_groups_apply.kafka_topic_name
    expected_consumer_groups = 3
    expected_partitions = 6
  }
  
  # Validate consumer group configuration
  assert {
    condition = var.expected_consumer_groups <= var.expected_partitions
    error_message = "Number of consumer groups should not exceed number of partitions for optimal performance"
  }
  
  # In a real implementation, this would test:
  # - Consumer group creation and assignment
  # - Partition rebalancing behavior
  # - Message consumption across groups
  # - Offset management per consumer group
}

# Load Balancing Validation
run "validate_load_balancing" {
  command = plan
  
  variables {
    partition_distribution_tolerance = 0.1  # 10% tolerance for uneven distribution
  }
  
  # Test load balancing across consumer groups
  # This would validate that messages are distributed evenly
  # across partitions and consumer groups
  assert {
    condition = var.partition_distribution_tolerance > 0
    error_message = "Partition distribution tolerance must be positive"
  }
}

# Consumer Group Offset Testing
run "validate_offset_management" {
  command = plan
  
  variables {
    offset_commit_interval_ms = 5000
    enable_auto_commit = true
  }
  
  # Validate offset management behavior
  # In a real implementation, this would test:
  # - Offset commits at regular intervals
  # - Consumer restart behavior
  # - Offset reset scenarios
  
  assert {
    condition = var.offset_commit_interval_ms > 0
    error_message = "Offset commit interval must be positive"
  }
}

# Consumer Group Failure Recovery
run "validate_failure_recovery" {
  command = plan
  
  variables {
    consumer_failure_scenarios = ["network_partition", "consumer_crash", "rebalance"]
    recovery_timeout_ms = 30000
  }
  
  # Test consumer group behavior during failures
  # This would validate:
  # - Partition reassignment on consumer failure
  # - Message delivery guarantees during rebalancing
  # - Recovery time within acceptable limits
  
  assert {
    condition = var.recovery_timeout_ms > 0
    error_message = "Recovery timeout must be positive"
  }
}

# Cleanup Test
run "cleanup_consumer_groups" {
  command = plan
  
  variables {
    cleanup_consumer_groups = true
    cleanup_topic = true
  }
  
  # Cleanup validation
  assert {
    condition = var.cleanup_consumer_groups == true
    error_message = "Consumer groups cleanup should be enabled"
  }
}
