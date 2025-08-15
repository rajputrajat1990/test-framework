# Confluent Cloud Test Framework - Comprehensive User Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation & Setup](#installation--setup)
4. [Basic Usage](#basic-usage)
5. [Sprint-Specific Testing](#sprint-specific-testing)
6. [Continuous Testing](#continuous-testing)
7. [Advanced Configuration](#advanced-configuration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Overview

The Confluent Cloud Test Framework is a comprehensive testing solution for infrastructure as code (IaC) using Terraform. It provides automated testing capabilities across multiple sprints, each adding enhanced features and capabilities.

### Framework Architecture
- **Modular Design**: Test modules for different Confluent Cloud components
- **Multi-Environment Support**: Dev, staging, and production environments
- **Automated Testing**: Unit, integration, and end-to-end test suites
- **Continuous Integration**: GitLab CI/CD integration with parallel execution
- **Comprehensive Reporting**: HTML reports, metrics, and notifications

## Prerequisites

### System Requirements
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Terraform**: >= 1.6.0
- **Shell**: Bash >= 4.0
- **Memory**: Minimum 4GB RAM for full test execution
- **Disk Space**: 2GB free space for test artifacts

### Required Tools
The following tools will be automatically installed by the setup script:
- `jq` - JSON processing
- `curl` - HTTP requests
- `yq` - YAML processing
- `bc` - Calculations

### Confluent Cloud Requirements
- **Account**: Active Confluent Cloud account with admin access
- **Environment**: Configured environment with Kafka cluster
- **API Keys**: Cloud API key and Kafka API key with appropriate permissions
- **Service Account**: For RBAC testing (optional but recommended)

### External Service Requirements (Optional)
- **AWS Account**: For S3 connector testing
- **Database**: PostgreSQL for sink connector testing
- **Monitoring**: Sumo Logic for monitoring integration (Sprint 5)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Test-framework
```

### 2. Quick Start Setup (Recommended)
The framework includes an interactive quick start script:

```bash
./scripts/quick-start.sh
```

This script will:
- Check system prerequisites
- Prompt for Confluent Cloud credentials
- Configure environment variables
- Set up initial configuration files
- Validate the setup

### 3. Manual Setup (Alternative)

If you prefer manual configuration:

#### 3.1 Set Environment Variables
Create a `.env` file or export variables:

```bash
# Required Confluent Cloud Configuration
export CONFLUENT_CLOUD_API_KEY="your-cloud-api-key"
export CONFLUENT_CLOUD_API_SECRET="your-cloud-api-secret"
export CONFLUENT_ENVIRONMENT_ID="env-xxxxx"
export CONFLUENT_CLUSTER_ID="lkc-xxxxx"

# Kafka API Keys (for topic operations)
export CONFLUENT_KAFKA_API_KEY="your-kafka-api-key"
export CONFLUENT_KAFKA_API_SECRET="your-kafka-api-secret"

# Test Configuration
export TEST_EXECUTION_MODE="apply"  # or "plan" for dry-run
export TEST_SERVICE_ACCOUNT="User:test-user@example.com"

# Optional External Services
export TEST_S3_BUCKET="your-test-bucket"
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export TEST_DATABASE_URL="postgresql://user:pass@host:5432/db"
```

#### 3.2 Run Setup Script
```bash
./scripts/setup.sh
```

#### 3.3 Load Environment
```bash
source .env
```

### 4. Verify Installation
```bash
# Run a basic validation test
./scripts/test-runner.sh --dry-run --env local --module kafka_topic
```

## Basic Usage

### Test Runner Command
The main test runner script provides flexible execution options:

```bash
./scripts/test-runner.sh [OPTIONS]
```

#### Common Options
- `-e, --env ENVIRONMENT`: Environment (dev, staging, prod)
- `-m, --module MODULE`: Run specific module only
- `-p, --plan PLAN`: Execution plan (basic, full, security)
- `--dry-run`: Show what would be executed without running
- `--no-cleanup`: Skip cleanup after tests
- `--parallel`: Run modules in parallel
- `-v, --verbose`: Verbose output

#### Basic Examples

```bash
# Run basic tests in dev environment
./scripts/test-runner.sh --env dev --plan basic

# Test specific module
./scripts/test-runner.sh --module kafka_topic --env dev

# Dry run to preview execution
./scripts/test-runner.sh --dry-run --plan basic --env local

# Run with verbose output and no cleanup
./scripts/test-runner.sh --verbose --no-cleanup --env dev
```

### Available Test Plans

| Plan | Description | Modules Included | Duration |
|------|-------------|------------------|----------|
| `basic` | Core Kafka and RBAC testing | kafka_topic, rbac_cluster_admin | 5-10 min |
| `full` | Complete module testing | All available modules | 20-30 min |
| `security` | Security-focused testing | RBAC, ACL, security modules | 10-15 min |
| `connectors` | Connector testing | S3 source, PostgreSQL sink | 15-20 min |
| `e2e` | End-to-end data flow | Producer → Connector → Consumer | 10-15 min |
| `performance` | Performance and load testing | High-throughput scenarios | 15-30 min |

### Available Test Modules

#### Sprint 1 Modules (Core Infrastructure)
- `kafka_topic` - Kafka topic creation and configuration
- `rbac_cluster_admin` - Cluster-level RBAC role bindings
- `rbac_topic_access` - Topic-specific RBAC permissions
- `s3_source_connector` - S3 source connector configuration

#### Sprint 2 Modules (CI/CD & E2E Testing)
- `e2e_basic_flow` - End-to-end data flow testing
- `e2e_consumer_groups` - Consumer groups testing scenarios
- `e2e_performance` - Performance and load testing
- `postgres_sink_connector` - PostgreSQL sink connector

#### Sprint 3 Modules (Enhanced Features)
- `schema_registry` - Schema management and evolution
- `smt_connector` - Single Message Transform testing
- `enhanced_security` - Comprehensive security validation

#### Sprint 4 Modules (Continuous Testing & Flink)
- `flink_job` - Apache Flink job deployment and testing
- `flink_testing` - Flink SQL transformations
- `compute_pool` - Compute pool management

#### Sprint 5 Modules (Observability & Production)
- `monitoring` - Monitoring integration (Sumo Logic)
- `enterprise_security` - Enterprise security compliance
- `production_deployment` - Production deployment automation

## Sprint-Specific Testing

Each sprint builds upon previous functionality while adding new capabilities. Here's how to run tests for each sprint:

### Sprint 1: Foundation Testing

Sprint 1 established the core framework with basic Kafka and RBAC testing.

```bash
# Run all Sprint 1 tests
./scripts/test-runner.sh --env dev --plan basic

# Test individual Sprint 1 modules
./scripts/test-runner.sh --module kafka_topic --env dev
./scripts/test-runner.sh --module rbac_cluster_admin --env dev
./scripts/test-runner.sh --module s3_source_connector --env dev

# Sprint 1 validation
if [ -f "./scripts/validate-sprint1.sh" ]; then
    ./scripts/validate-sprint1.sh
fi
```

### Sprint 2: CI/CD & End-to-End Testing

Sprint 2 added GitLab CI/CD integration and comprehensive E2E testing.

```bash
# Run Sprint 2 E2E tests
./scripts/run-e2e-tests.sh --test-type=basic-flow --env=dev

# Consumer groups testing
./scripts/run-e2e-tests.sh --test-type=consumer-groups --env=dev --message-count=500

# Performance testing
./scripts/run-e2e-tests.sh --test-type=performance --env=dev --message-count=1000

# Run all E2E tests
./scripts/run-e2e-tests.sh --test-type=all --env=dev

# Integration tests
./scripts/run-integration-tests.sh --env dev

# Unit tests
./scripts/run-unit-tests.sh
```

### Sprint 3: Enhanced Features

Sprint 3 introduced multi-format data validation, SMT transformations, and enhanced security.

```bash
# Run complete Sprint 3 test suite
./scripts/run-sprint3.sh comprehensive all

# Run specific Sprint 3 phases
./scripts/run-sprint3.sh basic data_validation    # Data format validation
./scripts/run-sprint3.sh basic smt_testing       # SMT transformations
./scripts/run-sprint3.sh basic security_validation # Security testing

# Data format validation (specific formats)
./scripts/data-validation/validate-formats.sh json basic
./scripts/data-validation/validate-formats.sh avro comprehensive
./scripts/data-validation/validate-formats.sh all performance

# SMT transformation testing
./scripts/test-smt-transformations.sh field_renaming basic
./scripts/test-smt-transformations.sh all comprehensive

# Enhanced security validation
./scripts/validate-security.sh all comprehensive
```

**Sprint 3 Test Phases:**
1. **Data Format Validation** - JSON, Avro, Protobuf, CSV, XML
2. **SMT Transformation Testing** - Field operations, type conversions, chaining
3. **Enhanced Security Validation** - RBAC, ACL, compliance testing
4. **Integration Testing** - Full Terraform integration
5. **Performance Testing** - High-throughput validation

### Sprint 4: Continuous Testing & Apache Flink

Sprint 4 added continuous testing capabilities and Apache Flink integration.

```bash
# Continuous testing orchestration
./continuous-testing/scripts/continuous-testing.sh run --mode=comprehensive

# Specific continuous testing commands
./continuous-testing/scripts/continuous-testing.sh analyze-changes
./continuous-testing/scripts/continuous-testing.sh select-tests
./continuous-testing/scripts/continuous-testing.sh execute-tests

# Flink-specific testing
terraform test -chdir=terraform/tests/flink

# Code change analysis and test selection
./continuous-testing/scripts/analyze-code-changes.sh
./continuous-testing/scripts/select-tests.sh --changes="terraform/modules/flink-job"
```

**Sprint 4 Capabilities:**
- **Change Detection**: Monitors file changes and selects relevant tests
- **Test Selection**: Intelligent test selection based on code changes
- **Flink Integration**: Apache Flink job testing and SQL transformations
- **Quality Gates**: Automated quality gate validation
- **Parallel Execution**: Optimized parallel test execution

### Sprint 5: Observability & Production Readiness

Sprint 5 delivers enterprise-grade observability and production deployment capabilities.

```bash
# Complete Sprint 5 validation
./scripts/validate-sprint5.sh

# Monitoring integration testing
./scripts/alert-management.sh --test-mode

# Production deployment testing
terraform test -chdir=terraform/modules/production-deployment

# Enterprise security testing
terraform test -chdir=terraform/modules/enterprise-security

# Advanced reporting
python3 scripts/test-reporting.py --generate-analytics --format=html
```

**Sprint 5 Features:**
- **Monitoring Integration**: Sumo Logic connectors, dashboards, alerts
- **Advanced Reporting**: Analytics, trend analysis, flaky test detection
- **Enterprise Security**: Comprehensive RBAC, compliance validation
- **Production Deployment**: Multi-environment, blue-green deployment
- **Observability**: Real-time monitoring and alerting

### Post-Sprint Testing Workflow

After each sprint completion, run this comprehensive validation:

```bash
#!/bin/bash
# Post-Sprint Validation Script

SPRINT=${1:-current}
ENVIRONMENT=${2:-dev}

echo "🚀 Running post-Sprint $SPRINT validation in $ENVIRONMENT environment"

# 1. Run current sprint-specific tests
case $SPRINT in
    1)
        ./scripts/test-runner.sh --env $ENVIRONMENT --plan basic
        ;;
    2)
        ./scripts/run-e2e-tests.sh --test-type=all --env=$ENVIRONMENT
        ;;
    3)
        ./scripts/run-sprint3.sh comprehensive all
        ;;
    4)
        ./continuous-testing/scripts/continuous-testing.sh run --mode=comprehensive
        ;;
    5)
        ./scripts/validate-sprint5.sh
        ;;
