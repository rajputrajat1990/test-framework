# Local GitLab Setup for Confluent Test Framework

This guide helps you set up a complete **local GitLab CE environment** with runners to run the CI/CD pipeline locally, avoiding any cloud charges.

## 🎯 Why Local GitLab?

- **💰 No Charges**: Run everything locally, no GitLab.com costs
- **🔒 Privacy**: Keep your code and credentials local
- **🚀 Fast Feedback**: No network latency for pipeline execution
- **🧪 Safe Testing**: Experiment without affecting production

## 📋 Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **8GB RAM minimum** (GitLab is memory-intensive)
- **20GB free disk space**

## 🚀 Quick Start

### 1. Set Up GitLab Environment

```bash
# Make scripts executable
chmod +x scripts/setup-local-gitlab.sh
chmod +x scripts/manage-gitlab.sh
chmod +x scripts/setup-runners.sh

# Start the complete GitLab setup
./scripts/setup-local-gitlab.sh
```

This will:
- Start GitLab CE container
- Configure hostname in `/etc/hosts`
- Set up 3 different runners (Shell, Docker, Kubernetes)
- Configure container registry

### 2. Access GitLab

Once setup is complete:
- **URL**: http://gitlab.local:8080
- **Username**: `root`
- **Password**: `rootpassword123`

### 3. Set Up Your First Project

1. **Create New Project** in GitLab
2. **Clone** the Confluent Test Framework:
   ```bash
   git clone http://gitlab.local:8080/root/confluent-test-framework.git
   cd confluent-test-framework
   ```

3. **Add the repository** as remote:
   ```bash
   git remote add gitlab http://gitlab.local:8080/root/confluent-test-framework.git
   git push gitlab main
   ```

## ⚙️ Environment and Cluster Setup

Since the framework expects existing Confluent Cloud environments and clusters, you have two options:

### Option A: Create Environments Automatically

```bash
# Install Confluent CLI first
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest

# Set credentials (optional)
export CONFLUENT_CLOUD_EMAIL="your-email@example.com"
export CONFLUENT_CLOUD_PASSWORD="your-password"

# Create environments and clusters
./scripts/create-confluent-environments.sh
```

This creates:
- **Development Environment** with Basic cluster
- **Staging Environment** with Standard cluster
- Updates configuration files automatically

### Option B: Use Existing Environments

Update the configuration files with your existing environment/cluster IDs:

```yaml
# config/environments/dev.yaml
confluent_cloud:
  environment_id: "env-your-dev-id"
  cluster_id: "lkc-your-cluster-id"
```

## 🏃‍♂️ GitLab Runners

The setup includes **3 different runners**:

| Runner Type | Tags | Use Case |
|-------------|------|----------|
| **Shell Runner** | `shell`, `terraform`, `linux` | Direct Terraform commands |
| **Docker Runner** | `docker`, `tests`, `containers` | Containerized testing |
| **K8s Runner** | `k8s`, `kubernetes`, `advanced` | Scalable workloads |

### Manual Runner Registration

If automatic registration fails:

```bash
# Get registration token from GitLab Admin > CI/CD > Runners
./scripts/setup-runners.sh <registration-token>
```

## 🔐 CI/CD Variables Setup

In your GitLab project, go to **Settings > CI/CD > Variables** and add:

| Variable | Description | Value |
|----------|-------------|-------|
| `CONFLUENT_API_KEY` | Confluent Cloud API Key | Your API key |
| `CONFLUENT_API_SECRET` | Confluent Cloud API Secret | Your API secret |
| `CONFLUENT_ENVIRONMENT_ID` | Environment ID | From config files |
| `CONFLUENT_CLUSTER_ID` | Cluster ID | From config files |

## 🛠️ Common Operations

### GitLab Management

```bash
# Start GitLab
./scripts/manage-gitlab.sh start

# Stop GitLab
./scripts/manage-gitlab.sh stop

# View logs
./scripts/manage-gitlab.sh logs -f

# Show status
./scripts/manage-gitlab.sh status

# Get registration token
./scripts/manage-gitlab.sh token

# Show runners status
./scripts/manage-gitlab.sh runners

# Create backup
./scripts/manage-gitlab.sh backup

# Reset everything (DESTRUCTIVE!)
./scripts/manage-gitlab.sh reset
```

### Docker Compose Operations

```bash
# Start services
docker-compose -f docker-compose.gitlab.yml up -d

# Stop services
docker-compose -f docker-compose.gitlab.yml down

# View logs
docker-compose -f docker-compose.gitlab.yml logs -f gitlab

# Restart specific service
docker-compose -f docker-compose.gitlab.yml restart gitlab
```

## 📊 Resource Requirements

### Minimum Configuration

