# Sprint 5: Enterprise Security and Compliance Module
# Comprehensive RBAC, security scanning, and compliance validation

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

# Service accounts for different access levels
resource "confluent_service_account" "kafka_admin" {
  display_name = "${var.environment}-kafka-admin"
  description  = "Administrative access for Kafka cluster management"
}

resource "confluent_service_account" "connector_operator" {
  display_name = "${var.environment}-connector-operator"
  description  = "Connector deployment and management access"
}

resource "confluent_service_account" "data_consumer" {
  display_name = "${var.environment}-data-consumer"
  description  = "Read-only access to specific topics"
}

resource "confluent_service_account" "monitoring_service" {
  display_name = "${var.environment}-monitoring-service"
  description  = "Monitoring and observability access"
}

# API Keys for service accounts
resource "confluent_api_key" "kafka_admin_key" {
  display_name = "${var.environment}-kafka-admin-key"
  description  = "Admin API key for cluster management"
  
  owner {
    id          = confluent_service_account.kafka_admin.id
    api_version = confluent_service_account.kafka_admin.api_version
    kind        = confluent_service_account.kafka_admin.kind
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

resource "confluent_api_key" "connector_operator_key" {
  display_name = "${var.environment}-connector-operator-key"
  description  = "Connector operator API key"
  
  owner {
    id          = confluent_service_account.connector_operator.id
    api_version = confluent_service_account.connector_operator.api_version
    kind        = confluent_service_account.connector_operator.kind
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

# RBAC Role Bindings - Kafka Admin
resource "confluent_role_binding" "kafka_admin_cluster" {
  principal   = "User:${confluent_service_account.kafka_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
}

resource "confluent_role_binding" "kafka_admin_environment" {
  principal   = "User:${confluent_service_account.kafka_admin.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}"
}

# RBAC Role Bindings - Connector Operator
resource "confluent_role_binding" "connector_operator_cluster" {
  principal   = "User:${confluent_service_account.connector_operator.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}"
}

resource "confluent_role_binding" "connector_operator_topics" {
  for_each = var.connector_accessible_topics
  
  principal   = "User:${confluent_service_account.connector_operator.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}/kafka=${var.cluster_id}/topic=${each.value}"
}

# RBAC Role Bindings - Data Consumer (Read-only)
resource "confluent_role_binding" "data_consumer_read" {
  for_each = var.consumer_accessible_topics
  
  principal   = "User:${confluent_service_account.data_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "crn://confluent.cloud/organization=${var.organization_id}/environment=${var.environment_id}/cloud-cluster=${var.cluster_id}/kafka=${var.cluster_id}/topic=${each.value}"
}

# ACL Rules for fine-grained access control
resource "confluent_kafka_acl" "admin_cluster_access" {
  kafka_cluster_id = var.cluster_id
  resource_type    = "CLUSTER"
  resource_name    = "kafka-cluster"
  pattern_type     = "LITERAL"
  principal        = "User:${confluent_service_account.kafka_admin.id}"
  host             = "*"
  operation        = "ALTER"
  permission       = "ALLOW"
}

resource "confluent_kafka_acl" "connector_topic_create" {
  kafka_cluster_id = var.cluster_id
  resource_type    = "TOPIC"
  resource_name    = "${var.environment}-connector-"
  pattern_type     = "PREFIXED"
  principal        = "User:${confluent_service_account.connector_operator.id}"
  host             = "*"
  operation        = "CREATE"
  permission       = "ALLOW"
}

resource "confluent_kafka_acl" "connector_topic_write" {
  kafka_cluster_id = var.cluster_id
  resource_type    = "TOPIC"
  resource_name    = "${var.environment}-connector-"
  pattern_type     = "PREFIXED"
  principal        = "User:${confluent_service_account.connector_operator.id}"
  host             = "*"
  operation        = "WRITE"
  permission       = "ALLOW"
}

# Consumer group ACLs
resource "confluent_kafka_acl" "data_consumer_group" {
  kafka_cluster_id = var.cluster_id
  resource_type    = "GROUP"
  resource_name    = "${var.environment}-consumer-group-"
  pattern_type     = "PREFIXED"
  principal        = "User:${confluent_service_account.data_consumer.id}"
  host             = "*"
  operation        = "READ"
  permission       = "ALLOW"
}

# HashiCorp Vault Integration for Secret Management
data "vault_generic_secret" "confluent_credentials" {
  count = var.vault_config.enabled ? 1 : 0
  path  = var.vault_config.secret_path
}

resource "vault_generic_secret" "service_account_keys" {
  count = var.vault_config.enabled ? 1 : 0
  path  = "${var.vault_config.secret_path}/service-accounts"
  
  data_json = jsonencode({
    kafka_admin_key    = confluent_api_key.kafka_admin_key.secret
    kafka_admin_id     = confluent_api_key.kafka_admin_key.id
    connector_operator_key = confluent_api_key.connector_operator_key.secret
    connector_operator_id  = confluent_api_key.connector_operator_key.id
  })
  
  depends_on = [
    confluent_api_key.kafka_admin_key,
    confluent_api_key.connector_operator_key
  ]
}

# Security scanning topics for audit logs
resource "confluent_kafka_topic" "security_audit_logs" {
  kafka_cluster_id = var.cluster_id
  topic_name       = "${var.environment}-security-audit-logs"
  partitions_count = 3
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.security_config.audit_retention_ms
    "min.insync.replicas" = "2"
    "compression.type"    = "lz4"
  }
}

resource "confluent_kafka_topic" "access_control_events" {
  kafka_cluster_id = var.cluster_id
  topic_name       = "${var.environment}-access-control-events"
  partitions_count = 1
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.security_config.access_events_retention_ms
    "min.insync.replicas" = "2"
  }
}

# Compliance validation resources
resource "confluent_kafka_topic" "compliance_reports" {
  kafka_cluster_id = var.cluster_id
  topic_name       = "${var.environment}-compliance-reports"
  partitions_count = 1
  
  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = var.compliance_config.report_retention_ms
    "min.insync.replicas" = "2"
  }
}

# Time-based rotation for security credentials
resource "time_rotating" "credential_rotation" {
  rotation_days = var.security_config.credential_rotation_days
}

# Trigger credential rotation when time expires
resource "null_resource" "rotate_credentials" {
  triggers = {
    rotation_time = time_rotating.credential_rotation.id
  }
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/rotate-credentials.sh ${var.environment}"
  }
  
  depends_on = [
    confluent_api_key.kafka_admin_key,
    confluent_api_key.connector_operator_key
  ]
}

