# Enterprise Security Module Variables

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

# Access Control Configuration
variable "connector_accessible_topics" {
  description = "Topics that connector operator can access"
  type        = set(string)
  default     = []
}

variable "consumer_accessible_topics" {
  description = "Topics that data consumer can read"
  type        = set(string)
  default     = []
}

# Vault Integration
variable "vault_config" {
  description = "HashiCorp Vault configuration for secret management"
  type = object({
    enabled     = optional(bool, false)
    address     = optional(string, "")
    secret_path = optional(string, "confluent/secrets")
    auth_method = optional(string, "token")
    token       = optional(string, "")
    
    # Vault policies
    admin_policy         = optional(string, "confluent-admin")
    operator_policy      = optional(string, "confluent-operator")
    readonly_policy      = optional(string, "confluent-readonly")
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security policies and configuration"
  type = object({
    # Credential management
    credential_rotation_days = optional(number, 30)
    enable_automatic_rotation = optional(bool, true)
    
    # Audit and logging
    audit_retention_ms         = optional(number, 2592000000)    # 30 days
    access_events_retention_ms = optional(number, 604800000)     # 7 days
    
    # Security scanning
    enable_vulnerability_scanning = optional(bool, true)
    scan_frequency_hours         = optional(number, 24)
    
    # Access control
    enforce_mfa                  = optional(bool, false)
    session_timeout_minutes      = optional(number, 480)         # 8 hours
    max_concurrent_sessions      = optional(number, 3)
    
    # IP restrictions
    enable_ip_whitelist          = optional(bool, false)
    allowed_ip_ranges           = optional(list(string), [])
    
    # Encryption
    require_tls                 = optional(bool, true)
    min_tls_version            = optional(string, "1.2")
  })
  default = {}
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance standards and validation configuration"
  type = object({
    # Compliance standards
    standards = optional(list(string), ["SOC2", "GDPR"])
    
    # Validation settings
    enable_validation      = optional(bool, true)
    validation_frequency   = optional(string, "daily")
    report_retention_ms    = optional(number, 31536000000)  # 365 days
    
    # SOC 2 Type II requirements
    soc2_controls = optional(object({
      enable_change_management = optional(bool, true)
      enable_access_reviews   = optional(bool, true)
      enable_data_encryption  = optional(bool, true)
      enable_backup_testing   = optional(bool, true)
    }), {})
    
    # GDPR requirements
    gdpr_controls = optional(object({
      enable_data_retention_policy  = optional(bool, true)
      enable_right_to_be_forgotten = optional(bool, true)
      enable_data_portability      = optional(bool, true)
      enable_consent_management    = optional(bool, true)
      data_retention_days          = optional(number, 30)
    }), {})
    
    # HIPAA requirements (if applicable)
    hipaa_controls = optional(object({
      enable_phi_encryption    = optional(bool, false)
      enable_access_logging    = optional(bool, false)
      enable_audit_trail      = optional(bool, false)
      phi_retention_years     = optional(number, 6)
    }), {})
  })
  default = {}
}

# RBAC Testing Configuration
variable "rbac_test_config" {
  description = "RBAC testing and validation configuration"
  type = object({
    # Test scenarios
    enable_privilege_escalation_tests = optional(bool, true)
    enable_cross_environment_tests    = optional(bool, true)
    enable_unauthorized_access_tests  = optional(bool, true)
    
    # Test users for validation
    test_users = optional(list(object({
      name           = string
      expected_roles = list(string)
      test_scenarios = list(string)
    })), [])
    
    # Negative testing
    enable_negative_testing = optional(bool, true)
    negative_test_scenarios = optional(list(string), [
      "unauthorized_topic_access",
      "privilege_escalation_attempt",
      "cross_cluster_access_attempt"
    ])
  })
  default = {}
}

# Audit Configuration
variable "audit_config" {
  description = "Audit logging and monitoring configuration"
  type = object({
    # Audit events to capture
    capture_authentication_events = optional(bool, true)
    capture_authorization_events  = optional(bool, true)
    capture_data_access_events    = optional(bool, true)
    capture_configuration_changes = optional(bool, true)
    capture_admin_actions         = optional(bool, true)
    
    # Audit storage
    audit_topic_partitions     = optional(number, 3)
    audit_topic_replication    = optional(number, 3)
    audit_log_format          = optional(string, "json")
    
    # Compliance reporting
    generate_compliance_reports = optional(bool, true)
    report_frequency           = optional(string, "weekly")
    report_recipients          = optional(list(string), [])
    
    # Tamper protection
    enable_log_integrity_checks = optional(bool, true)
    enable_log_encryption      = optional(bool, true)
  })
  default = {}
}

# Secret Scanning Configuration
variable "secret_scanning_config" {
  description = "Secret scanning and detection configuration"
  type = object({
    enabled                = optional(bool, true)
    scan_frequency_hours   = optional(number, 6)
    
    # Patterns to detect
    detect_api_keys       = optional(bool, true)
    detect_passwords      = optional(bool, true)
    detect_private_keys   = optional(bool, true)
    detect_tokens         = optional(bool, true)
    
    # Custom patterns
    custom_patterns = optional(list(object({
      name        = string
      pattern     = string
      description = string
    })), [])
    
    # Actions on detection
    alert_on_detection    = optional(bool, true)
    block_on_detection    = optional(bool, false)
    quarantine_secrets    = optional(bool, true)
  })
  default = {}
}

# Penetration Testing Configuration
variable "penetration_testing_config" {
  description = "Automated penetration testing configuration"
  type = object({
    enabled                  = optional(bool, false)  # Disabled by default
    frequency_days          = optional(number, 30)
    
    # Test categories
    enable_authentication_tests = optional(bool, true)
    enable_authorization_tests  = optional(bool, true)
    enable_injection_tests      = optional(bool, true)
    enable_dos_tests           = optional(bool, false)  # Be careful with DoS tests
    
    # Safety limits
    max_concurrent_tests    = optional(number, 1)
    test_timeout_minutes    = optional(number, 30)
    
    # Notification on findings
    alert_on_vulnerabilities = optional(bool, true)
    severity_threshold      = optional(string, "medium")
  })
  default = {}
}

# Data Classification Configuration
variable "data_classification_config" {
  description = "Data classification and handling configuration"
  type = object({
    enabled = optional(bool, true)
    
    # Classification levels
    classification_levels = optional(list(string), [
      "public", "internal", "confidential", "restricted"
    ])
    
    # Default classifications
    default_topic_classification = optional(string, "internal")
    
    # Handling requirements by classification
    handling_requirements = optional(map(object({
      encryption_required     = bool
      access_logging_required = bool
      retention_days         = number
      allowed_regions        = list(string)
    })), {})
  })
  default = {}
}
