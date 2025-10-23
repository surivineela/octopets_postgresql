# 🚀 Octopets Deployment Guide

This guide provides complete instructions for deploying the Octopets application with PostgreSQL and Azure Container Apps in your own Azure environment.

## 📋 **Prerequisites**

### **Required Tools**
- **Azure CLI** (version 2.50+)
- **Docker Desktop** (for building container images)
- **Git** (for cloning the repository)
- **.NET 9.0 SDK** (for local development)
- **PowerShell** or **Bash** (depending on your platform)

### **Azure Requirements**
- **Azure Subscription** with appropriate permissions
- **Contributor** role or higher on the subscription
- **Sufficient quota** for Container Apps and PostgreSQL Flexible Server in your chosen region

### **Installation Commands**
```bash
# Install Azure CLI (if not already installed)
# Windows (PowerShell)
winget install Microsoft.AzureCLI

# macOS
brew install azure-cli

# Linux (Ubuntu/Debian)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify installations
az --version
docker --version
dotnet --version
```

---

## 🎯 **Quick Deployment (Recommended)**

### **Step 1: Clone and Setup**
```bash
# Clone the repository
git clone https://github.com/surivineela/octopets_postgresql.git
cd octopets_postgresql

# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"
```

### **Step 2: Choose Your Region**
```bash
# List available regions (optional)
az account list-locations --query "[?availabilityZoneMappings != null].name" -o table

# Common regions with Container Apps support:
# - eastus, eastus2, westus2, westus3
# - northeurope, westeurope
# - swedencentral, norwayeast
# - australiaeast, japaneast
```

### **Step 3: Deploy Infrastructure**
```bash
# Create resource group (choose your preferred region)
LOCATION="eastus"  # Change this to your preferred region
RESOURCE_GROUP="octopets-prod-rg"
APP_NAME="octopets"

az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy infrastructure (this takes 10-15 minutes)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep \
  --parameters \
    location=$LOCATION \
    environment="prod" \
    appName=$APP_NAME \
    dbAdminLogin="octopetsadmin" \
    dbAdminPassword="YourSecurePassword123!"
```

### **Step 4: Build and Push Docker Images**

#### **Backend Image**
```bash
# Get Container Registry details
REGISTRY_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name "main" \
  --query "properties.outputs.containerRegistryName.value" -o tsv)

REGISTRY_SERVER=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name "main" \
  --query "properties.outputs.containerRegistryLoginServer.value" -o tsv)

# Login to Container Registry
az acr login --name $REGISTRY_NAME

# Build and push backend
docker build --no-cache -t $REGISTRY_SERVER/octopets-backend:latest -f backend/Dockerfile .
docker push $REGISTRY_SERVER/octopets-backend:latest
```

#### **Frontend Image**
```bash
# Build and push frontend
docker build --no-cache -t $REGISTRY_SERVER/octopets-frontend:latest -f frontend/Dockerfile .
docker push $REGISTRY_SERVER/octopets-frontend:latest
```

### **Step 5: Deploy Container Apps**
```bash
# Deploy backend
az containerapp create \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --environment "${APP_NAME}-prod-env" \
  --image "$REGISTRY_SERVER/octopets-backend:latest" \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 10 \
  --cpu 0.5 \
  --memory 1Gi \
  --registry-server $REGISTRY_SERVER \
  --env-vars \
    ASPNETCORE_ENVIRONMENT="Production" \
    ConnectionStrings__octopetsdb=secretref:postgres-connection

# Deploy frontend (get backend URL first)
BACKEND_URL=$(az containerapp show \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --query "properties.configuration.ingress.fqdn" -o tsv)

az containerapp create \
  --name "${APP_NAME}-prod-web" \
  --resource-group $RESOURCE_GROUP \
  --environment "${APP_NAME}-prod-env" \
  --image "$REGISTRY_SERVER/octopets-frontend:latest" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 5 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --registry-server $REGISTRY_SERVER
```

### **Step 6: Verify Deployment**
```bash
# Get application URLs
BACKEND_URL="https://$(az containerapp show --name "${APP_NAME}-prod-api" --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)"
FRONTEND_URL="https://$(az containerapp show --name "${APP_NAME}-prod-web" --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)"

echo "🎉 Deployment Complete!"
echo "Backend API: $BACKEND_URL"
echo "Frontend App: $FRONTEND_URL"

# Test endpoints
curl "$BACKEND_URL/health"
curl "$BACKEND_URL/api/listings"
```

---

## 🔧 **Manual Step-by-Step Deployment**

### **Step 1: Infrastructure Setup**

#### **1.1 Create Resource Group**
```bash
# Set your variables
LOCATION="eastus"                    # Change to your preferred region
RESOURCE_GROUP="octopets-prod-rg"    # Change if desired
APP_NAME="octopets"                  # Change if desired
DB_ADMIN_USER="octopetsadmin"        # Change if desired
DB_ADMIN_PASSWORD="YourSecurePassword123!"  # CHANGE THIS!

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

#### **1.2 Deploy PostgreSQL Flexible Server**
```bash
# Deploy PostgreSQL (takes 5-10 minutes)
az postgres flexible-server create \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $DB_ADMIN_USER \
  --admin-password $DB_ADMIN_PASSWORD \
  --sku-name Standard_B2s \
  --storage-size 32 \
  --version 15
