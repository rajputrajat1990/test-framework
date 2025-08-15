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

# 2. Run interactive quick start (recommended for first time)
./scripts/quick-start.sh

# 3. Load environment variables
source .env

# 4. Run your first test
./scripts/test-runner.sh --env local --module kafka_topic
```

### Sprint 2: CI/CD Pipeline Setup

For GitLab CI/CD integration:

```bash
# 1. Set up GitLab CI variables (in GitLab project settings):
CONFLUENT_CLOUD_API_KEY=your-api-key
CONFLUENT_CLOUD_API_SECRET=your-api-secret
CONFLUENT_ENVIRONMENT_ID=env-xxxxx
CONFLUENT_CLUSTER_ID=lkc-xxxxx
TEST_NOTIFICATION_WEBHOOK=https://hooks.slack.com/...
TEST_S3_BUCKET=your-test-bucket
TEST_DATABASE_URL=postgresql://...

# 2. Pipeline will run automatically on commits
# View results in GitLab CI/CD > Pipelines
```

### Sprint 2: End-to-End Testing

Run complete data flow tests locally:

```bash
# Basic data flow test
./scripts/run-e2e-tests.sh --test-type=basic-flow --env=dev

# Consumer groups test
./scripts/run-e2e-tests.sh --test-type=consumer-groups --env=dev --message-count=500

# Performance test
./scripts/run-e2e-tests.sh --test-type=performance --env=staging --message-count=1000

# All E2E tests
./scripts/run-e2e-tests.sh --test-type=basic-flow --env=dev && \
./scripts/run-e2e-tests.sh --test-type=consumer-groups --env=dev && \
./scripts/run-e2e-tests.sh --test-type=performance --env=dev
```

### Manual Setup (Alternative)

If you prefer manual configuration:

1. **Setup Environment Variables**:
```bash
export CONFLUENT_CLOUD_API_KEY=your-api-key
export CONFLUENT_CLOUD_API_SECRET=your-api-secret
export CONFLUENT_CLOUD_ENVIRONMENT_ID=env-xxxxx
export CONFLUENT_CLOUD_CLUSTER_ID=lkc-xxxxx
export TEST_EXECUTION_MODE=apply
```

2. **Initialize Framework**:
```bash
./scripts/setup.sh
```

3. **Run Tests**:
```bash
# Basic tests (Kafka topics + RBAC)
./scripts/test-runner.sh --env local --plan basic

# Test specific module
./scripts/test-runner.sh --module kafka_topic --env dev

# Dry run to see what would be executed
./scripts/test-runner.sh --dry-run --plan basic --env local

# Run with cleanup disabled (for debugging)
./scripts/test-runner.sh --no-cleanup --env dev

# Clean up test resources manually
./scripts/cleanup-test-resources.sh --pipeline-id=12345
```

## 📚 Available Test Modules

### ✅ Production Ready Modules

| Module | Description | Status | Sprint |
|--------|-------------|--------|---------|
| `kafka_topic` | Kafka topic creation with configurable partitions | ✅ Ready | 1 |
| `rbac_cluster_admin` | Cluster-level RBAC role bindings | ✅ Ready | 1 |  
| `rbac_topic_access` | Topic-specific RBAC permissions | ✅ Ready | 1 |
| `s3_source_connector` | S3 source connector configuration | ✅ Ready | 1* |
| `e2e_basic_flow` | End-to-end data flow testing | ✅ Ready | 2 |
| `e2e_consumer_groups` | Consumer groups testing scenarios | ✅ Ready | 2 |
| `e2e_performance` | Performance and load testing | ✅ Ready | 2 |
| `postgres_sink_connector` | PostgreSQL sink connector | ✅ Ready | 2* |

*Requires external service credentials

### 🎯 Available Test Plans

| Plan | Description | Modules Included |
|------|-------------|------------------|
| `basic` | Core Kafka and RBAC testing | kafka_topic, rbac_cluster_admin |
| `basic_e2e` | Basic end-to-end data flow | e2e_basic_flow |
| `consumer_groups_e2e` | Consumer group scenarios | e2e_consumer_groups |
| `performance_e2e` | Performance testing | e2e_performance |
| `full_e2e` | Complete E2E test suite | All E2E modules |
| `connector_integration` | Connector testing | All connector modules |

### 🔄 Planned Modules (Sprint 3+)
- Schema Registry schemas with evolution testing
- ksqlDB applications and queries
- Multi-region cluster setups
- Advanced connector types (MongoDB, Elasticsearch)

## Project Structure

```
terraform-automation-framework/
├── README.md
├── .gitignore
├── .gitlab-ci.yml                # Sprint 2: CI/CD Pipeline
├── SPRINT1-STATUS.md             # Sprint 1 completion status
├── SPRINT2-STATUS.md             # Sprint 2 completion status
├── terraform/
│   ├── modules/                  # Test modules for different components
│   │   ├── kafka-topic/
│   │   ├── s3-source-connector/
│   │   ├── postgres-sink-connector/  # Sprint 2: New sink connector
│   │   └── rbac/
│   ├── tests/                   # Terraform test files
│   │   ├── integration/
│   │   ├── e2e/                 # Sprint 2: End-to-end test configs
│   │   │   ├── basic-flow.tftest.hcl
│   │   │   └── consumer-groups.tftest.hcl
│   │   └── fixtures/
│   └── shared/                  # Shared configurations
├── config/
│   ├── modules.yaml             # Module definitions (enhanced for Sprint 2)
│   └── environments/            # Environment-specific configs
│       ├── dev.yaml            # Enhanced with E2E config
│       ├── staging.yaml        # Enhanced with E2E config
│       └── local.yaml.example
├── scripts/
│   ├── setup.sh
│   ├── test-runner.sh
│   ├── quick-start.sh
│   ├── run-e2e-tests.sh        # Sprint 2: E2E test orchestration
│   ├── run-unit-tests.sh       # Sprint 2: Unit test automation
│   ├── run-integration-tests.sh # Sprint 2: Integration test runner
│   ├── cleanup-test-resources.sh # Sprint 2: Resource cleanup
│   └── send-notifications.sh    # Sprint 2: Multi-channel notifications
├── test-results/                # Sprint 2: Test outputs and reports
├── test-data/                   # Sprint 2: Generated test data
├── logs/                        # Sprint 2: Execution logs
└── docs/
    ├── architecture.md
    └── user-guide.md
```

## Configuration

See `config/modules.yaml` for module definitions and `config/environments/` for environment-specific settings.

## Documentation

- [Architecture Guide](docs/architecture.md)
- [User Guide](docs/user-guide.md)
- [Module Development](docs/module-development.md)

## Contributing

Please read our contribution guidelines and submit pull requests for any improvements.

## License

This project is licensed under the MIT License.
