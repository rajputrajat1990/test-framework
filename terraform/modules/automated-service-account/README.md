# Automated Service Account Module

This Terraform module creates Confluent Cloud service accounts with automated API key generation and RBAC role binding. It eliminates the need for manual API key creation by leveraging the Confluent Terraform Provider v2.37.0+ capabilities.

## Features

- **Automated Service Account Creation**: Creates service accounts with descriptive names
- **Automatic API Key Generation**: Generates both cloud-level and cluster-level API keys
- **RBAC Role Binding**: Automatically assigns roles with proper CRN patterns
- **Flexible Configuration**: Supports multiple roles and scope configurations
- **Security Best Practices**: Sensitive outputs, minimal permissions, proper scoping

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.12.2 |
| confluent | ~> 2.37.0 |

## Usage

### Basic Example - Organization Admin

```hcl
module "test_automation_sa" {
  source = "./modules/automated-service-account"

  service_account_name        = "test-automation"
  service_account_description = "Service account for test automation"
  
  organization_id = "your-org-id"
  environment_id  = "env-12345"
  cluster_id      = "lkc-12345"
  
  rbac_roles = {
    orgadmin = {
      role_name   = "OrganizationAdmin"
      crn_pattern = "crn://confluent.cloud/organization/your-org-id"
    }
  }
  
  create_cloud_api_key    = true
  create_cluster_api_key  = true
}
```

### Limited Permissions Example - Monitoring

```hcl
module "monitoring_sa" {
  source = "./modules/automated-service-account"

  service_account_name = "monitoring"
  
  organization_id = "your-org-id"
  environment_id  = "env-12345"
  cluster_id      = "lkc-12345"
  
  rbac_roles = {
    metrics = {
      role_name   = "MetricsViewer"
      crn_pattern = "crn://confluent.cloud/organization/your-org-id/environment/env-12345"
    }
    read_access = {
      role_name   = "DeveloperRead"
      crn_pattern = "crn://confluent.cloud/organization/your-org-id/environment/env-12345/cloud-cluster/lkc-12345"
    }
  }
  
  create_cloud_api_key    = false
  create_cluster_api_key  = true
}
```

### Development Team Example

```hcl
module "dev_team_sa" {
  source = "./modules/automated-service-account"

  service_account_name = "dev-team"
  
  organization_id = var.organization_id
  environment_id  = var.dev_environment_id
  cluster_id      = var.dev_cluster_id
  
  rbac_roles = {
    env_admin = {
      role_name   = "EnvironmentAdmin"
      crn_pattern = "crn://confluent.cloud/organization/${var.organization_id}/environment/${var.dev_environment_id}"
    }
    cluster_manage = {
      role_name   = "DeveloperManage"  
      crn_pattern = "crn://confluent.cloud/organization/${var.organization_id}/environment/${var.dev_environment_id}/cloud-cluster/${var.dev_cluster_id}"
    }
  }
  
  create_cloud_api_key    = false
  create_cluster_api_key  = true
  
  tags = {
    team        = "development"
    environment = "dev"
    managed_by  = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| service_account_name | Name of the service account to create | `string` | n/a | yes |
| service_account_description | Description of the service account | `string` | `"Automated service account for Confluent Cloud operations"` | no |
| organization_id | Confluent Cloud Organization ID | `string` | n/a | yes |
| environment_id | Confluent Cloud Environment ID (optional, for scoped keys) | `string` | `""` | no |
| cluster_id | Confluent Cloud Cluster ID (optional, for cluster-scoped keys) | `string` | `""` | no |
| rbac_roles | Map of RBAC roles to assign to the service account | `map(object)` | `{}` | no |
| create_cloud_api_key | Whether to create a cloud-level API key | `bool` | `true` | no |
| create_cluster_api_key | Whether to create a cluster-level API key | `bool` | `false` | no |
| tags | Tags to apply to the service account and API keys | `map(string)` | `{}` | no |

### RBAC Roles Object Structure

```hcl
rbac_roles = {
  role_key = {
    role_name   = string  # Confluent Cloud role name
    crn_pattern = string  # CRN pattern for resource scope
  }
}
```

### Supported Role Names

| Role Name | Description | Scope |
|-----------|-------------|-------|
| OrganizationAdmin | Full organization access | Organization |
| EnvironmentAdmin | Environment administration | Environment |
| CloudClusterAdmin | Full cluster administration | Cluster |
| DeveloperManage | Manage cluster resources | Cluster |
| DeveloperWrite | Write access to topics | Cluster/Topic |
| DeveloperRead | Read access to topics | Cluster/Topic |
| ResourceOwner | Resource ownership | Resource-specific |
| Operator | Operational access | Cluster |
| MetricsViewer | Metrics and monitoring | Environment/Cluster |

## Outputs

| Name | Description |
|------|-------------|
| service_account_id | ID of the created service account |
| service_account_display_name | Display name of the created service account |
| service_account_description | Description of the created service account |
| cloud_api_key_id | ID of the cloud API key (sensitive) |
| cloud_api_key_secret | Secret of the cloud API key (sensitive) |
| cluster_api_key_id | ID of the cluster API key (sensitive) |
| cluster_api_key_secret | Secret of the cluster API key (sensitive) |
| rbac_role_bindings | Map of RBAC role bindings created |

## CRN Patterns

CRN (Confluent Resource Name) patterns define the scope of permissions:

### Organization Level
```
crn://confluent.cloud/organization={org-id}
```

### Environment Level  
```
crn://confluent.cloud/organization={org-id}/environment={env-id}
```

### Cluster Level
```
crn://confluent.cloud/organization={org-id}/environment={env-id}/cloud-cluster={cluster-id}
```

### Topic Level
```
crn://confluent.cloud/organization={org-id}/environment={env-id}/cloud-cluster={cluster-id}/kafka={cluster-id}/topic={topic-name}
```

## API Key Types

### Cloud API Key
- **Purpose**: Organization-wide operations (creating environments, clusters, etc.)
- **Required for**: OrganizationAdmin, cross-environment operations
- **Scoping**: Organization level

### Cluster API Key  
- **Purpose**: Cluster-specific operations (producing, consuming, topic management)
- **Required for**: All cluster operations
- **Scoping**: Cluster level

## Security Considerations

1. **Principle of Least Privilege**: Only assign necessary roles
2. **Scope Appropriately**: Use environment/cluster scoping when possible
3. **Secure State**: Use remote state with encryption
4. **Audit Regularly**: Review service accounts and permissions
5. **Rotate Keys**: Plan for API key rotation (manual or automated)

## Examples

See the `terraform/examples/` directory for comprehensive usage examples including:
- Multi-environment setup
- Different permission levels
- Integration with other modules

## Troubleshooting

### Common Issues

**Error: Invalid role name**
- Ensure role names match exactly (case-sensitive)
- Check supported roles list above

**Error: Invalid CRN pattern**
- Verify organization, environment, and cluster IDs
- Ensure CRN pattern matches the role scope requirements

**Error: Insufficient permissions**
- Verify bootstrap API key has OrganizationAdmin role
- Check that the bootstrap key can create service accounts

### Getting Resource IDs

```bash
# Organization ID
confluent organization list

# Environment ID  
confluent environment list

# Cluster ID
confluent kafka cluster list --environment <env-id>
```

## Migration from Manual API Keys

1. Identify existing manually created service accounts and API keys
2. Create equivalent automated service accounts using this module
3. Update applications to use new API keys
4. Remove old manually created resources
5. Update documentation and runbooks

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Update documentation for any new features
3. Test with multiple scenarios
4. Validate CRN patterns and role combinations
5. Ensure security best practices are maintained