```

#### **1.3 Create Container Registry**
```bash
# Create Container Registry
az acr create \
  --name "${APP_NAME}prodregistry" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Basic \
  --admin-enabled true
```

#### **1.4 Create Container Apps Environment**
```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name "${APP_NAME}-prod-logs" \
  --location $LOCATION

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name "${APP_NAME}-prod-logs" \
  --query "customerId" -o tsv)

# Create Container Apps environment
az containerapp env create \
  --name "${APP_NAME}-prod-env" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --logs-workspace-id $WORKSPACE_ID
```

### **Step 2: Build and Deploy Applications**

#### **2.1 Prepare Docker Images**
```bash
# Login to Container Registry
az acr login --name "${APP_NAME}prodregistry"

# Build backend image
docker build --no-cache -t "${APP_NAME}prodregistry.azurecr.io/octopets-backend:latest" -f backend/Dockerfile .
docker push "${APP_NAME}prodregistry.azurecr.io/octopets-backend:latest"

# Build frontend image  
docker build --no-cache -t "${APP_NAME}prodregistry.azurecr.io/octopets-frontend:latest" -f frontend/Dockerfile .
docker push "${APP_NAME}prodregistry.azurecr.io/octopets-frontend:latest"
```

#### **2.2 Configure Database Connection**
```bash
# Create connection string secret
CONNECTION_STRING="Host=${APP_NAME}-prod-postgres.postgres.database.azure.com;Database=octopetsdb;Username=${DB_ADMIN_USER};Password=${DB_ADMIN_PASSWORD};SSL Mode=Require"

az containerapp env secret set \
  --name "${APP_NAME}-prod-env" \
  --resource-group $RESOURCE_GROUP \
  --secrets postgres-connection="$CONNECTION_STRING"
```

#### **2.3 Deploy Backend Container App**
```bash
az containerapp create \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --environment "${APP_NAME}-prod-env" \
  --image "${APP_NAME}prodregistry.azurecr.io/octopets-backend:latest" \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 10 \
  --cpu 0.5 \
  --memory 1Gi \
  --registry-server "${APP_NAME}prodregistry.azurecr.io" \
  --env-vars \
    ASPNETCORE_ENVIRONMENT="Production" \
    ConnectionStrings__octopetsdb=secretref:postgres-connection
```

#### **2.4 Deploy Frontend Container App**
```bash
az containerapp create \
  --name "${APP_NAME}-prod-web" \
  --resource-group $RESOURCE_GROUP \
  --environment "${APP_NAME}-prod-env" \
  --image "${APP_NAME}prodregistry.azurecr.io/octopets-frontend:latest" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 5 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --registry-server "${APP_NAME}prodregistry.azurecr.io"
```

---

## 🔧 **Configuration Options**

### **Environment Variables**
You can customize the deployment by modifying these variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCATION` | `eastus` | Azure region for deployment |
| `RESOURCE_GROUP` | `octopets-prod-rg` | Resource group name |
| `APP_NAME` | `octopets` | Application name prefix |
| `DB_ADMIN_USER` | `octopetsadmin` | PostgreSQL admin username |
| `DB_ADMIN_PASSWORD` | *(required)* | PostgreSQL admin password |

### **PostgreSQL Configuration**
```bash
# Different PostgreSQL SKUs (adjust for your needs)
# Development: Standard_B1ms (1 vCore, 2GB RAM)
# Production: Standard_D2s_v3 (2 vCore, 8GB RAM)
# High Performance: Standard_D4s_v3 (4 vCore, 16GB RAM)

az postgres flexible-server create \
  --sku-name Standard_D2s_v3 \  # Change this
  --storage-size 128 \           # Increase storage
  --storage-auto-grow Enabled    # Enable auto-grow
```

### **Container Apps Scaling**
```bash
# Adjust scaling parameters
az containerapp update \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 2 \
  --max-replicas 20 \
  --cpu 1.0 \
  --memory 2Gi
```

---

## 🌐 **Network and Security Configuration**

### **Database Firewall Rules**
```bash
# Allow Container Apps to access PostgreSQL
CONTAINER_APP_OUTBOUND_IP=$(az containerapp env show \
  --name "${APP_NAME}-prod-env" \
  --resource-group $RESOURCE_GROUP \
  --query "properties.staticIp" -o tsv)

az postgres flexible-server firewall-rule create \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP \
  --rule-name "AllowContainerApps" \
  --start-ip-address $CONTAINER_APP_OUTBOUND_IP \
  --end-ip-address $CONTAINER_APP_OUTBOUND_IP
```

