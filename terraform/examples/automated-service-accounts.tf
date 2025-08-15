# Example configuration for using automated service account with orgadmin RBAC
# This example shows how to implement the automated API key generation

terraform {
  required_version = ">= 1.12.2"
  
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

# Initial Bootstrap Provider Configuration
# You only need ONE manually created API key with orgadmin privileges for bootstrap
provider "confluent" {
  cloud_api_key    = var.bootstrap_api_key
  cloud_api_secret = var.bootstrap_api_secret
}

# Variables
variable "bootstrap_api_key" {
  description = "Initial bootstrap API key (manually created with orgadmin privileges)"
  type        = string
  sensitive   = true
}

variable "bootstrap_api_secret" {
  description = "Initial bootstrap API secret (manually created with orgadmin privileges)"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "Confluent Cloud Organization ID"
  type        = string
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud Kafka Cluster ID"
  type        = string
}

# Automated Service Accounts for different purposes
module "test_automation_service_account" {
  source = "./modules/automated-service-account"

  service_account_name        = "test-automation-sa"
  service_account_description = "Service account for automated testing framework"
  
  organization_id = var.organization_id
  environment_id  = var.environment_id
  cluster_id      = var.cluster_id
  
  # Orgadmin for full automation capabilities
  rbac_roles = {
    orgadmin = {
      role_name   = "OrganizationAdmin"
      crn_pattern = "crn://confluent.cloud/organization/${var.organization_id}"
    }
  }
  
  create_cloud_api_key    = true
  create_cluster_api_key  = true
  
  tags = {
    purpose     = "test-automation"
    managed-by  = "terraform"
    environment = "test"
  }
}

# Monitoring Service Account with limited permissions
module "monitoring_service_account" {
  source = "./modules/automated-service-account"

  service_account_name        = "monitoring-sa"
  service_account_description = "Service account for monitoring and metrics collection"
  
  organization_id = var.organization_id
  environment_id  = var.environment_id
  cluster_id      = var.cluster_id
  
  # Limited permissions for monitoring
  rbac_roles = {
    metrics_viewer = {
      role_name   = "MetricsViewer"
      crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}"
    }
    cluster_read = {
      role_name   = "DeveloperRead"
      crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
    }
  }
  
  create_cloud_api_key    = false  # Don't need cloud-level key for monitoring
  create_cluster_api_key  = true
  
  tags = {
    purpose     = "monitoring"
    managed-by  = "terraform"
    environment = "production"
  }
}

# Development Service Account for developers
module "development_service_account" {
  source = "./modules/automated-service-account"

  service_account_name        = "development-sa"
  service_account_description = "Service account for development team"
  
  organization_id = var.organization_id
  environment_id  = var.environment_id
  cluster_id      = var.cluster_id
  
  # Development permissions
  rbac_roles = {
    env_admin = {
      role_name   = "EnvironmentAdmin"
      crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}"
    }
    cluster_manage = {
      role_name   = "DeveloperManage"
      crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
    }
  }
  
  create_cloud_api_key    = false
  create_cluster_api_key  = true
  
  tags = {
    purpose     = "development"
    managed-by  = "terraform"
    environment = "development"
  }
}

# Outputs for using the generated API keys
output "test_automation_cloud_api_key" {
  description = "Cloud API key for test automation"
  value = {
    key_id = module.test_automation_service_account.cloud_api_key_id
    secret = module.test_automation_service_account.cloud_api_key_secret
  }
  sensitive = true
}

output "monitoring_cluster_api_key" {
  description = "Cluster API key for monitoring"
  value = {
    key_id = module.monitoring_service_account.cluster_api_key_id
    secret = module.monitoring_service_account.cluster_api_key_secret
  }
  sensitive = true
}

output "development_cluster_api_key" {
  description = "Cluster API key for development"
  value = {
    key_id = module.development_service_account.cluster_api_key_id
    secret = module.development_service_account.cluster_api_key_secret
  }
  sensitive = true
}

# Usage example: Configure other providers with the generated API keys
# You can use these outputs to configure other Confluent providers or pass to other modules

# Example of using the generated API key for another provider instance
provider "confluent" {
  alias = "automated"
  
  cloud_api_key    = module.test_automation_service_account.cloud_api_key_id
  cloud_api_secret = module.test_automation_service_account.cloud_api_key_secret
}

# Example terraform.tfvars file structure:
# bootstrap_api_key    = "YOUR_INITIAL_ORGADMIN_API_KEY"
# bootstrap_api_secret = "YOUR_INITIAL_ORGADMIN_API_SECRET"
# organization_id      = "your-org-id"
# environment_id       = "env-12345"
# cluster_id          = "lkc-12345"
