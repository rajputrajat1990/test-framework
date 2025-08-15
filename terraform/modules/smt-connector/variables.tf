variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "cluster_id" {
  description = "Kafka Cluster ID"
  type        = string
}

variable "kafka_rest_endpoint" {
  description = "Kafka REST Endpoint"
  type        = string
}

variable "kafka_api_key" {
  description = "Kafka API Key"
  type        = string
  sensitive   = true
}

variable "kafka_api_secret" {
  description = "Kafka API Secret"
  type        = string
  sensitive   = true
}

variable "connector_name" {
  description = "Name of the SMT test connector"
  type        = string
}

variable "partitions" {
  description = "Number of partitions for test topics"
  type        = number
  default     = 3
}

variable "output_data_format" {
  description = "Output data format for the connector"
  type        = string
  default     = "JSON"
  
  validation {
    condition     = contains(["JSON", "AVRO", "PROTOBUF"], var.output_data_format)
    error_message = "Output data format must be JSON, AVRO, or PROTOBUF."
  }
}

variable "max_iterations" {
  description = "Maximum number of iterations for data generation"
  type        = number
  default     = 100
}

variable "enable_verification_sink" {
  description = "Enable verification sink connector"
  type        = bool
  default     = true
}

variable "value_converter" {
  description = "Value converter for sink connector"
  type        = string
  default     = "org.apache.kafka.connect.json.JsonConverter"
}

variable "key_converter" {
  description = "Key converter for sink connector"
  type        = string
  default     = "org.apache.kafka.connect.storage.StringConverter"
}

variable "smt_transformations" {
  description = "SMT transformation configurations"
  type        = map(string)
  default     = {}
}
