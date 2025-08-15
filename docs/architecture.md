# Architecture Guide

## Overview

The Confluent Cloud Terraform Test Framework is designed as a modular, scalable testing solution that leverages Terraform's native test capabilities with real resource provisioning (apply operations) to provide comprehensive integration testing for Confluent Cloud infrastructure.

## Core Architecture Principles

### 1. Modular Design
- **Separation of Concerns**: Each component type (topics, connectors, RBAC) has its own module
- **Reusability**: Modules can be used independently or combined
- **Extensibility**: New modules can be added without modifying core framework

### 2. Configuration-Driven
- **YAML Configuration**: Human-readable module and environment definitions
- **Parameter Injection**: Dynamic parameter substitution with environment variables
- **Environment Abstraction**: Different configurations for dev/staging/prod

### 3. Validation Framework
- **Resource Validation**: Automated verification of created resources
- **API Integration**: Cross-validation with Confluent Cloud APIs
- **Comprehensive Reporting**: Structured results with actionable feedback

## System Components

### Directory Structure

```
terraform-automation-framework/
├── terraform/
│   ├── shared/              # Shared provider configuration and utilities
│   ├── modules/             # Individual component test modules
│   │   ├── kafka-topic/     # Kafka topic creation and management
│   │   ├── s3-source-connector/  # S3 source connector configuration
│   │   ├── rbac/            # Role-based access control
│   │   └── [future modules] # Additional components
│   └── tests/               # Terraform test files (.tftest.hcl)
│       ├── integration/     # Integration tests
│       └── fixtures/        # Test data and fixtures
├── config/
│   ├── modules.yaml         # Module definitions and configurations
│   └── environments/        # Environment-specific overrides
├── scripts/                 # Automation and utility scripts
└── docs/                   # Documentation
```

### Core Components

#### 1. Shared Configuration (`terraform/shared/`)
- **Provider Setup**: Confluent Cloud provider configuration
- **Common Resources**: Random suffixes, time tracking
- **Variable Management**: Centralized variable definitions
- **Authentication**: Secure credential handling

#### 2. Module System (`terraform/modules/`)
Each module follows a standardized structure:

```hcl
# Standard module interface
terraform {
  required_providers {
    confluent = { ... }
  }
}

# Input variables with descriptions and defaults
variable "param_name" {
  description = "Parameter description"
  type        = string
  default     = "default_value"
}

# Resource creation
resource "confluent_resource" "main" {
  # Resource configuration
}

# Standard outputs
output "resource_id" { ... }
output "validation_data" {
  value = {
    resource_count = 1
    resource_type  = "confluent_resource_type"
    expected_properties = { ... }
    created_properties = { ... }
  }
}
```

#### 3. Configuration System (`config/`)

**Module Configuration (`modules.yaml`)**:
```yaml
modules:
  module_name:
    path: "./modules/module-directory"
    description: "Module description"
    parameters:
      param1: "${ENV_VAR}"
      param2: "static_value"
    validation:
      resource_count: 1
      resource_type: "confluent_resource"
    dependencies: []
    tags: ["category", "type"]
```

**Environment Configuration (`environments/env.yaml`)**:
```yaml
environment:
  name: "env_name"
confluent_cloud:
  environment_id: "env-xxxxx"
  cluster_id: "lkc-xxxxx"
module_overrides:
  module_name:
    parameters:
      param1: "environment_specific_value"
```

#### 4. Test Framework (`terraform/tests/`)
Uses Terraform's native test framework with `.tftest.hcl` files:

```hcl
run "test_name" {
  command = apply  # or plan

  module {
    source = "../../modules/module-name"
  }

  variables = {
    # Test-specific variables
  }

  # Assertions
  assert {
    condition     = output.expected_value == "actual_value"
    error_message = "Descriptive error message"
  }
}
```

## Data Flow

### 1. Test Execution Flow
```
1. Setup Script
   ├── Environment validation
   ├── Terraform initialization
   └── Connectivity testing

2. Test Runner
   ├── Configuration parsing
   ├── Module selection
   ├── Dependency resolution
   └── Execution orchestration

3. Module Execution
   ├── Parameter injection
   ├── Resource provisioning
   ├── Validation checks
   └── Cleanup (optional)

4. Result Aggregation
   ├── Success/failure tracking
   ├── Detailed reporting
   └── Log consolidation
```

