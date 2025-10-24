# 🚀 Octopets Azure Deployment Guide

This guide will help you deploy the Octopets application to Azure using Sweden Central region for optimal PostgreSQL availability.

## 🏗️ Infrastructure Overview

The deployment creates the following Azure resources:

- **Azure Database for PostgreSQL Flexible Server** (Sweden Central)
- **Azure Container Apps** for the backend API (Sweden Central)
- **Azure Static Web Apps** for the React frontend (West Europe)
- **Azure Key Vault** for secure secrets management (Sweden Central)
- **Azure Container Registry** for Docker images (Sweden Central)
- **Application Insights** for monitoring (Sweden Central)
- **Log Analytics Workspace** for logging (Sweden Central)

## 📋 Prerequisites

1. **Azure CLI** installed and configured
   ```bash
   # Install Azure CLI
   # Windows: Download from https://aka.ms/installazurecliwindows
   # macOS: brew install azure-cli
   # Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login to Azure
   az login
   ```

2. **GitHub CLI** (optional, for setting up secrets)
   ```bash
   # Install GitHub CLI
   # Windows: winget install GitHub.CLI
   # macOS: brew install gh
   # Linux: Follow instructions at https://cli.github.com/
   
   # Login to GitHub
   gh auth login
   ```

3. **Docker** installed (for local testing)

4. **Node.js 18+** and **npm** (for frontend development)

5. **OpenAI API Key** (for pet analysis features)

## 🚀 Deployment Steps

### Step 1: Clone and Prepare Repository

```bash
# Clone your repository
git clone https://github.com/surivineela/octopets.git
cd octopets

# Ensure you're on the main branch
git checkout main
```

### Step 2: Run Deployment Script

#### Option A: PowerShell (Windows)

```powershell
# Make the script executable and run it
.\deploy-azure.ps1
```

#### Option B: Bash (Linux/macOS)

```bash
# Make the script executable and run it
chmod +x deploy-azure.sh
./deploy-azure.sh
```

### Step 3: Configure GitHub Secrets

After deployment, configure the following GitHub repository secrets for CI/CD:

```bash
# Required secrets (set these in GitHub repository settings)
AZURE_CREDENTIALS              # Service principal credentials (JSON)
AZURE_SUBSCRIPTION_ID          # Your Azure subscription ID
AZURE_RESOURCE_GROUP          # octopets-prod-rg
AZURE_CONTAINER_APP_NAME      # octopets-prod-api
AZURE_STATIC_WEB_APP_NAME     # octopets-prod-web
AZURE_STATIC_WEB_APPS_API_TOKEN  # From Static Web App deployment token
POSTGRES_SERVER_NAME          # octopets-prod-postgres
```

#### Creating Azure Service Principal

```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "octopets-github-actions" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/octopets-prod-rg \
  --sdk-auth

# Copy the JSON output to AZURE_CREDENTIALS secret
```

### Step 4: Configure Static Web App Deployment Token

1. Go to Azure Portal → Static Web Apps → octopets-prod-web
2. Navigate to "Manage deployment token"
3. Copy the deployment token
4. Add it as `AZURE_STATIC_WEB_APPS_API_TOKEN` secret in GitHub

### Step 5: Trigger Initial Deployment

```bash
# Push to main branch to trigger CI/CD
git add .
git commit -m "Configure Azure deployment"
git push origin main
```

## 🔧 Configuration Details

### Database Configuration

- **Server**: PostgreSQL 15 Flexible Server
- **Location**: Sweden Central
- **Tier**: Burstable (B1ms) - can be scaled up for production
- **Storage**: 32GB with auto-grow enabled
- **Backup**: 7-day retention
- **SSL**: Required (enforced)

### Container Apps Configuration

- **Environment**: Dedicated environment for isolation
- **Scaling**: 1-10 replicas based on HTTP requests
- **CPU**: 0.5 cores per replica
- **Memory**: 1.0 GiB per replica
- **Health Checks**: Liveness and readiness probes
- **Ingress**: External HTTPS with CORS configured

### Static Web App Configuration

- **Location**: West Europe (closest to Sweden Central with SWA support)
- **Tier**: Standard (includes custom domains, staging environments)
- **CDN**: Built-in global CDN
- **SSL**: Automatic HTTPS with custom domain support

## 🔐 Security Configuration

### Key Vault Secrets

All sensitive information is stored in Azure Key Vault:

- `PostgresConnectionString`: Database connection string
- `OpenAIApiKey`: OpenAI API key for pet analysis
- Additional secrets as needed

### Network Security

- PostgreSQL: Firewall rules allow Azure services only
- Container Apps: HTTPS enforcement, CORS configured
- Static Web App: Security headers configured in `staticwebapp.config.json`

### Environment Variables

Production environment variables are configured in:

- Backend: Container App environment variables
- Frontend: `.env.production` file

## 📊 Monitoring & Logging

### Application Insights

- Performance monitoring
- Error tracking
- Custom telemetry
- Dependency tracking

### Log Analytics

- Centralized logging
- Query capabilities
- Alerting rules
- Custom dashboards

