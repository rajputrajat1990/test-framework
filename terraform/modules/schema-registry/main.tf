terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Schema Registry Cluster
resource "confluent_schema_registry_cluster" "test_sr" {
  package = var.package_type
  
  environment {
    id = var.environment_id
  }
  
  region {
    id = var.region_id
  }
  
  lifecycle {
    prevent_destroy = false
  }
}

# Schema for different data formats
resource "confluent_schema" "avro_schema" {
  count = var.enable_avro ? 1 : 0
  
  schema_registry_cluster {
    id = confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = confluent_schema_registry_cluster.test_sr.rest_endpoint
  subject_name  = "${var.subject_prefix}-avro-value"
  format        = "AVRO"
  schema        = file("${path.module}/schemas/avro-schema.avsc")
  
  credentials {
    key    = var.sr_api_key
    secret = var.sr_api_secret
  }
}

resource "confluent_schema" "protobuf_schema" {
  count = var.enable_protobuf ? 1 : 0
  
  schema_registry_cluster {
    id = confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = confluent_schema_registry_cluster.test_sr.rest_endpoint
  subject_name  = "${var.subject_prefix}-protobuf-value"
  format        = "PROTOBUF"
  schema        = file("${path.module}/schemas/user-event.proto")
  
  credentials {
    key    = var.sr_api_key
    secret = var.sr_api_secret
  }
}

resource "confluent_schema" "json_schema" {
  count = var.enable_json_schema ? 1 : 0
  
  schema_registry_cluster {
    id = confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = confluent_schema_registry_cluster.test_sr.rest_endpoint
  subject_name  = "${var.subject_prefix}-json-value"
  format        = "JSON"
  schema        = file("${path.module}/schemas/json-schema.json")
  
  credentials {
    key    = var.sr_api_key
    secret = var.sr_api_secret
  }
}

# Schema Registry API Key
resource "confluent_api_key" "schema_registry_api_key" {
  display_name = "${var.subject_prefix}-sr-api-key"
  description  = "Schema Registry API Key for ${var.subject_prefix} testing"
  
  owner {
    id          = var.service_account_id
    api_version = "iam/v2"
    kind        = "ServiceAccount"
  }
  
  managed_resource {
    id          = confluent_schema_registry_cluster.test_sr.id
    api_version = confluent_schema_registry_cluster.test_sr.api_version
    kind        = confluent_schema_registry_cluster.test_sr.kind
    
    environment {
      id = var.environment_id
    }
  }
  
  lifecycle {
    prevent_destroy = false
  }
}