- **RAM**: 8GB (GitLab needs ~4GB)
- **CPU**: 4 cores
- **Disk**: 20GB free space

### Recommended Configuration

- **RAM**: 16GB+ 
- **CPU**: 8+ cores
- **Disk**: 50GB+ SSD

### Resource Optimization

If you're on limited resources:

```bash
# Edit docker-compose.gitlab.yml and add:
services:
  gitlab:
    deploy:
      resources:
        limits:
          memory: 4g
        reservations:
          memory: 2g
```

## 🔧 Troubleshooting

### GitLab Won't Start

```bash
# Check logs
./scripts/manage-gitlab.sh logs

# Check Docker resources
docker system df
docker stats

# Free up space
./scripts/manage-gitlab.sh cleanup
```

### Runners Not Connecting

```bash
# Check runner status
./scripts/manage-gitlab.sh runners

# Re-register runners
./scripts/setup-runners.sh <token>

# Check runner logs
docker logs gitlab-runner-shell
```

### Pipeline Failures

```bash
# Check GitLab variables
# Go to Project > Settings > CI/CD > Variables

# Check Confluent connectivity
confluent environment list
confluent kafka cluster list
```

### Memory Issues

```bash
# Monitor resource usage
docker stats

# Reduce GitLab features in docker-compose.gitlab.yml:
environment:
  GITLAB_OMNIBUS_CONFIG: |
    prometheus_monitoring['enable'] = false
    grafana['enable'] = false
    alertmanager['enable'] = false
```

## 🌐 Network Configuration

The setup uses custom networking:

- **GitLab Network**: `172.20.0.0/16`
- **Hostname**: `gitlab.local` (added to `/etc/hosts`)
- **Ports**:
  - `8080`: GitLab Web UI
  - `8022`: GitLab SSH
  - `5050`: Container Registry

### Firewall Configuration

If using a firewall:

```bash
# Allow GitLab ports
sudo ufw allow 8080
sudo ufw allow 8022
sudo ufw allow 5050
```

## 📈 Performance Tuning

### GitLab Configuration

Edit the GitLab configuration in `docker-compose.gitlab.yml`:

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    # Increase worker processes
    unicorn['worker_processes'] = 4
    
    # Optimize database
    postgresql['shared_preload_libraries'] = 'pg_stat_statements'
    
    # Reduce background jobs
    sidekiq['max_concurrency'] = 10
```

### Runner Optimization

```bash
# Increase concurrent jobs per runner
docker exec gitlab-runner-docker gitlab-runner edit-config --name docker-runner
# Set concurrent = 3 in the config file
```

## 🔄 Updates and Maintenance

### Update GitLab

```bash
# Update to latest version
./scripts/manage-gitlab.sh update

# Or manually:
docker-compose -f docker-compose.gitlab.yml pull
docker-compose -f docker-compose.gitlab.yml up -d --force-recreate
```

### Regular Maintenance

```bash
# Weekly cleanup
./scripts/manage-gitlab.sh cleanup

# Monthly backup
./scripts/manage-gitlab.sh backup

# Monitor disk usage
df -h
docker system df
```

## 🛡️ Security Considerations

### Local Environment Security

- **Change default password** immediately
- **Disable unnecessary features** to reduce attack surface
- **Keep Docker updated**
- **Monitor logs** for suspicious activity

### Production-Like Security

For more production-like testing:

```yaml
# docker-compose.gitlab.yml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    # Enable HTTPS
    external_url 'https://gitlab.local'
    letsencrypt['enable'] = false
    nginx['ssl_certificate'] = "/etc/ssl/certs/gitlab.crt"
    nginx['ssl_certificate_key'] = "/etc/ssl/private/gitlab.key"
```

## 📚 Additional Resources

- **GitLab CE Documentation**: https://docs.gitlab.com/ee/
- **GitLab Runner Documentation**: https://docs.gitlab.com/runner/
- **Confluent CLI Documentation**: https://docs.confluent.io/confluent-cli/current/
- **Docker Compose Reference**: https://docs.docker.com/compose/

## 🆘 Getting Help

If you encounter issues:

1. **Check logs**: `./scripts/manage-gitlab.sh logs -f`
2. **Check system resources**: `docker stats`
3. **Review GitLab admin panel**: http://gitlab.local:8080/admin
4. **Check runner connectivity**: `./scripts/manage-gitlab.sh runners`

## 🚀 Next Steps

Once your local GitLab is running:

1. **Import** your test framework repository
2. **Configure CI/CD variables** with your Confluent credentials
3. **Test** a simple pipeline run
4. **Scale up** by adding more runners if needed
5. **Integrate** with your development workflow

This setup gives you a complete, local CI/CD environment equivalent to GitLab.com but without any costs!