esac

# 2. Regression testing - run all previous sprint capabilities
echo "🔄 Running regression tests..."
./scripts/test-runner.sh --env $ENVIRONMENT --plan full

# 3. Performance validation
echo "⚡ Running performance validation..."
./scripts/run-e2e-tests.sh --test-type=performance --env=$ENVIRONMENT

# 4. Security validation
echo "🔒 Running security validation..."
if [ -f "./scripts/validate-security.sh" ]; then
    ./scripts/validate-security.sh all comprehensive
fi

# 5. Generate comprehensive report
echo "📊 Generating comprehensive test report..."
if [ -f "./scripts/test-reporting.py" ]; then
    python3 scripts/test-reporting.py --sprint=$SPRINT --environment=$ENVIRONMENT
fi

echo "✅ Post-Sprint $SPRINT validation completed"
```

## Continuous Testing

Sprint 4 introduced continuous testing capabilities that automatically run tests based on code changes.

### Continuous Testing Commands

```bash
# Start continuous testing mode
./continuous-testing/scripts/continuous-testing.sh run --mode=watch

# Analyze recent changes
./continuous-testing/scripts/analyze-code-changes.sh --since="1 hour ago"

# Select and run tests for specific changes
./continuous-testing/scripts/select-tests.sh --changes="terraform/modules/kafka-topic"
./continuous-testing/scripts/execute-test-suite.sh --suite=terraform_validation

