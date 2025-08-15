# Sprint 4: Confluent Cloud Flink Compute Pool Module
# Creates and manages Flink compute pools for transformation testing

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Flink Compute Pool for testing
resource "confluent_flink_compute_pool" "test_pool" {
  display_name = "${var.pool_name}"
  cloud        = var.cloud_provider
  region       = var.region
  max_cfu      = var.max_cfu
  
  environment {
    id = var.environment_id
  }
}

# Service account for Flink operations
resource "confluent_service_account" "flink_sa" {
  display_name = "${var.pool_name}-flink-sa"
  description  = "Service account for Flink compute pool ${var.pool_name}"
}

# Role binding for Flink service account - Environment Admin
resource "confluent_role_binding" "flink_environment_admin" {
  principal   = "User:${confluent_service_account.flink_sa.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}"
}

# Role binding for Flink service account - FlinkDeveloper
resource "confluent_role_binding" "flink_developer" {
  principal   = "User:${confluent_service_account.flink_sa.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/flink-compute-pool=${confluent_flink_compute_pool.test_pool.id}"
}

# API Key for Flink service account
resource "confluent_api_key" "flink_api_key" {
  display_name = "${var.pool_name}-flink-api-key"
  description  = "API key for Flink compute pool ${var.pool_name}"
  
  owner {
    id          = confluent_service_account.flink_sa.id
    api_version = confluent_service_account.flink_sa.api_version
    kind        = confluent_service_account.flink_sa.kind
  }

  managed_resource {
    id          = confluent_flink_compute_pool.test_pool.id
    api_version = confluent_flink_compute_pool.test_pool.api_version
    kind        = confluent_flink_compute_pool.test_pool.kind

    environment {
      id = var.environment_id
    }
  }

  depends_on = [
    confluent_role_binding.flink_environment_admin,
    confluent_role_binding.flink_developer,
  ]
}

# Wait for compute pool to be ready
resource "time_sleep" "wait_for_compute_pool" {
  depends_on = [confluent_flink_compute_pool.test_pool]
  
  create_duration = "60s"
}

# Data source to check compute pool status
data "confluent_flink_compute_pool" "test_pool_status" {
  id = confluent_flink_compute_pool.test_pool.id
  
  environment {
    id = var.environment_id
  }
  
  depends_on = [time_sleep.wait_for_compute_pool]
}

# Local values for output processing
locals {
  pool_ready = data.confluent_flink_compute_pool.test_pool_status.resource_name != ""
  
  pool_status = {
    id           = confluent_flink_compute_pool.test_pool.id
    display_name = confluent_flink_compute_pool.test_pool.display_name
    cloud        = confluent_flink_compute_pool.test_pool.cloud
    region       = confluent_flink_compute_pool.test_pool.region
    max_cfu      = confluent_flink_compute_pool.test_pool.max_cfu
    resource_name = data.confluent_flink_compute_pool.test_pool_status.resource_name
  }
}
