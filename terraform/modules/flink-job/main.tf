# Sprint 4: Confluent Cloud Flink Job Module
# Creates and manages Flink SQL statements for transformation testing

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

# Data source to get compute pool information
data "confluent_flink_compute_pool" "pool" {
  id = var.compute_pool_id
  
  environment {
    id = var.environment_id
  }
}

# Flink Statement for transformation job
resource "confluent_flink_statement" "transformation_job" {
  statement = templatefile(var.sql_file_path, var.sql_template_variables)
  
  compute_pool {
    id = var.compute_pool_id
  }
  
  principal {
    id = var.service_account_id
  }
  
  properties = merge(var.flink_properties, {
    "sql.current-catalog"  = var.environment_id
    "sql.current-database" = var.cluster_id
  })
  
  # Optional statement name
  statement_name = var.statement_name
  
  depends_on = [data.confluent_flink_compute_pool.pool]
}

# Wait for statement to be created and running
resource "time_sleep" "wait_for_statement" {
  depends_on = [confluent_flink_statement.transformation_job]
  
  create_duration = var.statement_creation_wait_time
}

# Optional validation statement for testing
resource "confluent_flink_statement" "validation_job" {
  count = var.enable_validation ? 1 : 0
  
  statement = templatefile(var.validation_sql_file_path, var.sql_template_variables)
  
  compute_pool {
    id = var.compute_pool_id
  }
  
  principal {
    id = var.service_account_id
  }
  
  properties = merge(var.flink_properties, {
    "sql.current-catalog"  = var.environment_id
    "sql.current-database" = var.cluster_id
  })
  
  statement_name = "${var.statement_name}-validation"
  
  depends_on = [confluent_flink_statement.transformation_job]
}

# Performance monitoring statement (optional)
resource "confluent_flink_statement" "performance_monitor" {
  count = var.enable_performance_monitoring ? 1 : 0
  
  statement = <<-EOT
    -- Performance monitoring query
    SELECT 
      'performance_metrics' as metric_type,
      COUNT(*) as processed_records,
      COUNT(DISTINCT user_id) as unique_users,
      AVG(CAST(JSON_VALUE(payload, '$.processing_time_ms') AS DOUBLE)) as avg_processing_time_ms,
      CURRENT_TIMESTAMP as measurement_time
    FROM ${var.source_table_name}
    WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' MINUTE
    GROUP BY TUMBLE(PROCTIME(), INTERVAL '1' MINUTE);
  EOT
  
  compute_pool {
    id = var.compute_pool_id
  }
  
  principal {
    id = var.service_account_id
  }
  
  properties = merge(var.flink_properties, {
    "sql.current-catalog"  = var.environment_id
    "sql.current-database" = var.cluster_id
  })
  
  statement_name = "${var.statement_name}-performance"
  
  depends_on = [confluent_flink_statement.transformation_job]
}

# Local values for output processing
locals {
  job_status = {
    id            = confluent_flink_statement.transformation_job.id
    statement     = confluent_flink_statement.transformation_job.statement
    statement_name = confluent_flink_statement.transformation_job.statement_name
    status        = "UNKNOWN"  # Status not available via data source in this provider version
    compute_pool  = var.compute_pool_id
    principal     = var.service_account_id
  }
  
  validation_enabled = var.enable_validation && length(confluent_flink_statement.validation_job) > 0
  performance_monitoring_enabled = var.enable_performance_monitoring && length(confluent_flink_statement.performance_monitor) > 0
}
