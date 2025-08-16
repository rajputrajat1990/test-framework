# Sprint 5: Multi-Environment Production Deployment Module
# Blue-green deployment, configuration management, health monitoring

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 16.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Input variables
variable "environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Cloud cluster ID"
  type        = string
}

variable "organization_id" {
  description = "Confluent Cloud organization ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "deployment_config" {
  description = "Deployment configuration"
  type = object({
    version                        = optional(string, "1.0.0")
    cloud_provider                 = optional(string, "aws")
    region                        = optional(string, "us-west-2")
    connectors                    = optional(list(string), [])
    validation_frequency_hours    = optional(number, 24)
    alert_on_config_drift        = optional(bool, true)
    enable_auto_recovery         = optional(bool, false)
  })
  default = {}
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type = object({
    sumo_collector_id = optional(string, "")
    log_topics       = optional(list(string), [])
  })
  default = {}
}

variable "security_config" {
  description = "Security configuration"
  type = object({
    connector_topics = optional(list(string), [])
    consumer_topics  = optional(list(string), [])
    enable_mtls     = optional(bool, false)
    enable_rbac     = optional(bool, true)
  })
  default = {}
}

variable "vault_config" {
  description = "Vault configuration for secret management"
  type = object({
    enabled     = optional(bool, false)
    address    = optional(string, "")
    token      = optional(string, "")
    path_prefix = optional(string, "confluent")
  })
  default = {}
}

variable "gitlab_config" {
  description = "GitLab integration configuration"
  type = object({
    enabled    = optional(bool, false)
    project_id = optional(string, "")
  })
  default = {}
}

# Data source for current environment configuration
data "confluent_environment" "current" {
  id = var.environment_id
}

data "confluent_kafka_cluster" "current" {
  id = var.cluster_id
  environment {
    id = var.environment_id
  }
}

# Environment-specific configuration management
locals {
  environment_config = {
    dev = {
      compute_units         = 5
      connector_tasks       = 1
      monitoring_retention  = "7d"
      alert_channels       = ["slack"]
      auto_scaling_enabled = false
    }
    
    staging = {
      compute_units         = 10
      connector_tasks       = 2
      monitoring_retention  = "30d"
      alert_channels       = ["slack", "email"]
      auto_scaling_enabled = true
    }
    
    prod = {
      compute_units         = 50
      connector_tasks       = 4
      monitoring_retention  = "90d"
      alert_channels       = ["slack", "email", "pagerduty"]
      auto_scaling_enabled = true
    }
  }
  
  current_config = local.environment_config[var.environment]
}

# Blue-Green Deployment Configuration
resource "confluent_kafka_topic" "deployment_coordination" {
  topic_name       = "${var.environment}-deployment-coordination"
  partitions_count = 1
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "86400000"  # 1 day
    "min.insync.replicas" = "2"
  }
}

resource "confluent_kafka_topic" "health_checks" {
  topic_name       = "${var.environment}-health-checks"
  partitions_count = 3
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "604800000"  # 7 days
    "min.insync.replicas" = "2"
  }
}

# Deployment service account
resource "confluent_service_account" "deployment_sa" {
  display_name = "${var.environment}-deployment-sa"
  description  = "Service account for deployment automation and health checks"
}

resource "confluent_api_key" "deployment_api_key" {
  display_name = "${var.environment}-deployment-key"
  description  = "API key for deployment operations"
  
  owner {
    id          = confluent_service_account.deployment_sa.id
    api_version = confluent_service_account.deployment_sa.api_version
    kind        = confluent_service_account.deployment_sa.kind
  }
  
  managed_resource {
    id               = var.cluster_id
    api_version      = "cmk/v2"
    kind             = "Cluster"
    environment {
      id = var.environment_id
    }
  }
}

# RBAC for deployment service account
resource "confluent_role_binding" "deployment_admin" {
  principal   = "User:${confluent_service_account.deployment_sa.id}"
  role_name   = var.environment == "prod" ? "CloudClusterAdmin" : "DeveloperManage"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
}

# Core testing framework topics
resource "confluent_kafka_topic" "core_topics" {
  for_each = toset(["monitoring-logs", "connector-metrics", "deployment-status", "health-checks"])
  
  topic_name       = "${var.environment}-${each.value}"
  partitions_count = var.environment == "prod" ? 6 : 3
  
  kafka_cluster {
    id = var.cluster_id
  }
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.environment == "prod" ? "2592000000" : "604800000"  # 30 days prod, 7 days others
    "min.insync.replicas" = var.environment == "prod" ? "3" : "2"
    "compression.type"    = "lz4"
  }
}

module "monitoring_integration" {
  source = "../monitoring"
  
  environment_id   = var.environment_id
  cluster_id       = var.cluster_id
  organization_id  = var.organization_id
  environment      = var.environment
  cluster_name     = data.confluent_kafka_cluster.current.display_name
  
  sumo_collector_id = var.monitoring_config.sumo_collector_id
  log_topics        = var.monitoring_config.log_topics
  
  monitoring_config = {
    connector_tasks      = local.current_config.connector_tasks
    batch_size          = var.environment == "prod" ? 500 : 100
    batch_timeout       = var.environment == "prod" ? 10000 : 5000
    log_retention_ms    = var.environment == "prod" ? 2592000000 : 604800000  # 30d vs 7d
    metrics_retention_ms = var.environment == "prod" ? 7776000000 : 2592000000  # 90d vs 30d
  }
  
