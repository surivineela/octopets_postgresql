# Octopets Azure Deployment Script (PowerShell)
# This script deploys the Octopets application to Azure using Bicep templates

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "octopets-prod-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "swedencentral"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Octopets Azure Deployment to Sweden Central..." -ForegroundColor Cyan

# Variables
$DeploymentName = "octopets-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Check if Azure CLI is installed
Write-Host "🔍 Checking Azure CLI installation..." -ForegroundColor Yellow
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Login to Azure (if not already logged in)
Write-Host "🔐 Checking Azure login status..." -ForegroundColor Yellow
try {
    $null = az account show 2>$null
    Write-Host "✅ Already logged in to Azure" -ForegroundColor Green
} catch {
    Write-Host "Please log in to Azure..." -ForegroundColor Yellow
    az login
}

# Set subscription (if provided)
if ($SubscriptionId) {
    Write-Host "📋 Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
}

# Get current subscription info
$CurrentSubscription = az account show --query "id" -o tsv
Write-Host "✅ Using subscription: $CurrentSubscription" -ForegroundColor Green

# Check if PostgreSQL is available in Sweden Central
Write-Host "🔍 Checking PostgreSQL availability in Sweden Central..." -ForegroundColor Yellow
$PostgresCheck = az provider show --namespace Microsoft.DBforPostgreSQL --query "resourceTypes[?resourceType=='flexibleServers'].locations" -o tsv | Where-Object { $_ -like "*sweden*" }

if (-not $PostgresCheck) {
    Write-Host "⚠️  PostgreSQL Flexible Server might not be available in Sweden Central" -ForegroundColor Yellow
    Write-Host "    Continuing anyway - Azure will provide the closest available region" -ForegroundColor Yellow
} else {
    Write-Host "✅ PostgreSQL is available in Sweden Central" -ForegroundColor Green
}

# Create resource group
Write-Host "📁 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Prompt for secrets
Write-Host ""
Write-Host "🔑 Please provide the following secrets:" -ForegroundColor Cyan
$DbPassword = Read-Host "Database Admin Password (min 8 chars, must contain uppercase, lowercase, numbers)" -AsSecureString
$DbPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DbPassword))

$OpenAiKey = Read-Host "OpenAI API Key (optional - press Enter to skip)" -AsSecureString  
$OpenAiKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($OpenAiKey))

# Use default key if none provided
if ([string]::IsNullOrWhiteSpace($OpenAiKeyPlain)) {
    $OpenAiKeyPlain = "your-openai-key-here"
    Write-Host "⚠️  Using placeholder OpenAI key. Update this in Key Vault after deployment." -ForegroundColor Yellow
}

# Validate password strength
if ($DbPasswordPlain.Length -lt 8) {
    Write-Host "❌ Password must be at least 8 characters long" -ForegroundColor Red
    exit 1
}

# Deploy infrastructure
Write-Host ""
Write-Host "🏗️  Deploying infrastructure..." -ForegroundColor Yellow
Write-Host "This may take 10-15 minutes..." -ForegroundColor Yellow

