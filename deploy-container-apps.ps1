# Direct Azure Container Apps Deployment Script (PowerShell)
# Replaces Aspire azure.yaml deployment

param(
    [string]$ResourceGroup = "rg-octopets",
    [string]$Location = "East US",
    [string]$EnvironmentName = "octopets-env"
)

# Configuration
$BackendAppName = "octopets-backend"
$FrontendAppName = "octopets-frontend" 
$AcrName = "acroctopets$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "🚀 Starting direct Azure Container Apps deployment..." -ForegroundColor Blue

# Check if logged in to Azure
try {
    az account show | Out-Null
    Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
} catch {
    Write-Host "❌ Please login to Azure CLI first: az login" -ForegroundColor Red
    exit 1
}

# Create resource group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output table

# Create Container Registry
Write-Host "📋 Creating Azure Container Registry..." -ForegroundColor Yellow
az acr create `
    --resource-group $ResourceGroup `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true `
    --output table

# Get ACR credentials
$AcrServer = az acr show --name $AcrName --resource-group $ResourceGroup --query loginServer --output tsv
$AcrUsername = az acr credential show --name $AcrName --resource-group $ResourceGroup --query username --output tsv
$AcrPassword = az acr credential show --name $AcrName --resource-group $ResourceGroup --query passwords[0].value --output tsv

Write-Host "✅ Container Registry: $AcrServer" -ForegroundColor Green

# Create Container Apps Environment
Write-Host "🌍 Creating Container Apps Environment..." -ForegroundColor Yellow
az containerapp env create `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --location $Location `
    --output table

# Build and push backend image
Write-Host "🔨 Building and pushing backend image..." -ForegroundColor Yellow
az acr build `
    --registry $AcrName `
    --image "octopets/backend:latest" `
    --file "./backend/Dockerfile" `
    "./backend"

# Build and push frontend image
Write-Host "🔨 Building and pushing frontend image..." -ForegroundColor Yellow
az acr build `
    --registry $AcrName `
    --image "octopets/frontend:latest" `
    --file "./frontend/Dockerfile" `
    "./frontend"

# Deploy backend container app
Write-Host "🚀 Deploying backend container app..." -ForegroundColor Yellow
az containerapp create `
    --name $BackendAppName `
    --resource-group $ResourceGroup `
    --environment $EnvironmentName `
    --image "$AcrServer/octopets/backend:latest" `
    --registry-server $AcrServer `
    --registry-username $AcrUsername `
    --registry-password $AcrPassword `
    --target-port 8080 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 3 `
    --cpu 0.5 `
    --memory 1.0Gi `
    --env-vars `
        "ASPNETCORE_ENVIRONMENT=Production" `
        "OpenAI__ApiKey=$env:OPENAI_API_KEY" `
        "EnableSwagger=true" `
    --output table

# Get backend URL
$BackendUrl = az containerapp show `
    --name $BackendAppName `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn `
    --output tsv

Write-Host "✅ Backend deployed at: https://$BackendUrl" -ForegroundColor Green

# Deploy frontend container app
Write-Host "🚀 Deploying frontend container app..." -ForegroundColor Yellow
az containerapp create `
    --name $FrontendAppName `
    --resource-group $ResourceGroup `
    --environment $EnvironmentName `
    --image "$AcrServer/octopets/frontend:latest" `
    --registry-server $AcrServer `
    --registry-username $AcrUsername `
    --registry-password $AcrPassword `
    --target-port 80 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 5 `
    --cpu 0.25 `
    --memory 0.5Gi `
    --env-vars `
        "REACT_APP_API_BASE_URL=https://$BackendUrl/api" `
        "REACT_APP_USE_MOCK_DATA=false" `
    --output table

# Get frontend URL
$FrontendUrl = az containerapp show `
    --name $FrontendAppName `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn `
    --output tsv

Write-Host "🎉 Deployment complete!" -ForegroundColor Green
Write-Host "📱 Frontend: https://$FrontendUrl" -ForegroundColor Blue
Write-Host "🔧 Backend API: https://$BackendUrl" -ForegroundColor Blue
Write-Host "📊 Swagger UI: https://$BackendUrl/scalar/v1" -ForegroundColor Blue

# Save deployment info
$DeploymentInfo = @{
    resourceGroup = $ResourceGroup
    location = $Location
    environment = $EnvironmentName
    containerRegistry = $AcrServer
    frontend = @{
        name = $FrontendAppName
        url = "https://$FrontendUrl"
    }
    backend = @{
        name = $BackendAppName
        url = "https://$BackendUrl"
    }
    deployedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
} | ConvertTo-Json -Depth 3

$DeploymentInfo | Out-File -FilePath "deployment-info.json" -Encoding UTF8

Write-Host "💾 Deployment info saved to deployment-info.json" -ForegroundColor Green