output "connector_id" {
  description = "SMT Test Connector ID"
  value       = confluent_connector.smt_test_connector.id
}

output "connector_name" {
  description = "SMT Test Connector Name"
  value       = confluent_connector.smt_test_connector.display_name
}

output "connector_status" {
  description = "SMT Test Connector Status"
  value       = confluent_connector.smt_test_connector.status
}

output "source_topic_name" {
  description = "Source topic name"
  value       = confluent_kafka_topic.smt_source.topic_name
}

output "target_topic_name" {
  description = "Target topic name"
  value       = confluent_kafka_topic.smt_target.topic_name
}

output "source_topic_id" {
  description = "Source topic ID"
  value       = confluent_kafka_topic.smt_source.id
}

output "target_topic_id" {
  description = "Target topic ID"
  value       = confluent_kafka_topic.smt_target.id
}

output "sink_connector_id" {
  description = "Verification Sink Connector ID"
  value       = var.enable_verification_sink ? confluent_connector.smt_verification_sink[0].id : null
}

output "sink_connector_status" {
  description = "Verification Sink Connector Status"
  value       = var.enable_verification_sink ? confluent_connector.smt_verification_sink[0].status : null
}