### Health Checks

- Backend: `/health` endpoint
- Database: Connection monitoring
- Container Apps: Built-in health probes

## 🔄 CI/CD Pipeline

### Backend Deployment (`.github/workflows/deploy-backend.yml`)

1. Build .NET application
2. Run tests
3. Build Docker image
4. Push to Azure Container Registry
5. Update Container App
6. Run database migrations
7. Verify deployment

### Frontend Deployment (`.github/workflows/deploy-frontend.yml`)

1. Build React application
2. Run tests
3. Deploy to Static Web App
4. Configure routing and headers

## 🌍 Custom Domain Configuration

### Frontend Domain

1. Configure DNS CNAME record:
   ```
   www.octopets.com → octopets-prod-web.azurestaticapps.net
   ```

2. Add custom domain in Azure Portal:
   - Static Web Apps → Custom domains → Add
   - Verify domain ownership
   - Configure SSL certificate

### Backend API Domain (Optional)

1. Configure Container App custom domain:

   ```bash
   az containerapp hostname add \
     --hostname api.octopets.com \
     --name octopets-prod-api \
     --resource-group octopets-prod-rg
   ```

## 📈 Scaling & Performance

### Automatic Scaling

Container Apps automatically scale based on:
- HTTP requests (30 concurrent requests per replica)
- CPU utilization
- Memory usage

### Manual Scaling

```bash
# Scale Container App
az containerapp update \
  --name octopets-prod-api \
  --resource-group octopets-prod-rg \
  --min-replicas 2 \
  --max-replicas 20

# Scale PostgreSQL
az postgres flexible-server update \
  --name octopets-prod-postgres \
  --resource-group octopets-prod-rg \
  --sku-name Standard_B2s
```

### Database Performance

- Connection pooling enabled
- Optimized indexes for common queries
- Query performance monitoring

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**

   ```bash
   # Check firewall rules
   az postgres flexible-server firewall-rule list \
     --name octopets-prod-postgres \
     --resource-group octopets-prod-rg
   ```

2. **Container App Not Starting**

   ```bash
   # Check logs
   az containerapp logs show \
     --name octopets-prod-api \
     --resource-group octopets-prod-rg
   ```

3. **Static Web App Build Failed**
   - Check Node.js version in workflow
   - Verify environment variables
   - Check build logs in GitHub Actions

### Useful Commands

```bash
# View all resources
az resource list --resource-group octopets-prod-rg --output table

# Monitor Container App
az containerapp logs show --name octopets-prod-api --resource-group octopets-prod-rg --follow

# Check database status
az postgres flexible-server show --name octopets-prod-postgres --resource-group octopets-prod-rg

# Update application settings
az containerapp update --name octopets-prod-api --resource-group octopets-prod-rg --set-env-vars SETTING_NAME=value
```

## 💰 Cost Management

### Estimated Monthly Costs (Sweden Central)

- PostgreSQL Flexible Server (B1ms): ~$12-15
- Container Apps Environment: ~$0 (pay per use)
- Container Apps Compute: ~$5-20 (depends on usage)
- Static Web Apps (Standard): ~$9
- Key Vault: ~$1
- Application Insights: ~$2-10 (depends on telemetry)
- Storage/Bandwidth: ~$1-5

**Total Estimated**: $30-60/month for production workload

### Cost Optimization

1. Use Burstable tier for PostgreSQL in non-production
2. Configure Container Apps to scale to zero during low usage
3. Enable Application Insights sampling for high-traffic scenarios
4. Use Azure Cost Management for monitoring

## 📞 Support

For deployment issues:

1. Check Azure Portal for resource status
2. Review GitHub Actions logs
3. Monitor Application Insights for errors
4. Check Container App logs for runtime issues

## 🔄 Updates and Maintenance

### Regular Updates

1. Monitor security updates for base images
2. Update NuGet packages regularly
3. Review and update Node.js dependencies
4. Monitor Azure service updates

### Backup Strategy

- PostgreSQL: Automated daily backups (7-day retention)
- Application: Source code in Git
- Configuration: Infrastructure as Code (Bicep templates)

---

## 🎉 Deployment Complete!

After successful deployment, your application will be available at:

- **Frontend**: https://octopets-prod-web.azurestaticapps.net
- **Backend API**: https://octopets-prod-api.azurecontainerapps.io
- **API Documentation**: https://octopets-prod-api.azurecontainerapps.io/scalar/v1

Monitor your application through:
- **Azure Portal**: Resource monitoring and management
- **Application Insights**: Performance and error tracking
- **GitHub Actions**: Deployment pipeline monitoring

### Database Schema Summary

Your PostgreSQL database stores:

**Listings Table**:
- Venue information (name, address, contact)
- Pet policies and amenities
- Operating hours and pricing
- Location coordinates

**Reviews Table**:
- User reviews and ratings
- Review text and timestamps
- Associated listing information

**Pet Analysis Data**:
- OpenAI-powered pet analysis results
- Cached analysis for performance

All data is properly indexed for optimal query performance and includes comprehensive seed data for immediate use.