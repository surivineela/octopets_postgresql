#!/bin/bash
# Direct Azure Container Apps Deployment Script
# Replaces Aspire azure.yaml deployment

set -euo pipefail

# Configuration
RESOURCE_GROUP="rg-octopets"
LOCATION="East US"
ENVIRONMENT_NAME="octopets-env"
ACR_NAME="acroctopets$(date +%s)"
BACKEND_APP_NAME="octopets-backend"
FRONTEND_APP_NAME="octopets-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting direct Azure Container Apps deployment...${NC}"

# Check if logged in to Azure
if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}❌ Please login to Azure CLI first: az login${NC}"
    exit 1
fi

# Create resource group
echo -e "${YELLOW}📦 Creating resource group...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

# Create Container Registry
echo -e "${YELLOW}📋 Creating Azure Container Registry...${NC}"
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true \
    --output table

# Get ACR credentials
ACR_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query passwords[0].value --output tsv)

echo -e "${GREEN}✅ Container Registry: $ACR_SERVER${NC}"

# Create Container Apps Environment
echo -e "${YELLOW}🌍 Creating Container Apps Environment...${NC}"
az containerapp env create \
    --name "$ENVIRONMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output table

# Build and push backend image
echo -e "${YELLOW}🔨 Building and pushing backend image...${NC}"
az acr build \
    --registry "$ACR_NAME" \
    --image "octopets/backend:latest" \
    --file "./backend/Dockerfile" \
    "./backend"

# Build and push frontend image
echo -e "${YELLOW}🔨 Building and pushing frontend image...${NC}"
az acr build \
    --registry "$ACR_NAME" \
    --image "octopets/frontend:latest" \
    --file "./frontend/Dockerfile" \
    "./frontend"

# Deploy backend container app
echo -e "${YELLOW}🚀 Deploying backend container app...${NC}"
az containerapp create \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$ACR_SERVER/octopets/backend:latest" \
    --registry-server "$ACR_SERVER" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1.0Gi \
    --env-vars \
        ASPNETCORE_ENVIRONMENT=Production \
        OpenAI__ApiKey="$OPENAI_API_KEY" \
        EnableSwagger=true \
    --output table

# Get backend URL
BACKEND_URL=$(az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo -e "${GREEN}✅ Backend deployed at: https://$BACKEND_URL${NC}"

# Deploy frontend container app
echo -e "${YELLOW}🚀 Deploying frontend container app...${NC}"
az containerapp create \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$ACR_SERVER/octopets/frontend:latest" \
    --registry-server "$ACR_SERVER" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 80 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 5 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --env-vars \
        REACT_APP_API_BASE_URL="https://$BACKEND_URL/api" \
        REACT_APP_USE_MOCK_DATA=false \
    --output table

# Get frontend URL
FRONTEND_URL=$(az containerapp show \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo -e "${BLUE}📱 Frontend: https://$FRONTEND_URL${NC}"
echo -e "${BLUE}🔧 Backend API: https://$BACKEND_URL${NC}"
echo -e "${BLUE}📊 Swagger UI: https://$BACKEND_URL/scalar/v1${NC}"

# Save deployment info
cat > deployment-info.json << EOF
{
    "resourceGroup": "$RESOURCE_GROUP",
    "location": "$LOCATION",
    "environment": "$ENVIRONMENT_NAME",
    "containerRegistry": "$ACR_SERVER",
    "frontend": {
        "name": "$FRONTEND_APP_NAME",
        "url": "https://$FRONTEND_URL"
    },
    "backend": {
        "name": "$BACKEND_APP_NAME", 
        "url": "https://$BACKEND_URL"
    },
    "deployedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo -e "${GREEN}💾 Deployment info saved to deployment-info.json${NC}"