### **Custom Domain (Optional)**
```bash
# Add custom domain to Container App
az containerapp hostname add \
  --hostname "api.yourdomain.com" \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP

# Bind SSL certificate
az containerapp ssl upload \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --certificate-file ./path/to/certificate.pfx \
  --certificate-password "cert-password"
```

---

## 🔍 **Verification and Testing**

### **Health Checks**
```bash
# Get application URLs
BACKEND_URL="https://$(az containerapp show --name "${APP_NAME}-prod-api" --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)"
FRONTEND_URL="https://$(az containerapp show --name "${APP_NAME}-prod-web" --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)"

# Test backend health
curl "$BACKEND_URL/health"
curl "$BACKEND_URL/"
curl "$BACKEND_URL/api/listings"

# Test frontend
curl "$FRONTEND_URL"
```

### **Database Connection Test**
```bash
# Test PostgreSQL connectivity
az postgres flexible-server connect \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP \
  --admin-user $DB_ADMIN_USER \
  --admin-password $DB_ADMIN_PASSWORD \
  --database-name octopetsdb
```

### **Application Logs**
```bash
# View backend logs
az containerapp logs show \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --follow

# View frontend logs
az containerapp logs show \
  --name "${APP_NAME}-prod-web" \
  --resource-group $RESOURCE_GROUP \
  --follow
```

---

## 🚨 **Implementing Breaking Scenarios**

After successful deployment, you can implement the breaking scenarios from `BREAKING_SCENARIOS_GUIDE.md`:

### **Quick Test: Database Server Stop**
```bash
# Break: Stop PostgreSQL server
az postgres flexible-server stop \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP

# Verify impact: Should return 503
curl "$BACKEND_URL/health"

# Fix: Start PostgreSQL server
az postgres flexible-server start \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP

# Verify fix: Should return 200
curl "$BACKEND_URL/health"
```

---

## 🧹 **Cleanup (Optional)**

### **Remove All Resources**
```bash
# Delete entire resource group (WARNING: This removes everything!)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

### **Remove Individual Components**
```bash
# Stop and delete Container Apps only
az containerapp delete --name "${APP_NAME}-prod-api" --resource-group $RESOURCE_GROUP --yes
az containerapp delete --name "${APP_NAME}-prod-web" --resource-group $RESOURCE_GROUP --yes

# Keep PostgreSQL and other infrastructure intact
```

---

## 📊 **Cost Estimation**

### **Monthly Cost Breakdown (East US region)**
| Component | Configuration | Est. Monthly Cost |
|-----------|---------------|-------------------|
| PostgreSQL Flexible Server | Standard_B2s | ~$50-70 |
| Container Apps (Backend) | 0.5 CPU, 1GB RAM | ~$25-35 |
| Container Apps (Frontend) | 0.25 CPU, 0.5GB RAM | ~$15-20 |
| Container Registry | Basic SKU | ~$5 |
| Log Analytics | 5GB/month | ~$10-15 |
| **Total** | | **~$105-145/month** |

### **Cost Optimization Tips**
- Use **Burstable** PostgreSQL SKUs for development
- Set **minimum replicas to 0** for non-production environments
- Use **shared** Container Apps environments
- Enable **auto-pause** for PostgreSQL during off-hours

---

## 🆘 **Troubleshooting**

### **Common Issues**

#### **1. Container Registry Permission Denied**
```bash
# Solution: Enable admin user and get credentials
az acr update --name "${APP_NAME}prodregistry" --admin-enabled true
az acr credential show --name "${APP_NAME}prodregistry"
```

#### **2. PostgreSQL Connection Timeout**
```bash
# Solution: Check firewall rules
az postgres flexible-server firewall-rule list \
  --name "${APP_NAME}-prod-postgres" \
  --resource-group $RESOURCE_GROUP
```

#### **3. Container App Health Check Failures**
```bash
# Solution: Check container logs
az containerapp logs show \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP
```

#### **4. DNS Resolution Issues**
```bash
# Solution: Verify Container App ingress configuration
az containerapp show \
  --name "${APP_NAME}-prod-api" \
  --resource-group $RESOURCE_GROUP \
  --query "properties.configuration.ingress"
```

---

## 📚 **Additional Resources**

- **Azure Container Apps Documentation**: https://docs.microsoft.com/en-us/azure/container-apps/
- **PostgreSQL Flexible Server**: https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/
- **Breaking Scenarios Guide**: [BREAKING_SCENARIOS_GUIDE.md](./BREAKING_SCENARIOS_GUIDE.md)
- **Azure CLI Reference**: https://docs.microsoft.com/en-us/cli/azure/

---

## 🎉 **Success!**

After completing this guide, you should have:
- ✅ **Working Octopets application** deployed in your Azure environment
- ✅ **PostgreSQL database** with proper connectivity
- ✅ **Container Apps** running frontend and backend
- ✅ **Monitoring and logging** configured
- ✅ **Ready for SRE testing** with breaking scenarios

**Frontend URL**: Access your application
**Backend API**: Test endpoints and health checks
**Breaking scenarios**: Ready for implementation and SRE training

*Happy deploying! 🚀*