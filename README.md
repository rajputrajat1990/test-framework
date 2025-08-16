# Confluent Cloud Terraform Test Framework

A comprehensive test automation framework for Confluent Cloud infrastructure using Terraform's native test capabilities with full CI/CD integration and end-to-end data flow testing.

## 🚀 Sprint 3 - IN PROGRESS!

**Status**: 🔄 **Enhanced Features Sprint Implementation**

Sprint 3 is now under active development, implementing advanced data format validation, SMT transformation testing, and comprehensive RBAC/ACL security validation capabilities.

### 🎯 Sprint 3 New Capabilities
- **Multi-Format Data Validation**: JSON, Avro, Protobuf, CSV, XML with Schema Registry integration
- **SMT Transformation Testing**: Complete Single Message Transform validation framework
- **Enhanced Security Validation**: Comprehensive RBAC and ACL testing with compliance checks
- **Schema Evolution Testing**: Backward/forward compatibility validation
- **Performance Benchmarking**: High-throughput testing for all data formats and transformations
- **Security Compliance**: Automated security policy validation and reporting

### 🔧 Sprint 3 Technical Implementation
- **Schema Registry Module**: Full multi-format schema management and validation
- **SMT Connector Module**: Automated transformation testing with before/after validation
- **Enhanced Security Scripts**: Comprehensive RBAC/ACL testing with compliance reporting
- **Data Format Validation Framework**: Support for 5+ data formats with performance testing
- **Integration Test Suites**: Complete Terraform test coverage for all new features

## 🚀 Sprint 2 - COMPLETED!

**Status**: ✅ **Production Ready with CI/CD & E2E Testing**

This framework now provides complete end-to-end testing capabilities with GitLab CI/CD integration. Sprint 2 has successfully implemented:

### ✅ New Sprint 2 Capabilities
- **End-to-End Data Flow Testing**: Complete producer → connector → consumer validation
- **GitLab CI/CD Integration**: 6-stage pipeline with parallel execution
- **Consumer Groups Testing**: Multi-group consumption scenarios with partition management
- **Performance Benchmarking**: High-throughput testing with metrics collection
- **Data Integrity Validation**: Cross-pipeline data validation for JSON and Avro formats
- **Automated Notifications**: Multi-channel alerts (Slack, email, Teams)
- **Security Integration**: SAST scanning and secret detection
- **Resource Cleanup Automation**: Intelligent cleanup with failure recovery

### ✅ Sprint 1 Foundation (Still Available)
- **Kafka Topics**: Complete topic creation with configurable partitions and settings
- **RBAC (Role-Based Access Control)**: Role bindings for various principals and resources  
- **S3 Source Connector**: AWS S3 source connector with full configuration support
- **Modular Architecture**: Dynamic module loading with environment overrides
- **Resource Validation**: Comprehensive verification and API integration

## 🎯 Complete Testing Coverage

The framework now provides three levels of testing:

1. **Unit Tests**: Configuration validation, syntax checking, and module verification
2. **Integration Tests**: Module deployment and resource validation against live Confluent Cloud
3. **End-to-End Tests**: Complete data flow validation with producer-connector-consumer scenarios

## Features

- **Sprint 3 Enhanced Features**: Multi-format data validation, SMT transformation testing, and comprehensive security validation
- **Schema Registry Integration**: Complete schema management for Avro, Protobuf, and JSON with evolution testing
- **SMT Testing Framework**: Automated Single Message Transform validation with before/after comparison
- **Enhanced Security Validation**: Comprehensive RBAC/ACL testing with compliance reporting
- **Multi-Format Data Support**: JSON, Avro, Protobuf, CSV, XML validation with performance testing
- **Security Compliance Testing**: Automated policy validation and security scoring
- **Native Terraform Testing**: Uses `terraform test` with apply operations for integration testing
- **End-to-End Data Flow Testing**: Complete producer → connector → consumer validation
- **GitLab CI/CD Integration**: 6-stage automated pipeline with parallel execution
- **Consumer Groups Testing**: Multi-group consumption scenarios with partition management
- **Performance Benchmarking**: High-throughput testing with detailed metrics
- **Data Integrity Validation**: Cross-pipeline validation for JSON and Avro formats
- **Modular Architecture**: Easily extensible for new Confluent Cloud components
- **Security Integration**: SAST scanning, secret detection, and secure credential management
- **Multi-Channel Notifications**: Slack, email, and Teams integration for test results
- **Resource Validation**: Automated verification of created resources
- **Configuration-Driven**: YAML-based module and environment configuration
- **API Integration**: Cross-validates with Confluent Cloud Admin API
- **Parallel Execution**: Supports concurrent module and test execution
- **Automated Cleanup**: Intelligent resource cleanup with failure recovery
- **Comprehensive Reporting**: JUnit XML reports, performance metrics, and detailed logs

