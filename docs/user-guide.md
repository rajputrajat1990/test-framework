# User Guide

## Getting Started

This guide will help you set up and use the Confluent Cloud Terraform Test Framework to test your infrastructure configurations.

## Prerequisites

### System Requirements
- **Terraform**: >= 1.6.0
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Additional Tools**: `jq`, `curl`, `yq` (installed automatically by setup script)

### Confluent Cloud Requirements
- Active Confluent Cloud account
- Environment with a Kafka cluster
- API key with the following permissions:
  - Cloud resource management
  - Kafka cluster administration
  - Role binding management

### Optional Requirements
- **AWS Account**: For S3 connector testing
- **Service Account**: For RBAC testing

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd terraform-automation-framework
```

### 2. Set Environment Variables
Create a `.env` file or set environment variables:

```bash
# Required variables
export CONFLUENT_CLOUD_API_KEY="your-cloud-api-key"
export CONFLUENT_CLOUD_API_SECRET="your-cloud-api-secret"
export CONFLUENT_ENVIRONMENT_ID="env-xxxxx"
export CONFLUENT_CLUSTER_ID="lkc-xxxxx"

# Optional variables
export TEST_S3_BUCKET="your-test-bucket"
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export CONFLUENT_KAFKA_API_KEY="your-kafka-api-key"
export CONFLUENT_KAFKA_API_SECRET="your-kafka-api-secret"
export TEST_SERVICE_ACCOUNT="User:test-user@example.com"
```

### 3. Run Setup Script
```bash
./scripts/setup.sh
```

The setup script will:
- Validate prerequisites
- Check environment variables
- Initialize Terraform configurations
- Test Confluent Cloud connectivity
- Create necessary directories

## Basic Usage

### Running All Tests
```bash
# Run basic test suite
./scripts/test-runner.sh --env dev

# Run full test suite including connectors
./scripts/test-runner.sh --env dev --plan full

# Run in staging environment
./scripts/test-runner.sh --env staging --plan basic
```

### Running Specific Modules
```bash
# Test only Kafka topics
./scripts/test-runner.sh --module kafka_topic --env dev

# Test RBAC configuration
./scripts/test-runner.sh --module rbac_cluster_admin --env dev
```

### Dry Run Mode
```bash
# See what would be executed without actually running
./scripts/test-runner.sh --dry-run --plan full --env dev
```

### Parallel Execution
```bash
# Run independent modules in parallel
./scripts/test-runner.sh --parallel --env dev
```

## Configuration

### Module Configuration

Edit `config/modules.yaml` to customize module behavior:

```yaml
modules:
  kafka_topic:
    path: "./modules/kafka-topic"
    parameters:
      topic_name: "${TEST_PREFIX}-topic-${TEST_SUFFIX}"
      partitions: 3
      # Add more parameters as needed
    validation:
      resource_count: 1
      resource_type: "confluent_kafka_topic"
    enabled: true  # Set to false to disable
```

### Environment Configuration

Create environment-specific configurations in `config/environments/`:

```yaml
# config/environments/dev.yaml
environment:
  name: "dev"
  
confluent_cloud:
  environment_id: "env-dev123"
  cluster_id: "lkc-dev456"

testing:
  execution_mode: "apply"
  cleanup_policy: "always"
  timeout_minutes: 20

module_overrides:
  kafka_topic:
    parameters:
      partitions: 1  # Reduced for dev
```

### Custom Execution Plans

Define custom test execution plans:

```yaml
execution_modes:
  - name: "custom-plan"
    description: "Custom test execution"
    modules:
      - kafka_topic
      - rbac_cluster_admin
      # Add modules as needed
```

## Module Development

### Creating a New Module

1. **Create Module Directory**:
```bash
mkdir terraform/modules/your-module
```

2. **Create Module Files**:
```bash
# Main Terraform configuration
terraform/modules/your-module/main.tf

# Module documentation
terraform/modules/your-module/README.md
```

3. **Implement Standard Interface**:
```hcl
# terraform/modules/your-module/main.tf
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.51.0"
    }
  }
}

variable "environment_id" {
  description = "Confluent Cloud Environment ID"
  type        = string
}

# Your module-specific variables
variable "your_parameter" {
  description = "Your parameter description"
  type        = string
}

# Your resources
resource "confluent_your_resource" "main" {
  # Resource configuration
}