try {
    $DeploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file "infrastructure/main.bicep" `
        --parameters `
            location=$Location `
            environment="prod" `
            appName="octopets" `
            dbAdminLogin="octopetsadmin" `
            dbAdminPassword=$DbPasswordPlain `
            openAiApiKey=$OpenAiKeyPlain `
        --name $DeploymentName `
        --query "properties.outputs" `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Deployment failed" -ForegroundColor Red
        exit 1
    }

    # Parse outputs
    $PostgresServer = $DeploymentOutput.postgresServerName.value
    $PostgresFqdn = $DeploymentOutput.postgresFqdn.value
    $ContainerAppUrl = $DeploymentOutput.containerAppUrl.value
    $StaticWebAppUrl = $DeploymentOutput.staticWebAppUrl.value
    $KeyVaultName = $DeploymentOutput.keyVaultName.value
    $ContainerAppName = $DeploymentOutput.containerAppName.value
    $StaticWebAppName = $DeploymentOutput.staticWebAppName.value

    Write-Host "✅ Infrastructure deployment completed!" -ForegroundColor Green
} catch {
    Write-Host "❌ Infrastructure deployment failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📊 Deployment Summary:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   PostgreSQL Server: $PostgresServer" -ForegroundColor White
Write-Host "   PostgreSQL FQDN: $PostgresFqdn" -ForegroundColor White
Write-Host "   Container App: $ContainerAppName" -ForegroundColor White
Write-Host "   Container App URL: $ContainerAppUrl" -ForegroundColor White
Write-Host "   Static Web App: $StaticWebAppName" -ForegroundColor White
Write-Host "   Static Web App URL: $StaticWebAppUrl" -ForegroundColor White
Write-Host "   Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host ""

# Create GitHub repository secrets (if GitHub CLI is available)
Write-Host "🔐 Setting up GitHub secrets for CI/CD..." -ForegroundColor Yellow

try {
    gh --version | Out-Null
    
    # Check if we're in a git repository
    if (Test-Path ".git") {
        Write-Host "Setting GitHub repository secrets..." -ForegroundColor Yellow
        gh secret set AZURE_SUBSCRIPTION_ID --body $CurrentSubscription
        gh secret set AZURE_RESOURCE_GROUP --body $ResourceGroupName
        gh secret set AZURE_CONTAINER_APP_NAME --body $ContainerAppName
        gh secret set AZURE_STATIC_WEB_APP_NAME --body $StaticWebAppName
        gh secret set POSTGRES_SERVER_NAME --body $PostgresServer
        
        Write-Host "✅ GitHub secrets configured!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Not in a git repository. Please set GitHub secrets manually." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  GitHub CLI not found. Please set GitHub secrets manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 Your Application URLs:" -ForegroundColor Cyan
Write-Host "   Frontend: $StaticWebAppUrl" -ForegroundColor Green
Write-Host "   Backend API: $ContainerAppUrl" -ForegroundColor Green
Write-Host "   API Documentation: $ContainerAppUrl/scalar/v1" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Wait for container deployment to complete (~5 minutes)" -ForegroundColor White
Write-Host "2. Update OpenAI API key in Key Vault if needed" -ForegroundColor White
Write-Host "3. Configure custom domain (optional)" -ForegroundColor White
Write-Host "4. Set up GitHub Actions for CI/CD" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Useful Commands:" -ForegroundColor Cyan
Write-Host "   View logs: az containerapp logs show --name $ContainerAppName --resource-group $ResourceGroupName --follow" -ForegroundColor White
Write-Host "   Scale app: az containerapp update --name $ContainerAppName --resource-group $ResourceGroupName --min-replicas 1 --max-replicas 5" -ForegroundColor White

# Save deployment info
$DeploymentInfo = @{
    subscriptionId = $CurrentSubscription
    resourceGroup = $ResourceGroupName
    location = $Location
    postgresServer = $PostgresServer
    postgresFqdn = $PostgresFqdn
    containerAppName = $ContainerAppName
    containerAppUrl = $ContainerAppUrl
    staticWebAppName = $StaticWebAppName
    staticWebAppUrl = $StaticWebAppUrl
    keyVaultName = $KeyVaultName
    deploymentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$DeploymentInfo | ConvertTo-Json -Depth 2 | Out-File -FilePath "deployment-info.json" -Encoding UTF8
Write-Host "📄 Deployment information saved to deployment-info.json" -ForegroundColor White

# Clear sensitive variables
$DbPassword = $null
$DbPasswordPlain = $null
$OpenAiKey = $null
$OpenAiKeyPlain = $null

Write-Host ""
Write-Host "🌟 Welcome to Octopets! Your pet-friendly venue discovery app is ready!" -ForegroundColor Green