# Security validation tests
resource "null_resource" "security_validation" {
  triggers = {
    cluster_id = var.cluster_id
    timestamp  = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Running security validation tests..."
      
      # Test RBAC permissions
      python3 ${path.module}/scripts/test-rbac-permissions.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id} \
        --service-accounts '${jsonencode({
          kafka_admin        = confluent_service_account.kafka_admin.id
          connector_operator = confluent_service_account.connector_operator.id
          data_consumer      = confluent_service_account.data_consumer.id
        })}'
      
      # Test ACL enforcement
      python3 ${path.module}/scripts/test-acl-enforcement.py \
        --environment ${var.environment} \
        --cluster-id ${var.cluster_id}
      
      # Validate compliance requirements
      if [ "${var.compliance_config.enable_validation}" = "true" ]; then
        python3 ${path.module}/scripts/compliance-validator.py \
          --environment ${var.environment} \
          --standards '${join(",", var.compliance_config.standards)}' \
          --audit-topic ${confluent_kafka_topic.security_audit_logs.topic_name}
      fi
      
      echo "Security validation completed"
    EOT
  }
  
  depends_on = [
    confluent_role_binding.kafka_admin_cluster,
    confluent_role_binding.connector_operator_cluster,
    confluent_kafka_acl.admin_cluster_access,
    confluent_kafka_topic.security_audit_logs
  ]
}