# Generate continuous testing report
./continuous-testing/scripts/generate-test-report.sh --format=html
```

### CI/CD Integration

The framework integrates with GitLab CI/CD pipelines:

#### GitLab CI Variables Required
Set these in your GitLab project settings:
```bash
CONFLUENT_CLOUD_API_KEY=your-api-key
CONFLUENT_CLOUD_API_SECRET=your-api-secret
CONFLUENT_ENVIRONMENT_ID=env-xxxxx
CONFLUENT_CLUSTER_ID=lkc-xxxxx
TEST_NOTIFICATION_WEBHOOK=https://hooks.slack.com/...
TEST_S3_BUCKET=your-test-bucket
TEST_DATABASE_URL=postgresql://...
```

#### Pipeline Stages
1. **Validation**: Terraform validation and linting
2. **Unit Tests**: Module unit testing
3. **Integration Tests**: Live resource testing
4. **E2E Tests**: End-to-end data flow testing
5. **Security Tests**: RBAC and security validation
6. **Reporting**: Test results and notifications

## Advanced Configuration

### Environment Configuration

Customize environments in `config/environments/`:

```yaml
# config/environments/dev.yaml
environment:
  name: "dev"
  confluent:
    environment_id: "env-xxxxx"
    cluster_id: "lkc-xxxxx"
  
  test_configuration:
    execution_mode: "apply"
    cleanup_enabled: true
    parallel_execution: true
    timeout_minutes: 30
    
  module_overrides:
    kafka_topic:
      partitions: 3
      replication_factor: 3
    
  notifications:
    slack_webhook: "https://hooks.slack.com/..."
    email_recipients: ["team@company.com"]
