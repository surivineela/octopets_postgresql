# 🚀 Octopets Azure Deployment Guide

This guide will help you deploy the Octopets application to Azure using Sweden Central region for optimal PostgreSQL availability.

## 🏗️ Infrastructure Overview

The deployment creates the following Azure resources in Sweden Central region:

- **Azure Database for PostgreSQL Flexible Server** - PostgreSQL 15 database
- **Azure Container Apps Environment** - Managed environment for containers
- **Azure Container Apps** - Frontend (React) and Backend (.NET) apps
- **Azure Key Vault** - Secure secrets management
- **Azure Container Registry** - Docker image storage
- **Application Insights** - Application monitoring and telemetry
- **Log Analytics Workspace** - Centralized logging

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

3. **Docker** installed (for building container images)

4. **Node.js 18+** and **npm** (for local frontend development, optional)

## 🚀 Deployment Steps

### Step 1: Clone and Prepare Repository

```bash
# Clone your repository
git clone https://github.com/surivineela/octopets_postgresql.git
cd octopets_postgresql

# Ensure you're on the main branch
git checkout main
```

### Step 2: Deploy Infrastructure

```bash
# Create resource group
az group create --name octopets-prod-rg --location swedencentral

# Deploy infrastructure using Bicep
az deployment group create \
  --resource-group octopets-prod-rg \
  --template-file infrastructure/main.bicep \
  --parameters location=swedencentral \
               environment=prod \
               appName=octopets \
               dbAdminLogin=octopetsadmin \
               dbAdminPassword='YourSecurePassword123!'

# Note the output values for backend and frontend URLs
```

### Step 3: Build and Push Container Images

```bash
# Login to Azure Container Registry
az acr login --name octopetsprodregistry

# Build and push backend image
cd backend
docker build -f Dockerfile -t octopetsprodregistry.azurecr.io/octopets-backend:latest ..
docker push octopetsprodregistry.azurecr.io/octopets-backend:latest

# Build and push frontend image
cd ../frontend
docker build -t octopetsprodregistry.azurecr.io/octopets-frontend:latest \
  --build-arg REACT_APP_USE_MOCK_DATA=false \
  --build-arg REACT_APP_API_BASE_URL=https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/api \
  .
docker push octopetsprodregistry.azurecr.io/octopets-frontend:latest
```

### Step 4: Update Container Apps with Images

```bash
# Update backend container app
az containerapp update \
  --name octopets-prod-api \
  --resource-group octopets-prod-rg \
  --image octopetsprodregistry.azurecr.io/octopets-backend:latest

# Update frontend container app
az containerapp update \
  --name octopets-prod-web \
  --resource-group octopets-prod-rg \
  --image octopetsprodregistry.azurecr.io/octopets-frontend:latest
```

### Step 5: Seed the Database

```bash
# Add firewall rule for your IP
az postgres flexible-server firewall-rule create \
  --resource-group octopets-prod-rg \
  --name octopets-prod-postgres \
  --rule-name AllowMyIP \
  --start-ip-address YOUR_IP_ADDRESS \
  --end-ip-address YOUR_IP_ADDRESS

# Run seed script (requires psql or use seed-database.sql file)
# See seed-database.sql in the repository root
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

**Backend (octopets-prod-api):**
- **Scaling**: 1-10 replicas based on HTTP requests
- **CPU**: 0.5 cores per replica
- **Memory**: 1.0 GiB per replica
- **Health Checks**: `/health` and `/health/ready` endpoints
- **Ingress**: External HTTPS with CORS configured

**Frontend (octopets-prod-web):**
- **Scaling**: 1-5 replicas based on HTTP requests
- **CPU**: 0.25 cores per replica
- **Memory**: 0.5 GiB per replica
- **Ingress**: External HTTPS
- **Build Args**: REACT_APP_USE_MOCK_DATA, REACT_APP_API_BASE_URL

## 🔐 Security Configuration

### Key Vault Secrets

All sensitive information is stored in Azure Key Vault:

- `PostgresConnectionString`: Database connection string
- Container Registry credentials
- Application Insights connection strings

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

## 🔄 Manual Deployment Workflow

This application uses manual Docker builds and Azure CLI commands for deployment:

1. **Build Docker Images**: Build frontend and backend containers locally
2. **Push to ACR**: Push images to Azure Container Registry
3. **Update Container Apps**: Deploy updated images to Container Apps
4. **Database Migrations**: Backend automatically runs migrations on startup
5. **Photo Updates**: Backend automatically updates listing photos on startup

## 🌍 Custom Domain Configuration (Optional)

### Frontend Domain

Configure Container App custom domain:

```bash
az containerapp hostname add \
  --hostname www.octopets.com \
  --name octopets-prod-web \
  --resource-group octopets-prod-rg
```

### Backend API Domain

Configure Container App custom domain:

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

## 🎉 Deployment Complete

After successful deployment, your application will be available at:

- **Frontend**: <https://octopets-prod-web.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io>
- **Backend API**: <https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io>
- **API Health**: <https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health>
- **API Listings**: <https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/api/listings>

Monitor your application through:

- **Azure Portal**: Resource monitoring and management
- **Application Insights**: Performance and error tracking
- **Container App Logs**: Real-time application logs

### Database Schema Summary

Your PostgreSQL database stores:

**Listings Table**:

- Venue information (name, address, contact)
- Pet policies and amenities
- Photos (filenames, path added by frontend)
- Rating and location information

**Reviews Table**:

- User reviews and ratings
- Review text and timestamps
- Associated listing information

**Seed Data**:

- 6 demo listings with proper image references
- 13 reviews across all listings
- Auto-populated via backend DataInitializer or seed-database.sql

All data is properly indexed for optimal query performance and includes comprehensive seed data for immediate use.