  alert_config = {
    alert_channels                = local.current_config.alert_channels
    connector_failure_threshold   = var.environment == "prod" ? 1 : 2
    consumer_lag_threshold        = var.environment == "prod" ? 5000 : 10000
    error_rate_threshold         = var.environment == "prod" ? 1 : 5
    notification_cooldown_minutes = var.environment == "prod" ? 5 : 15
  }
}

module "enterprise_security" {
  source = "../enterprise-security"
  
  environment_id   = var.environment_id
  cluster_id       = var.cluster_id
  organization_id  = var.organization_id
  environment      = var.environment
  
  connector_accessible_topics = var.security_config.connector_topics
  consumer_accessible_topics  = var.security_config.consumer_topics
  
  vault_config = var.vault_config
  
  security_config = {
    credential_rotation_days      = var.environment == "prod" ? 30 : 90
    enable_automatic_rotation     = var.environment == "prod" ? true : false
    audit_retention_ms           = var.environment == "prod" ? 7776000000 : 2592000000  # 90d vs 30d
    enforce_mfa                  = var.environment == "prod"
    enable_vulnerability_scanning = true
    scan_frequency_hours         = var.environment == "prod" ? 6 : 24
    require_tls                  = true
    min_tls_version             = "1.2"
  }
}

# Flink compute pool for stream processing
module "flink_compute_pool" {
  source = "../compute-pool"
  
  pool_name      = "${var.environment}-deployment-pool"
  environment_id = var.environment_id
  organization_id = var.organization_id
  
  cloud_provider = var.deployment_config.cloud_provider
  region         = var.deployment_config.region
  max_cfu        = local.current_config.compute_units
}

# GitLab CI/CD Integration
data "gitlab_project" "framework_project" {
  count = var.gitlab_config.enabled ? 1 : 0
  id    = var.gitlab_config.project_id
}

resource "gitlab_project_variable" "confluent_credentials" {
  count = var.gitlab_config.enabled ? length(local.gitlab_variables) : 0
  
  project   = data.gitlab_project.framework_project[0].id
  key       = local.gitlab_variables[count.index].key
  value     = local.gitlab_variables[count.index].value
  protected = true
  masked    = true
  
  environment_scope = var.environment
}

locals {
  gitlab_variables = var.gitlab_config.enabled ? [
    {
      key   = "CONFLUENT_CLOUD_API_KEY"
      value = confluent_api_key.deployment_api_key.id
    },
    {
      key   = "CONFLUENT_CLOUD_API_SECRET"
      value = confluent_api_key.deployment_api_key.secret
    },
    {
      key   = "CONFLUENT_ENVIRONMENT_ID"
      value = var.environment_id
    },
    {
      key   = "CONFLUENT_CLUSTER_ID"
      value = var.cluster_id
    }
  ] : []
}

# Health check and monitoring setup
resource "null_resource" "deployment_health_checks" {
  triggers = {
    deployment_version = var.deployment_config.version
    cluster_id         = var.cluster_id
    timestamp          = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Running deployment health checks for ${var.environment}..."
      
      # Wait for core components to be ready
      sleep 30
      
      # Run comprehensive health validation
      python3 ${path.module}/scripts/deployment-health-check.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id} \
        --expected-topics 4 \
        --expected-connectors 0 \
        --health-check-timeout 300
      
      # Validate monitoring integration
      if [ "${module.monitoring_integration.sumo_logic_integration.connector_id}" != "" ]; then
        echo "Monitoring integration validated"
      else
        echo "WARNING: Monitoring integration not ready"
      fi
      
  # Validate security configuration (optional)
  # python3 ${path.module}/scripts/security-validation.py \
  #   --environment ${var.environment} \
  #   --cluster-id ${var.cluster_id}
      
      # Generate deployment report
      python3 ${path.module}/scripts/generate-deployment-report.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id} \
        --deployment-version ${var.deployment_config.version} \
        --output deployment-report-${var.environment}.json
      
      echo "Deployment health checks completed"
    EOT
  }
  
  depends_on = [
    confluent_kafka_topic.core_topics,
    module.monitoring_integration,
    module.enterprise_security,
    module.flink_compute_pool
  ]
}

# Configuration drift detection
resource "time_rotating" "config_validation" {
  rotation_hours = var.deployment_config.validation_frequency_hours
}

resource "null_resource" "configuration_drift_detection" {
  triggers = {
    validation_time = time_rotating.config_validation.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Running configuration drift detection..."
      
      python3 ${path.module}/scripts/detect-config-drift.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id} \
        --expected-config ${path.module}/config/${var.environment}-expected-config.json \
        --alert-on-drift ${var.deployment_config.alert_on_config_drift}
      
      echo "Configuration drift detection completed"
    EOT
  }
  
  depends_on = [null_resource.deployment_health_checks]
}

# Auto-recovery and self-healing
resource "null_resource" "auto_recovery" {
  count = var.deployment_config.enable_auto_recovery ? 1 : 0
  
  triggers = {
    cluster_id = var.cluster_id
    timestamp  = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Setting up auto-recovery monitoring..."
      
      # Start background health monitoring
      nohup python3 ${path.module}/scripts/auto-recovery-monitor.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id} \
        --recovery-actions-config ${path.module}/config/recovery-actions.yaml \
        --log-file /tmp/auto-recovery-${var.environment}.log &
      
      echo "Auto-recovery monitoring started"
    EOT
  }
}
