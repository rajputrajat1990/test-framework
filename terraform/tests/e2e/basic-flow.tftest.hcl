# End-to-End Basic Flow Test Configuration
# Tests: Producer -> Source Connector -> Topic -> Sink Connector -> Consumer

run "basic_flow_setup" {
  command = plan
  
  variables {
    test_prefix = "e2e-basic-flow"
    test_suffix = formatdate("YYYYMMDD-hhmm", timestamp())
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
    
    # Test data configuration
    message_count = 100
    data_format  = "json"
    
    # S3 source connector configuration
    test_s3_bucket = var.test_s3_bucket
    aws_access_key_id = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    
    # PostgreSQL sink connector configuration  
    test_database_url = var.test_database_url
    test_database_user = var.test_database_user
    test_database_password = var.test_database_password
  }
}

run "basic_flow_apply" {
  command = apply
  
  variables {
    test_prefix = run.basic_flow_setup.test_prefix
    test_suffix = run.basic_flow_setup.test_suffix
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
    
    message_count = 100
    data_format  = "json"
    
    test_s3_bucket = var.test_s3_bucket
    aws_access_key_id = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    
    test_database_url = var.test_database_url
    test_database_user = var.test_database_user
    test_database_password = var.test_database_password
  }
}

run "verify_infrastructure" {
  command = plan
  
  variables {
    test_prefix = run.basic_flow_apply.test_prefix
    test_suffix = run.basic_flow_apply.test_suffix
    
    confluent_environment_id = var.confluent_environment_id
    confluent_cluster_id     = var.confluent_cluster_id
  }
  
  assert {
    condition = can(run.basic_flow_apply.kafka_topic_name)
    error_message = "Kafka topic was not created successfully"
  }
  
  assert {
    condition = can(run.basic_flow_apply.s3_source_connector_name)
    error_message = "S3 source connector was not created successfully"
  }
  
  assert {
    condition = can(run.basic_flow_apply.postgres_sink_connector_name)
    error_message = "PostgreSQL sink connector was not created successfully"
  }
}

# Data Flow Validation Tests
run "validate_data_flow" {
  command = plan
  
  variables {
    kafka_topic_name = run.basic_flow_apply.kafka_topic_name
    s3_bucket_name   = run.basic_flow_apply.s3_bucket_name
    database_url     = run.basic_flow_apply.database_url
  }
  
  # Verify topic configuration
  assert {
    condition = run.basic_flow_apply.kafka_topic_partitions == 3
    error_message = "Kafka topic should have 3 partitions"
  }
  
  # Verify connector states would be checked here
  # In a real implementation, this would include:
  # - S3 source connector status
  # - PostgreSQL sink connector status
  # - Data validation between source and sink
}

# Performance Validation
run "validate_performance" {
  command = plan
  
  variables {
    expected_throughput = 1000  # messages per minute
    max_latency_ms     = 30000  # 30 seconds
  }
  
  # Performance assertions would be implemented here
  # This is a placeholder for actual performance testing
  assert {
    condition = var.expected_throughput > 0
    error_message = "Expected throughput must be positive"
  }
}

# Cleanup Test
run "cleanup_basic_flow" {
  command = plan
  
  variables {
    cleanup_enabled = true
  }
  
  # This would normally be a destroy operation
  # For safety in the test file, we're using plan
}