# Standard outputs
output "validation_data" {
  description = "Data for resource validation"
  value = {
    resource_count = 1
    resource_type  = "confluent_your_resource"
    expected_properties = {
      # Expected values
    }
    created_properties = {
      # Actual values
    }
  }
}
```

4. **Add Module to Configuration**:
```yaml
# config/modules.yaml
modules:
  your_module:
    path: "./modules/your-module"
    description: "Your module description"
    parameters:
      environment_id: "${CONFLUENT_ENVIRONMENT_ID}"
      your_parameter: "your_value"
    validation:
      resource_count: 1
      resource_type: "confluent_your_resource"
```

5. **Create Test File** (optional):
```hcl
# terraform/tests/integration/your-module.tftest.hcl
run "test_your_module" {
  command = apply

  module {
    source = "../../modules/your-module"
  }

  variables = {
    environment_id = var.environment_id
    your_parameter = "test_value"
  }

  assert {
    condition     = output.your_output == "expected_value"
    error_message = "Output validation failed"
  }
}
```

## Testing Strategies

### Unit Testing
```bash
# Test individual modules in isolation
./scripts/test-runner.sh --module kafka_topic --env dev
```

### Integration Testing
```bash
# Test multiple modules together
./scripts/test-runner.sh --plan basic --env dev
```

### End-to-End Testing
```bash
# Full environment test
./scripts/test-runner.sh --plan full --env staging
```

### Regression Testing
```bash
# Test all modules after changes
./scripts/test-runner.sh --plan full --env dev --parallel
```

## Advanced Usage

### Custom Variable Substitution

Use environment variables in your configurations:

```yaml
parameters:
  topic_name: "${TEST_PREFIX}-${TOPIC_SUFFIX}-${TEST_SUFFIX}"
  custom_config: "${CUSTOM_CONFIG_VALUE}"
```

### Conditional Module Execution

Control module execution based on environment:

```yaml
modules:
  s3_source_connector:
    enabled: false  # Globally disabled
    # Override in environment config
```

```yaml
# config/environments/staging.yaml
module_overrides:
  s3_source_connector:
    enabled: true  # Enable in staging
```

### Custom Validation Rules

Add custom validation logic:

```yaml
modules:
  kafka_topic:
    validation:
      property_checks:
        - property: "partitions_count"
          expected: 3
          operator: "equals"
        - property: "config.retention.ms"
          expected: 604800000
          operator: "greater_than"
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: Invalid API credentials
```
**Solution**: Verify your API key and secret are correct and have necessary permissions.

#### 2. Resource Already Exists
```
Error: Topic already exists
```
**Solution**: Resource names must be unique. The framework uses random suffixes to prevent conflicts.

#### 3. Timeout Issues
```
Error: Operation timed out
```
**Solution**: Increase timeout values in environment configuration:
```yaml
testing:
  timeout_minutes: 45
```

#### 4. Module Dependencies
```
Error: Dependency not met
```
**Solution**: Ensure dependent modules are included in execution plan or run them first.

### Debugging

#### Enable Verbose Logging
```bash
./scripts/test-runner.sh --verbose --env dev
```

#### Check Log Files
```bash
# View latest logs
ls -la logs/
tail -f logs/kafka_topic_*.log
```

#### Manual Terraform Commands
```bash
# Navigate to module directory
cd terraform/modules/kafka-topic

# Run terraform commands manually
terraform init
terraform plan -var="environment_id=env-xxxxx" ...
```

### Cleanup Issues

#### Manual Cleanup
```bash
# If automatic cleanup fails, clean up manually
cd terraform/modules/problematic-module
terraform destroy -auto-approve \
  -var="environment_id=$CONFLUENT_ENVIRONMENT_ID" \
  -var="cluster_id=$CONFLUENT_CLUSTER_ID"
```

#### Force Cleanup
```bash
# Skip cleanup validation
./scripts/test-runner.sh --no-cleanup --env dev
```

## Best Practices

### 1. Resource Naming
- Use descriptive prefixes
- Include environment indicators
- Ensure uniqueness with random suffixes

### 2. Configuration Management
- Keep sensitive data in environment variables
- Use environment-specific overrides
- Document configuration changes

### 3. Test Organization
- Group related tests in execution plans
- Use meaningful module names
- Include comprehensive validation

### 4. Error Handling
- Always check logs for detailed errors
- Use dry-run mode to validate configurations
- Clean up resources after failed tests

### 5. Security
- Never commit credentials to version control
- Use least-privilege API keys
- Regularly rotate credentials
- Review logs for sensitive data exposure

## Support and Contribution

### Getting Help
- Check the troubleshooting section
- Review log files for detailed error information
- Check Confluent Cloud console for resource status

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Reporting Issues
Please include:
- Framework version
- Environment details
- Configuration files (sanitized)
- Error logs
- Steps to reproduce

This user guide provides comprehensive information for using the framework effectively. For architectural details, see the [Architecture Guide](architecture.md).
