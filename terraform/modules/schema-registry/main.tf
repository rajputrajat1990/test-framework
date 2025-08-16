terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.37.0"
    }
  }
}

# Schema Registry Cluster (data source in provider v2+)
data "confluent_schema_registry_cluster" "test_sr" {
  environment {
    id = var.environment_id
  }
  # Optionally filter by region or name if needed. Region is not directly used here.
}

# Schema for different data formats
resource "confluent_schema" "avro_schema" {
  count = var.enable_avro ? 1 : 0
  
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = data.confluent_schema_registry_cluster.test_sr.rest_endpoint
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
    id = data.confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = data.confluent_schema_registry_cluster.test_sr.rest_endpoint
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
    id = data.confluent_schema_registry_cluster.test_sr.id
  }
  
  rest_endpoint = data.confluent_schema_registry_cluster.test_sr.rest_endpoint
  subject_name  = "${var.subject_prefix}-json-value"
  format        = "JSON"
  schema        = file("${path.module}/schemas/json-schema.json")
  
  credentials {
    key    = var.sr_api_key
    secret = var.sr_api_secret
  }
}

# Note: API key creation for Schema Registry is often managed outside this module or by referencing
# the data source attributes (api_version/kind) which are not exposed as resource types here in v2.
# If needed, create API keys in a higher-level module and pass sr_api_key/sr_api_secret as inputs.