```

### Module Configuration

Customize modules in `config/modules.yaml`:

```yaml
modules:
  kafka_topic:
    enabled: true
    path: "terraform/modules/kafka-topic"
    dependencies: []
    execution_order: 1
    sprint: 1
    tags: ["core", "kafka"]
    
  enhanced_security:
    enabled: true
    path: "terraform/modules/enhanced-security"
    dependencies: ["kafka_topic"]
    execution_order: 10
    sprint: 3
    tags: ["security", "rbac"]
```

### Quality Gates Configuration

Configure quality gates in `continuous-testing/config/quality-gates.yaml`:

```yaml
quality_gates:
  minimum_success_rate: 90
  maximum_failed_tests: 5
  performance_thresholds:
    max_execution_time: "30m"
    max_memory_usage: "2GB"
  
  security_requirements:
    rbac_validation: required
    acl_validation: required
    compliance_score: 85
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Authentication Errors
```bash
# Verify credentials
echo $CONFLUENT_CLOUD_API_KEY | head -c 10
echo $CONFLUENT_CLOUD_API_SECRET | head -c 10

# Test API connectivity
curl -u "$CONFLUENT_CLOUD_API_KEY:$CONFLUENT_CLOUD_API_SECRET" \
  https://api.confluent.cloud/org/v2/environments
```

