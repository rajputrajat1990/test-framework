# Confluent Cloud Terraform Test Framework

A comprehensive test automation framework for testing Confluent Cloud infrastructure using Terraform. Provides automated validation of Kafka topics, RBAC, connectors, and end-to-end data flows with CI/CD integration.

## Features

- **Native Terraform Testing**: Uses `terraform test` with real resource deployment for integration testing
- **End-to-End Data Flow Testing**: Complete producer → connector → consumer validation
- **Multi-Format Data Support**: JSON, Avro, Protobuf, CSV, XML validation with Schema Registry integration
- **RBAC & Security Testing**: Comprehensive role-based access control and security validation
- **Connector Testing**: S3 source, PostgreSQL sink, and other connector integration tests
- **Performance Testing**: High-throughput testing with detailed metrics and benchmarking
- **CI/CD Integration**: GitLab pipeline templates with parallel execution
- **Consumer Groups Testing**: Multi-group consumption scenarios with partition management
- **Modular Architecture**: Easily extensible for new Confluent Cloud components
- **Configuration-Driven**: YAML-based module and environment configuration
- **Automated Cleanup**: Intelligent resource cleanup with failure recovery
- **Comprehensive Reporting**: JUnit XML reports, performance metrics, and detailed logs

## Testing Coverage

The framework provides three levels of testing:

1. **Unit Tests**: Configuration validation, syntax checking, and module verification
2. **Integration Tests**: Module deployment and resource validation against live Confluent Cloud
3. **End-to-End Tests**: Complete data flow validation with producer-connector-consumer scenarios

## Prerequisites

- Terraform >= 1.6.0
- Confluent Cloud account with required permissions
- API key and secret with necessary access

## Quick Start

Clone the repository and run the guided setup:

```bash
git clone <repository-url>
cd test-framework
./scripts/quick-start.sh
```

**Manual setup** (alternative):

```bash
# Set environment variables
export CONFLUENT_CLOUD_API_KEY=your-api-key
export CONFLUENT_CLOUD_API_SECRET=your-api-secret
export CONFLUENT_CLOUD_ENVIRONMENT_ID=env-xxxxx
export CONFLUENT_CLOUD_CLUSTER_ID=lkc-xxxxx

# Initialize framework
./scripts/setup.sh

# Load environment
source .env
```

## Usage

### Basic Module Testing

Test a specific module:

```bash
./scripts/test-runner.sh --env local --module kafka_topic
```

Run multiple modules with a test plan:

```bash
./scripts/test-runner.sh --env dev --plan basic
```

### End-to-End Testing

Run complete data flow tests:

```bash
# Basic data flow test
./scripts/run-e2e-tests.sh --test-type=basic-flow --env=dev

# Consumer groups test
./scripts/run-e2e-tests.sh --test-type=consumer-groups --env=dev --message-count=500

# Performance test
./scripts/run-e2e-tests.sh --test-type=performance --env=staging --message-count=1000
```

### Advanced Options

```bash
# Dry run to see what would be executed
./scripts/test-runner.sh --dry-run --plan basic --env local

# Run with cleanup disabled (for debugging)
./scripts/test-runner.sh --no-cleanup --env dev

# Clean up test resources manually
./scripts/cleanup-test-resources.sh --pipeline-id=12345
```

## Available Modules

| Module | Description | Requirements |
|--------|-------------|--------------|
| `kafka_topic` | Kafka topic creation and validation | None |
| `rbac_cluster_admin` | Cluster-level RBAC role bindings | None |
| `rbac_topic_access` | Topic-specific RBAC permissions | None |
| `s3_source_connector` | S3 source connector configuration | AWS credentials |
| `postgres_sink_connector` | PostgreSQL sink connector | PostgreSQL database |
| `e2e_basic_flow` | End-to-end data flow testing | None |
| `e2e_consumer_groups` | Consumer groups testing scenarios | None |
| `e2e_performance` | Performance and load testing | None |

### Test Plans

| Plan | Description | Modules Included |
|------|-------------|------------------|
| `basic` | Core Kafka and RBAC testing | kafka_topic, rbac_cluster_admin |
| `basic_e2e` | Basic end-to-end data flow | e2e_basic_flow |
| `consumer_groups_e2e` | Consumer group scenarios | e2e_consumer_groups |
| `performance_e2e` | Performance testing | e2e_performance |
| `full_e2e` | Complete E2E test suite | All E2E modules |
| `connector_integration` | Connector testing | All connector modules |

See `config/modules.yaml` for complete module definitions and `config/environments/` for environment configurations.

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

The pipeline automatically runs unit, integration, and end-to-end tests with parallel execution and comprehensive reporting.

## Project Structure

```
test-framework/
├── README.md
├── scripts/                    # Test runners and utilities
│   ├── quick-start.sh         # Interactive setup
│   ├── test-runner.sh         # Main test execution
│   ├── run-e2e-tests.sh       # End-to-end test orchestration
│   └── cleanup-test-resources.sh
├── terraform/                  # Terraform modules and tests
│   ├── modules/               # Individual test modules
│   └── tests/                 # Test configurations
├── config/                     # Configuration files
│   ├── modules.yaml           # Module definitions
│   └── environments/          # Environment configs
├── docs/                      # Documentation
├── test-results/              # Test outputs and reports
└── logs/                      # Execution logs
```

## Configuration

- **Modules**: Configure test modules in `config/modules.yaml`
- **Environments**: Environment-specific settings in `config/environments/`
- **Test Plans**: Define custom test plans for different scenarios

## Documentation

- [Architecture Guide](docs/architecture.md)
- [User Guide](docs/user-guide.md)
- [Comprehensive User Guide](docs/comprehensive-user-guide.md)

## Contributing

Contributions are welcome! Please open issues or pull requests for improvements.

## License

MIT
