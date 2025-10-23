#!/bin/bash

# Octopets Azure Deployment Script
# This script deploys the Octopets application to Azure using Bicep templates

set -e

echo "🚀 Starting Octopets Azure Deployment to Sweden Central..."

# Variables
SUBSCRIPTION_ID=""  # Add your subscription ID here
RESOURCE_GROUP="octopets-prod-rg"
LOCATION="swedencentral"
DEPLOYMENT_NAME="octopets-deployment-$(date +%Y%m%d-%H%M%S)"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure (if not already logged in)
echo "🔐 Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please log in to Azure..."
    az login
fi

# Set subscription (if provided)
if [ ! -z "$SUBSCRIPTION_ID" ]; then
    echo "📋 Setting subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Get current subscription info
CURRENT_SUBSCRIPTION=$(az account show --query "id" -o tsv)
echo "✅ Using subscription: $CURRENT_SUBSCRIPTION"

# Check if PostgreSQL is available in Sweden Central
echo "🔍 Checking PostgreSQL availability in Sweden Central..."
POSTGRES_AVAILABLE=$(az provider show --namespace Microsoft.DBforPostgreSQL --query "resourceTypes[?resourceType=='flexibleServers'].locations" -o tsv | grep -i sweden || echo "")

if [ -z "$POSTGRES_AVAILABLE" ]; then
    echo "⚠️  PostgreSQL Flexible Server might not be available in Sweden Central"
    echo "    Continuing anyway - Azure will provide the closest available region"
else
    echo "✅ PostgreSQL is available in Sweden Central"
fi

# Create resource group
echo "📁 Creating resource group: $RESOURCE_GROUP"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

# Prompt for secrets
echo "🔑 Please provide the following secrets:"
read -s -p "Database Admin Password (min 8 chars, must contain uppercase, lowercase, numbers): " DB_PASSWORD
echo
read -s -p "OpenAI API Key: " OPENAI_KEY
echo

# Validate password strength
if [[ ${#DB_PASSWORD} -lt 8 ]]; then
    echo "❌ Password must be at least 8 characters long"
    exit 1
fi

# Deploy infrastructure
echo "🏗️  Deploying infrastructure..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "infrastructure/main.bicep" \
    --parameters \
        location="$LOCATION" \
        environment="prod" \
        appName="octopets" \
        dbAdminLogin="octopetsadmin" \
        dbAdminPassword="$DB_PASSWORD" \
        openAiApiKey="$OPENAI_KEY" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs" \
    --output json)

# Parse outputs
POSTGRES_SERVER=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.postgresServerName.value')
POSTGRES_FQDN=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.postgresFqdn.value')
CONTAINER_APP_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.containerAppUrl.value')
STATIC_WEB_APP_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.staticWebAppUrl.value')
KEY_VAULT_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.keyVaultName.value')
CONTAINER_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.containerAppName.value')
STATIC_WEB_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.staticWebAppName.value')

echo "✅ Infrastructure deployment completed!"
echo ""
echo "📊 Deployment Summary:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   PostgreSQL Server: $POSTGRES_SERVER"
echo "   PostgreSQL FQDN: $POSTGRES_FQDN"
echo "   Container App: $CONTAINER_APP_NAME"
echo "   Container App URL: $CONTAINER_APP_URL"
echo "   Static Web App: $STATIC_WEB_APP_NAME"
echo "   Static Web App URL: $STATIC_WEB_APP_URL"
echo "   Key Vault: $KEY_VAULT_NAME"
echo ""

# Create GitHub repository secrets (if GitHub CLI is available)
if command -v gh &> /dev/null; then
    echo "🔐 Setting up GitHub secrets for CI/CD..."
    
    # Check if we're in a git repository
    if git rev-parse --is-inside-work-tree &> /dev/null; then
        gh secret set AZURE_SUBSCRIPTION_ID --body "$CURRENT_SUBSCRIPTION"
        gh secret set AZURE_RESOURCE_GROUP --body "$RESOURCE_GROUP"
        gh secret set AZURE_CONTAINER_APP_NAME --body "$CONTAINER_APP_NAME"
        gh secret set AZURE_STATIC_WEB_APP_NAME --body "$STATIC_WEB_APP_NAME"
        gh secret set POSTGRES_SERVER_NAME --body "$POSTGRES_SERVER"
        
        echo "✅ GitHub secrets configured!"
    else
        echo "⚠️  Not in a git repository. Please set GitHub secrets manually."
    fi
else
    echo "⚠️  GitHub CLI not found. Please set GitHub secrets manually."
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "🔧 Next Steps:"
echo "1. Configure GitHub Actions for CI/CD (see .github/workflows/)"
echo "2. Update your domain DNS to point to the Static Web App"
echo "3. Configure custom domain in Azure Static Web Apps"
echo "4. Run database migrations: dotnet ef database update --connection \"$CONNECTION_STRING\""
echo ""
echo "🔗 Useful Commands:"
echo "   View logs: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
echo "   Update container: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image YOUR_IMAGE"
echo "   Scale app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 5"

# Save deployment info
cat > deployment-info.json << EOF
{
  "subscriptionId": "$CURRENT_SUBSCRIPTION",
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "postgresServer": "$POSTGRES_SERVER",
  "postgresFqdn": "$POSTGRES_FQDN",
  "containerAppName": "$CONTAINER_APP_NAME",
  "containerAppUrl": "$CONTAINER_APP_URL",
  "staticWebAppName": "$STATIC_WEB_APP_NAME",
  "staticWebAppUrl": "$STATIC_WEB_APP_URL",
  "keyVaultName": "$KEY_VAULT_NAME",
  "deploymentDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "📄 Deployment information saved to deployment-info.json"