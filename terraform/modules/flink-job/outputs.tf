# Sprint 4: Outputs for Flink Job Module

# Primary Job Outputs
output "statement_id" {
  description = "ID of the Flink statement"
  value       = confluent_flink_statement.transformation_job.id
}

output "statement_name" {
  description = "Name of the Flink statement"
  value       = confluent_flink_statement.transformation_job.statement_name
}

output "statement_content" {
  description = "Content of the Flink SQL statement"
  value       = confluent_flink_statement.transformation_job.statement
  sensitive   = false
}

output "job_status" {
  description = "Status of the Flink job"
  value       = try(data.confluent_flink_statement.job_status.status, "UNKNOWN")
}

output "job_details" {
  description = "Detailed information about the Flink job"
  value       = local.job_status
}

# Compute Pool Information
output "compute_pool_id" {
  description = "ID of the compute pool running the job"
  value       = var.compute_pool_id
}

output "compute_pool_info" {
  description = "Information about the compute pool"
  value = {
    id           = data.confluent_flink_compute_pool.pool.id
    display_name = data.confluent_flink_compute_pool.pool.display_name
    cloud        = data.confluent_flink_compute_pool.pool.cloud
    region       = data.confluent_flink_compute_pool.pool.region
    current_cfu  = data.confluent_flink_compute_pool.pool.current_cfu
    max_cfu      = data.confluent_flink_compute_pool.pool.max_cfu
  }
}

# Service Account Information
output "service_account_id" {
  description = "ID of the service account running the job"
  value       = var.service_account_id
}

# Validation Job Outputs (when enabled)
output "validation_job_id" {
  description = "ID of the validation job (if enabled)"
  value       = var.enable_validation ? try(confluent_flink_statement.validation_job[0].id, null) : null
}

output "validation_enabled" {
  description = "Whether validation is enabled for this job"
  value       = local.validation_enabled
}

# Performance Monitoring Outputs (when enabled)
output "performance_monitor_id" {
  description = "ID of the performance monitoring job (if enabled)"
  value       = var.enable_performance_monitoring ? try(confluent_flink_statement.performance_monitor[0].id, null) : null
}

output "performance_monitoring_enabled" {
  description = "Whether performance monitoring is enabled for this job"
  value       = local.performance_monitoring_enabled
}

# Configuration Summary
output "job_configuration" {
  description = "Summary of the job configuration"
  value = {
    statement_name    = var.statement_name
    environment_id    = var.environment_id
    cluster_id       = var.cluster_id
    compute_pool_id  = var.compute_pool_id
    service_account  = var.service_account_id
    sql_file_path    = var.sql_file_path
    stop_on_error    = var.stop_on_error
    validation_enabled = local.validation_enabled
    performance_monitoring_enabled = local.performance_monitoring_enabled
  }
}

# Resource Information
output "resource_info" {
  description = "Resource information for the job"
  value = {
    parallelism          = var.parallelism
    memory_limit         = var.memory_limit
    checkpoint_interval  = var.checkpoint_interval
    checkpoint_timeout   = var.checkpoint_timeout
  }
}

# Table Information
output "table_info" {
  description = "Source and target table information"
  value = {
    source_table = var.source_table_name
    target_table = var.target_table_name
  }
}

# Flink Properties
output "flink_properties" {
  description = "Flink properties used for the job"
  value       = merge(var.flink_properties, {
    "sql.current-catalog"  = var.environment_id
    "sql.current-database" = var.cluster_id
  })
}

# Job State Information
output "job_state" {
  description = "Current state information of the job"
  value = {
    id              = confluent_flink_statement.transformation_job.id
    status          = try(data.confluent_flink_statement.job_status.status, "UNKNOWN")
    created_at      = confluent_flink_statement.transformation_job.id # Proxy for creation time
    compute_pool    = var.compute_pool_id
    environment     = var.environment_id
    cluster         = var.cluster_id
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Information for monitoring the job"
  value = {
    statement_id     = confluent_flink_statement.transformation_job.id
    statement_name   = var.statement_name
    compute_pool_id  = var.compute_pool_id
    environment_id   = var.environment_id
    service_account  = var.service_account_id
    validation_job   = local.validation_enabled ? try(confluent_flink_statement.validation_job[0].id, null) : null
    performance_job  = local.performance_monitoring_enabled ? try(confluent_flink_statement.performance_monitor[0].id, null) : null
  }
}

# Error Information
output "job_errors" {
  description = "Error information (if any) for debugging"
  value = {
    status = try(data.confluent_flink_statement.job_status.status, "UNKNOWN")
    # Additional error details would be available through Confluent Cloud Console
    troubleshooting_hint = "Check Confluent Cloud Console for detailed error logs if status is FAILED"
  }
}

# SQL Template Variables (for debugging)
output "sql_template_variables" {
  description = "Template variables used in SQL generation"
  value       = var.sql_template_variables
  sensitive   = false
}

# Job Dependencies
output "job_dependencies" {
  description = "Dependencies for this job"
  value = {
    depends_on_compute_pool = data.confluent_flink_compute_pool.pool.id
    requires_service_account = var.service_account_id
    sql_file_path = var.sql_file_path
  }
}
