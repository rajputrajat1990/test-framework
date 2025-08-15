# Terraform Upgrade and Automated API Key Migration Guide

This document outlines the upgrade from the previous Terraform configuration to the new automated service account and API key management system.

## What's Changed

### 1. Provider Version Updates
- **Terraform**: Upgraded from `>= 1.6.0` to `>= 1.12.2`
- **Confluent Provider**: Upgraded from `~> 1.51.0` to `~> 2.37.0`
- **HashiCorp Random**: Upgraded from `~> 3.4` to `~> 3.7.2` 
- **HashiCorp Time**: Upgraded from `~> 0.9` to `~> 0.13.1`

### 2. Automated API Key Management
- New `automated-service-account` module for automated service account creation
- Service accounts can be created with orgadmin RBAC for full automation
- Automatic API key generation (both cloud-level and cluster-level)
- RBAC role binding automation

## Migration Steps

### Step 1: Upgrade Terraform Version
Ensure you have Terraform 1.12.2 or later installed:

```bash
terraform version
# If needed, upgrade Terraform to 1.12.2+
```

### Step 2: Update Provider Versions
The provider versions have been automatically updated in all modules:
- `terraform/shared/main.tf`
- All module files in `terraform/modules/`

### Step 3: Initial Bootstrap Setup
You still need ONE manually created API key with orgadmin privileges for the initial bootstrap. This key will be used to create all subsequent automated service accounts.

Create a `terraform.tfvars` file:
```hcl
# Initial bootstrap credentials (manually created)
confluent_cloud_api_key    = "YOUR_BOOTSTRAP_API_KEY"
confluent_cloud_api_secret = "YOUR_BOOTSTRAP_API_SECRET"

# Required IDs
organization_id = "your-org-id"
environment_id  = "env-12345" 
cluster_id     = "lkc-12345"
```

### Step 4: Initialize and Apply Changes
```bash
# Navigate to your terraform configuration
cd terraform/shared

# Initialize with new provider versions
terraform init -upgrade

# Plan the changes
terraform plan

# Apply the changes  
terraform apply
```

### Step 5: Use Generated API Keys
After the initial apply, you can access the automatically generated API keys:

```bash
# Get the automated API key outputs
terraform output automated_cloud_api_key_id
terraform output automated_cloud_api_key_secret
```

## New Automated Service Account Module

### Basic Usage
```hcl
module "my_service_account" {
  source = "./modules/automated-service-account"

  service_account_name        = "my-automation-sa"
  service_account_description = "My automated service account"
  
  organization_id = var.organization_id
  environment_id  = var.environment_id
  cluster_id      = var.cluster_id
  
  rbac_roles = {
    orgadmin = {
      role_name   = "OrganizationAdmin"
      crn_pattern = "crn://confluent.cloud/organization/${var.organization_id}"
    }
  }
  
  create_cloud_api_key    = true
  create_cluster_api_key  = true
}
```

### Available RBAC Roles
- `OrganizationAdmin` - Full organization access
- `EnvironmentAdmin` - Environment-level administration  
- `CloudClusterAdmin` - Full cluster administration
- `DeveloperManage` - Manage cluster resources
- `DeveloperWrite` - Write access to topics
- `DeveloperRead` - Read access to topics
- `ResourceOwner` - Resource ownership
- `Operator` - Operational access
- `MetricsViewer` - Metrics and monitoring access

### Multiple Service Accounts Example
```hcl
# Test automation with full privileges
module "test_automation" {
  source = "./modules/automated-service-account"
  # ... configuration with OrganizationAdmin
}

# Monitoring with limited privileges  
module "monitoring" {
  source = "./modules/automated-service-account"
  # ... configuration with MetricsViewer + DeveloperRead
}

# Development team access
module "development" {
  source = "./modules/automated-service-account"
  # ... configuration with EnvironmentAdmin + DeveloperManage  
}
```

## Benefits of New Approach

### 1. **No Manual API Key Management**
- Service accounts and API keys are created automatically
- No need to manually generate keys in the Confluent Cloud UI
- Keys are properly scoped with appropriate RBAC

### 2. **Better Security**
- Each service account has minimal required permissions
- API keys are properly managed through Terraform state
- Automated rotation capabilities (can be extended)

### 3. **Improved Automation**
- One bootstrap key can create unlimited service accounts
- Consistent RBAC application across environments
- Easy to replicate across environments

### 4. **Better Governance**
- All service accounts are tracked in Terraform
- RBAC roles are explicitly defined and versioned
- Easy to audit and review permissions

## Troubleshooting

### Issue: Provider Version Conflicts
```bash
# Clean up and reinitialize
rm -rf .terraform
rm .terraform.lock.hcl
terraform init -upgrade
```

### Issue: Bootstrap API Key Permissions
Ensure your bootstrap API key has `OrganizationAdmin` role:
1. Go to Confluent Cloud UI
2. Navigate to Administration > Access management
3. Verify the service account has OrganizationAdmin role

### Issue: CRN Pattern Errors
Verify your organization, environment, and cluster IDs:
```bash
# List organizations
confluent organization list

# List environments  
confluent environment list

# List clusters
confluent kafka cluster list --environment <env-id>
```

## Best Practices

1. **Minimize Bootstrap Key Usage**: Only use the bootstrap key for initial setup
2. **Use Scoped Service Accounts**: Create service accounts with minimal required permissions
3. **Environment Separation**: Use different service accounts for different environments
4. **Regular Audits**: Review service accounts and their permissions regularly
5. **Secure State Management**: Use remote state with encryption for Terraform state

## Example Directory Structure
```
terraform/
├── shared/
│   └── main.tf                           # Updated with new providers
├── modules/
│   ├── automated-service-account/        # New module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── other-modules/                    # All updated to new provider versions
└── examples/
    └── automated-service-accounts.tf     # Usage examples
```

This migration provides a robust foundation for automated Confluent Cloud resource management while maintaining security and governance standards.