### 2. Configuration Resolution
```
1. Base Configuration (modules.yaml)
2. Environment Overrides (environments/env.yaml)
3. Runtime Parameters (CLI arguments)
4. Environment Variables (substitution)
5. Final Module Configuration
```

### 3. Validation Pipeline
```
1. Resource Creation Validation
   ├── Count verification
   ├── Property validation
   └── Relationship checks

2. API Cross-Validation
   ├── Confluent Cloud API calls
   ├── Resource state verification
   └── Status monitoring

3. Result Compilation
   ├── Pass/fail determination
   ├── Error categorization
   └── Actionable feedback
```

## Module Development Standards

### Module Interface Contract

Each module must implement:

1. **Standard Variables**:
   - `environment_id` (string, required)
   - Component-specific parameters

2. **Standard Outputs**:
   - `validation_data` (object, required)
   - Resource identifiers
   - Configuration details

3. **Validation Data Structure**:
```hcl
output "validation_data" {
  value = {
    resource_count = number
    resource_type  = "confluent_resource_type"
    expected_properties = {
      # Expected configuration
    }
    created_properties = {
      # Actual resource properties
    }
    api_verification = {
      # API validation requirements
    }
  }
}
```

### Module Categories

#### Core Infrastructure Modules
- **Kafka Topics**: Topic creation, configuration, partition management
- **Schema Registry**: Schema management and evolution
- **RBAC**: Role-based access control and permissions

#### Connector Modules
- **Source Connectors**: Data ingestion (S3, Database, etc.)
- **Sink Connectors**: Data export (S3, Database, etc.)
- **Transform Connectors**: Stream processing connectors

#### Advanced Modules
- **ksqlDB**: Stream processing applications
- **Kafka Streams**: Stream processing topologies
- **Multi-Region**: Cross-region replication and failover

## Integration Points

### 1. Confluent Cloud APIs
- **Admin API**: Resource management and validation
- **Metrics API**: Performance and health monitoring
- **Audit API**: Security and compliance tracking

### 2. External Systems
- **AWS Services**: S3, RDS for connector testing
- **Azure Services**: Blob Storage, SQL Database
- **GCP Services**: Cloud Storage, BigQuery

### 3. CI/CD Integration
- **GitHub Actions**: Automated testing workflows
- **Jenkins**: Enterprise CI/CD pipelines
- **GitLab CI**: Integrated DevOps workflows

## Scalability Considerations

### 1. Parallel Execution
- **Independent Modules**: Run modules without dependencies in parallel
- **Resource Isolation**: Prevent resource naming conflicts
- **Batch Processing**: Group related operations

### 2. Resource Management
- **Naming Conventions**: Unique resource names with prefixes/suffixes
- **Cleanup Strategies**: Automatic resource cleanup after tests
- **Resource Limits**: Environment-specific resource constraints

### 3. Performance Optimization
- **Terraform State**: Isolated state files per module
- **Provider Caching**: Reuse provider connections
- **Selective Execution**: Run only modified modules

## Security Architecture

### 1. Credential Management
- **Environment Variables**: Secure credential injection
- **No Hardcoding**: No credentials in configuration files
- **Principle of Least Privilege**: Minimal required permissions

### 2. Network Security
- **VPC Isolation**: Network isolation where applicable
- **Private Endpoints**: Use private connectivity options
- **Audit Logging**: Comprehensive activity logging

### 3. Data Protection
- **Sensitive Variables**: Terraform sensitive variable handling
- **Encryption**: Data encryption in transit and at rest
- **Access Controls**: Role-based access to test environments

## Extension Points

### 1. Custom Modules
- **Module Template**: Standardized module structure
- **Validation Framework**: Pluggable validation system
- **Configuration Schema**: Extensible parameter system

### 2. Reporting Extensions
- **Custom Validators**: Domain-specific validation logic
- **Report Formats**: JSON, XML, HTML output formats
- **Integrations**: Slack, email, dashboard notifications

### 3. Environment Adapters
- **Cloud Providers**: Multi-cloud support
- **On-Premises**: Confluent Platform compatibility
- **Hybrid**: Mixed environment scenarios

This architecture provides a solid foundation for comprehensive Confluent Cloud testing while maintaining flexibility for future enhancements and integrations.
