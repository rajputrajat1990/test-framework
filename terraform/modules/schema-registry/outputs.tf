output "schema_registry_id" {
  description = "Schema Registry Cluster ID"
  value       = data.confluent_schema_registry_cluster.test_sr.id
}

output "schema_registry_rest_endpoint" {
  description = "Schema Registry REST Endpoint"
  value       = data.confluent_schema_registry_cluster.test_sr.rest_endpoint
}

// API keys are provided via variables in this module; no outputs for keys.

output "avro_schema_id" {
  description = "Avro Schema ID"
  value       = var.enable_avro ? confluent_schema.avro_schema[0].id : null
}

output "avro_schema_version" {
  description = "Avro Schema Version"
  value       = var.enable_avro ? confluent_schema.avro_schema[0].version : null
}

output "protobuf_schema_id" {
  description = "Protobuf Schema ID"
  value       = var.enable_protobuf ? confluent_schema.protobuf_schema[0].id : null
}

output "protobuf_schema_version" {
  description = "Protobuf Schema Version"
  value       = var.enable_protobuf ? confluent_schema.protobuf_schema[0].version : null
}

output "json_schema_id" {
  description = "JSON Schema ID"
  value       = var.enable_json_schema ? confluent_schema.json_schema[0].id : null
}

output "json_schema_version" {
  description = "JSON Schema Version"
  value       = var.enable_json_schema ? confluent_schema.json_schema[0].version : null
}