#### 2. Terraform State Issues
```bash
# Reset Terraform state for specific module
cd terraform/modules/kafka-topic
terraform init -upgrade
terraform workspace select default || terraform workspace new default

# Clean up test resources manually
./scripts/cleanup-test-resources.sh --pipeline-id=manual --force
```

#### 3. Permission Issues
```bash
# Check API key permissions
# Ensure your API key has:
# - Cloud resource management permissions
# - Kafka cluster admin access
# - Role binding management access
```

#### 4. Module Dependencies
```bash
# Run dependency check
./scripts/test-runner.sh --dry-run --verbose --env dev

# Check module execution order
grep -r "dependencies:" config/modules.yaml
```

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
export DEBUG=true
export VERBOSE=true

# Run with full debug output
./scripts/test-runner.sh --verbose --env dev 2>&1 | tee debug.log
```

### Log Analysis

Check logs for detailed error information:

```bash
# View recent logs
tail -f logs/test-execution.log

# Sprint-specific logs
tail -f scripts/sprint3-integration.log
tail -f logs/sprint5-validation.log

# Continuous testing logs
tail -f continuous-testing/logs/continuous-testing.log
```

## Best Practices

### 1. Environment Management
- Use separate environments for different test phases
- Keep production environment configurations secure
- Regularly clean up test resources to avoid costs

### 2. Test Execution Strategy
- Start with basic tests before running comprehensive suites
- Use dry-run mode to validate configurations
- Run performance tests during off-peak hours

### 3. Security Considerations
- Store sensitive credentials securely (use CI/CD variables)
- Regularly rotate API keys
- Monitor test execution for unauthorized access

### 4. Resource Management
```bash
# Regular cleanup
./scripts/cleanup-test-resources.sh --older-than="1 day"

# Monitor resource usage
./scripts/test-runner.sh --plan basic --env dev --verbose | grep -i "resource\|cost"
```

### 5. Monitoring and Alerting
- Set up notifications for test failures
- Monitor test execution times for performance regression
- Track success rates across sprints

### 6. Sprint Migration Strategy

When moving from one sprint to another:

```bash
# 1. Validate current sprint functionality
./scripts/validate-sprint${CURRENT}.sh

# 2. Run regression tests
./scripts/test-runner.sh --plan full --env dev

# 3. Clean up resources
./scripts/cleanup-test-resources.sh

# 4. Update configurations for new sprint
# Edit config/modules.yaml to enable new modules

# 5. Test new sprint functionality
./scripts/run-sprint${NEW}.sh basic all

# 6. Validate integration
./scripts/test-runner.sh --plan full --env dev
```

### 7. Performance Optimization
- Use parallel execution for independent modules
- Cache Terraform providers and modules
- Optimize test data sizes for faster execution

### 8. Documentation Maintenance
- Update test documentation after each sprint
- Maintain configuration examples
- Document any custom modifications or extensions

---

## Quick Reference Commands

### Daily Operations
```bash
# Quick health check
./scripts/test-runner.sh --dry-run --plan basic --env dev

# Run current sprint tests
./scripts/run-sprint3.sh basic all  # Adjust sprint number

# Performance check
./scripts/run-e2e-tests.sh --test-type=performance --env=dev
```

### Sprint Completion Checklist
```bash
# 1. Validate sprint implementation
./scripts/validate-sprint${N}.sh

# 2. Run comprehensive regression tests
./scripts/test-runner.sh --plan full --env staging

# 3. Performance validation
./scripts/run-e2e-tests.sh --test-type=all --env=staging

# 4. Generate final report
python3 scripts/test-reporting.py --sprint=${N} --comprehensive

# 5. Clean up test resources
./scripts/cleanup-test-resources.sh --confirm
```

### Emergency Procedures
```bash
# Stop all running tests
pkill -f "terraform\|test-runner"

# Force cleanup of all test resources
./scripts/cleanup-test-resources.sh --force --all-environments

# Reset framework to clean state
git stash
git pull
./scripts/setup.sh
```

---

This comprehensive guide covers all aspects of the Confluent Cloud Test Framework from basic usage to advanced sprint-specific testing. For additional support, refer to the individual sprint walkthrough documents or contact your development team.
