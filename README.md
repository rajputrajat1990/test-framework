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

A test automation framework for Confluent Cloud infrastructure using Terraform tests, focused on CI/CD integration and end-to-end data flow validation.

## TL;DR
- Run the guided quick start: `./scripts/quick-start.sh`
- Run a single module test: `./scripts/test-runner.sh --env local --module kafka_topic`

## What this repo provides
- Reusable Terraform test modules for Confluent Cloud (topics, RBAC, connectors).
- End-to-end data flow tests (producer → connector → consumer).
- CI/CD-ready pipelines (GitLab) and reporting (JUnit XML, logs, metrics).

## Quick checklist
- [x] Clean quick-start and test-runner scripts
- [x] CI/CD pipeline templates for GitLab
- [x] Core test modules: `kafka_topic`, `rbac_*`, connectors

## Prerequisites
- Terraform >= 1.6.0
- Confluent Cloud account with appropriate permissions
- API key/secret with required access

## Quick Start
1. Clone the repository

```bash
git clone <repository-url>
cd test-framework
```

2. Run the interactive quick start (recommended for first time)

```bash
./scripts/quick-start.sh
```

3. Load environment variables (if not using quick start)

```bash
source .env
```

4. Run a single module test

```bash
./scripts/test-runner.sh --env local --module kafka_topic
```

For E2E runs, see `./scripts/run-e2e-tests.sh` (examples are in the `scripts/` folder).

## Available test modules (high level)
- `kafka_topic` — topic creation and validation
- `rbac_cluster_admin`, `rbac_topic_access` — RBAC role bindings and topic permissions
- `s3_source_connector`, `postgres_sink_connector` — connector integration tests (may require external credentials)
- `e2e_basic_flow`, `e2e_consumer_groups`, `e2e_performance` — end-to-end and performance tests

See `config/modules.yaml` for the full module configuration and `config/environments/` for environment-specific settings.

## CI/CD (GitLab)
Set required project variables in GitLab (example):

```
CONFLUENT_CLOUD_API_KEY
CONFLUENT_CLOUD_API_SECRET
CONFLUENT_ENVIRONMENT_ID
CONFLUENT_CLUSTER_ID
TEST_NOTIFICATION_WEBHOOK
TEST_S3_BUCKET
```

The repository includes a GitLab pipeline template (`.gitlab-ci.yml`) that runs unit, integration, and E2E stages.

## Project layout (short)

```
./
├── README.md
├── scripts/                # runners and helpers (test-runner, quick-start, e2e runners)
├── terraform/              # modules and terraform tests
├── config/                 # module & environment definitions
└── docs/                   # architecture and user guides
```

## Contributing
Contributions are welcome. Please open issues or PRs and follow the repo's contribution guidelines.

## License
MIT
