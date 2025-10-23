# Simple Octopets Deployment Script
param(
    [string]$ResourceGroupName = "octopets-prod-rg",
    [string]$Location = "swedencentral"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Octopets Azure Deployment..." -ForegroundColor Cyan

# Check Azure CLI
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI is available" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Check login
try {
    $null = az account show 2>$null
    Write-Host "✅ Already logged in to Azure" -ForegroundColor Green
} catch {
    Write-Host "Logging in to Azure..." -ForegroundColor Yellow
    az login
}

# Get subscription
$CurrentSubscription = az account show --query "id" -o tsv
Write-Host "✅ Using subscription: $CurrentSubscription" -ForegroundColor Green

# Create resource group
Write-Host "📁 Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Get secrets
Write-Host ""
Write-Host "Please provide secrets:" -ForegroundColor Cyan
$DbPassword = Read-Host "Database Password (min 8 chars)" -AsSecureString
$DbPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DbPassword))

$OpenAiKey = Read-Host "OpenAI API Key (optional)" -AsSecureString
$OpenAiKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($OpenAiKey))

if ([string]::IsNullOrWhiteSpace($OpenAiKeyPlain)) {
    $OpenAiKeyPlain = "placeholder-key"
}

# Deploy
Write-Host ""
Write-Host "🏗️ Deploying infrastructure..." -ForegroundColor Yellow

$DeploymentName = "octopets-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infrastructure/main.bicep" `
    --parameters location=$Location environment="prod" appName="octopets" dbAdminLogin="octopetsadmin" dbAdminPassword="$DbPasswordPlain" openAiApiKey="$OpenAiKeyPlain" `
    --name $DeploymentName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment completed!" -ForegroundColor Green
    
    # Get outputs
    $Outputs = az deployment group show --resource-group $ResourceGroupName --name $DeploymentName --query "properties.outputs" --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "🔗 Your URLs:" -ForegroundColor Cyan
    Write-Host "Frontend: $($Outputs.staticWebAppUrl.value)" -ForegroundColor Green
    Write-Host "Backend: $($Outputs.containerAppUrl.value)" -ForegroundColor Green
} else {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
}

# Clear secrets
$DbPassword = $null
$DbPasswordPlain = $null
$OpenAiKey = $null
$OpenAiKeyPlain = $null