# Sprint 4: Outputs for Flink Compute Pool Module

output "compute_pool_id" {
  description = "ID of the Flink compute pool"
  value       = confluent_flink_compute_pool.test_pool.id
}

output "compute_pool_display_name" {
  description = "Display name of the Flink compute pool"
  value       = confluent_flink_compute_pool.test_pool.display_name
}

output "compute_pool_cloud" {
  description = "Cloud provider of the compute pool"
  value       = confluent_flink_compute_pool.test_pool.cloud
}

output "compute_pool_region" {
  description = "Region of the compute pool"
  value       = confluent_flink_compute_pool.test_pool.region
}

output "compute_pool_max_cfu" {
  description = "Maximum CFU of the compute pool"
  value       = confluent_flink_compute_pool.test_pool.max_cfu
}

output "compute_pool_current_cfu" {
  description = "Current CFU usage of the compute pool (not available in this provider version)"
  value       = 0
}

output "compute_pool_resource_name" {
  description = "Resource name of the compute pool"
  value       = try(data.confluent_flink_compute_pool.test_pool_status.resource_name, "")
}

output "compute_pool_status" {
  description = "Detailed status information of the compute pool"
  value       = local.pool_status
}

# Service Account Outputs
output "service_account_id" {
  description = "ID of the Flink service account"
  value       = confluent_service_account.flink_sa.id
}

output "service_account_display_name" {
  description = "Display name of the Flink service account"
  value       = confluent_service_account.flink_sa.display_name
}

output "service_account_description" {
  description = "Description of the Flink service account"
  value       = confluent_service_account.flink_sa.description
}

# API Key Outputs
output "flink_api_key_id" {
  description = "ID of the Flink API key"
  value       = confluent_api_key.flink_api_key.id
  sensitive   = true
}

output "flink_api_key_secret" {
  description = "Secret of the Flink API key"
  value       = confluent_api_key.flink_api_key.secret
  sensitive   = true
}

# Role Binding Outputs
output "role_bindings" {
  description = "Role bindings for the Flink service account"
  value = {
    environment_admin = {
      id          = confluent_role_binding.flink_environment_admin.id
      principal   = confluent_role_binding.flink_environment_admin.principal
      role_name   = confluent_role_binding.flink_environment_admin.role_name
      crn_pattern = confluent_role_binding.flink_environment_admin.crn_pattern
    }
    flink_developer = {
      id          = confluent_role_binding.flink_developer.id
      principal   = confluent_role_binding.flink_developer.principal
      role_name   = confluent_role_binding.flink_developer.role_name
      crn_pattern = confluent_role_binding.flink_developer.crn_pattern
    }
  }
}

# Readiness Outputs
output "pool_ready" {
  description = "Whether the compute pool is ready for use"
  value       = local.pool_ready
}

output "pool_endpoint" {
  description = "Endpoint information for the compute pool (when available)"
  value = {
    id                = confluent_flink_compute_pool.test_pool.id
    api_version       = confluent_flink_compute_pool.test_pool.api_version
    kind             = confluent_flink_compute_pool.test_pool.kind
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of the compute pool configuration"
  value = {
    pool_name        = var.pool_name
    environment_id   = var.environment_id
    cloud_provider   = var.cloud_provider
    region          = var.region
    max_cfu         = var.max_cfu
    current_cfu     = 0  # Not available in this provider version
    created_at      = confluent_flink_compute_pool.test_pool.id # Creation timestamp proxy
    service_account = confluent_service_account.flink_sa.display_name
    api_key_created = confluent_api_key.flink_api_key.id != ""
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Information for monitoring the compute pool"
  value = {
    pool_id           = confluent_flink_compute_pool.test_pool.id
    service_account   = confluent_service_account.flink_sa.id
    max_cfu          = confluent_flink_compute_pool.test_pool.max_cfu
    cloud_provider   = confluent_flink_compute_pool.test_pool.cloud
    region           = confluent_flink_compute_pool.test_pool.region
  }
}
