# Service Account Outputs
output "service_account_id" {
  description = "ID of the created service account"
  value       = confluent_service_account.main.id
}

output "service_account_display_name" {
  description = "Display name of the created service account"
  value       = confluent_service_account.main.display_name
}

output "service_account_description" {
  description = "Description of the created service account"
  value       = confluent_service_account.main.description
}

# Cloud API Key Outputs
output "cloud_api_key_id" {
  description = "ID of the cloud API key"
  value       = var.create_cloud_api_key ? confluent_api_key.cloud[0].id : null
  sensitive   = true
}

output "cloud_api_key_secret" {
  description = "Secret of the cloud API key"
  value       = var.create_cloud_api_key ? confluent_api_key.cloud[0].secret : null
  sensitive   = true
}

# Cluster API Key Outputs
output "cluster_api_key_id" {
  description = "ID of the cluster API key"
  value       = var.create_cluster_api_key && var.cluster_id != "" ? confluent_api_key.cluster[0].id : null
  sensitive   = true
}

output "cluster_api_key_secret" {
  description = "Secret of the cluster API key"
  value       = var.create_cluster_api_key && var.cluster_id != "" ? confluent_api_key.cluster[0].secret : null
  sensitive   = true
}

# RBAC Information
output "rbac_role_bindings" {
  description = "Map of RBAC role bindings created for this service account"
  value = {
    for k, v in confluent_role_binding.main : k => {
      principal   = v.principal
      role_name   = v.role_name
      crn_pattern = v.crn_pattern
    }
  }
}
