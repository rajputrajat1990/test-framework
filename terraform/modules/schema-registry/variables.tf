variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

variable "region_id" {
  description = "Region ID for Schema Registry"
  type        = string
  default     = "sgreg-1"
}

variable "package_type" {
  description = "Schema Registry package type"
  type        = string
  default     = "ESSENTIALS"
  
  validation {
    condition     = contains(["ESSENTIALS", "ADVANCED"], var.package_type)
    error_message = "Package type must be either ESSENTIALS or ADVANCED."
  }
}

variable "subject_prefix" {
  description = "Prefix for schema subjects"
  type        = string
  default     = "test"
}

variable "service_account_id" {
  description = "Service Account ID for API key creation"
  type        = string
}

variable "sr_api_key" {
  description = "Schema Registry API Key"
  type        = string
  sensitive   = true
}

variable "sr_api_secret" {
  description = "Schema Registry API Secret"
  type        = string
  sensitive   = true
}

variable "enable_avro" {
  description = "Enable Avro schema creation"
  type        = bool
  default     = true
}

variable "enable_protobuf" {
  description = "Enable Protobuf schema creation"
  type        = bool
  default     = true
}

variable "enable_json_schema" {
  description = "Enable JSON schema creation"
  type        = bool
  default     = true
}
