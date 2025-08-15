# Kafka Topic Module

This module creates a Kafka topic in Confluent Cloud with configurable partitions and topic settings.

## Features

- Creates Kafka topics with specified partitions
- Configurable topic settings (cleanup policy, retention, etc.)
- Supports custom topic configuration
- Provides comprehensive validation data
- Compatible with Confluent Cloud Terraform provider

## Usage

```hcl
module "kafka_topic" {
  source = "./modules/kafka-topic"

  topic_name     = "test-topic-${random_string.suffix.result}"
  partitions     = 3
  environment_id = var.environment_id
  cluster_id     = var.cluster_id
  
  topic_config = {
    "cleanup.policy"       = "delete"
    "retention.ms"         = "604800000"  # 7 days
    "min.insync.replicas" = "2"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| topic_name | Name of the Kafka topic | string | n/a | yes |
| partitions | Number of partitions for the topic | number | 3 | no |
| environment_id | Confluent Cloud Environment ID | string | n/a | yes |
| cluster_id | Confluent Cloud Kafka Cluster ID | string | n/a | yes |
| topic_config | Topic configuration settings | map(string) | see main.tf | no |
| rest_endpoint | REST endpoint of the Kafka cluster | string | "" | no |
| credentials | Kafka cluster credentials | object | {key="", secret=""} | no |

## Outputs

| Name | Description |
|------|-------------|
| topic_name | Name of the created topic |
| topic_id | ID of the created topic |
| partitions_count | Number of partitions |
| config | Topic configuration |
| rest_endpoint | REST endpoint used |
| validation_data | Data for resource validation |

## Validation

This module provides validation data that can be used by the test framework to verify:

- Resource creation (1 topic expected)
- Topic name matches expected value
- Partition count matches expected value
- Configuration matches expected settings

## Requirements

- Terraform >= 1.6.0
- Confluent Cloud Terraform Provider ~> 1.51.0
- Valid Confluent Cloud credentials with topic creation permissions