## Prerequisites

- Terraform >= 1.6.0
- Confluent Cloud account with admin access
- API key with necessary permissions

## ⚡ Quick Start

**New users**: Use the quick start script for guided setup!

```bash
# 1. Clone the repository
git clone <repository-url>
cd terraform-automation-framework


# Confluent Cloud Terraform Test Framework

## Overview
This project provides a developer-friendly automation framework for testing Confluent Cloud infrastructure using Terraform. It enables automated validation of Kafka topics, RBAC, connectors, and end-to-end data flows, with built-in CI/CD support and reporting.

## Features
- Modular Terraform test suites for Confluent Cloud resources (Kafka topics, RBAC, connectors)
- End-to-end data flow validation (producer → connector → consumer)
- Performance and integration testing
- Automated resource cleanup
- CI/CD pipeline templates (GitLab)
- JUnit XML reports, logs, and metrics
- YAML-based configuration for modules and environments

## Prerequisites
- Terraform >= 1.6.0
- Confluent Cloud account with required permissions
- API key and secret

## Getting Started
Clone the repository and run the quick start script:

```bash
git clone <repository-url>
cd test-framework
./scripts/quick-start.sh
```

Alternatively, set up environment variables manually:

```bash
export CONFLUENT_CLOUD_API_KEY=your-api-key
export CONFLUENT_CLOUD_API_SECRET=your-api-secret
export CONFLUENT_CLOUD_ENVIRONMENT_ID=env-xxxxx
export CONFLUENT_CLOUD_CLUSTER_ID=lkc-xxxxx
source .env
```

## Usage
Run a test for a specific module:

```bash
./scripts/test-runner.sh --env local --module kafka_topic
```

Run all end-to-end tests:

```bash
./scripts/run-e2e-tests.sh --test-type=basic-flow --env=dev
./scripts/run-e2e-tests.sh --test-type=consumer-groups --env=dev
./scripts/run-e2e-tests.sh --test-type=performance --env=staging
```

See `scripts/` for more runners and options.

## Available Modules
- `kafka_topic`: Kafka topic creation and validation
- `rbac_cluster_admin`, `rbac_topic_access`: RBAC role bindings and permissions
- `s3_source_connector`, `postgres_sink_connector`: Connector integration tests (external credentials may be required)
- `e2e_basic_flow`, `e2e_consumer_groups`, `e2e_performance`: End-to-end and performance tests

See `config/modules.yaml` for all modules and `config/environments/` for environment configs.

## CI/CD Integration
This repository includes a GitLab pipeline template (`.gitlab-ci.yml`) for automated testing. Set the following variables in your GitLab project:

```
CONFLUENT_CLOUD_API_KEY
CONFLUENT_CLOUD_API_SECRET
CONFLUENT_ENVIRONMENT_ID
CONFLUENT_CLUSTER_ID
TEST_NOTIFICATION_WEBHOOK
TEST_S3_BUCKET
```

## Project Structure
```
test-framework/
├── README.md
├── scripts/
├── terraform/
├── config/
├── docs/
├── test-results/
├── logs/
└── ...
```

## Documentation
- [Architecture Guide](docs/architecture.md)
- [User Guide](docs/user-guide.md)

## Contributing
Contributions are welcome! Please open issues or pull requests for improvements.

## License
MIT
