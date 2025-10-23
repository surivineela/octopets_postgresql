#!/usr/bin/env pwsh

# Octopets Deployment Script
# This script helps deploy the Octopets application with OpenAI integration to Azure

param(
    [string]$EnvironmentName = "octopets-prod",
    [string]$Location = "eastus2",
    [string]$OpenAIApiKey = "",
    [switch]$SkipOpenAIKey = $false
)

Write-Host "🐾 Octopets Deployment Script" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Check prerequisites
Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Yellow

# Check if azd is installed
if (!(Get-Command "azd" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure Developer CLI (azd) is not installed." -ForegroundColor Red
    Write-Host "Please install it from: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd" -ForegroundColor Red
    exit 1
}

# Check if we're in the right directory
if (!(Test-Path "Octopets.AppHost.csproj")) {
    Write-Host "❌ Please run this script from the apphost directory" -ForegroundColor Red
    Write-Host "Current directory: $(Get-Location)" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Prerequisites check passed" -ForegroundColor Green

# Get OpenAI API key if not provided
if (!$SkipOpenAIKey -and [string]::IsNullOrEmpty($OpenAIApiKey)) {
    Write-Host "`n🔑 OpenAI API Key Configuration" -ForegroundColor Yellow
    Write-Host "You need an OpenAI API key for the pet analysis features." -ForegroundColor White
    Write-Host "You can get one at: https://platform.openai.com/" -ForegroundColor White
    
    $OpenAIApiKey = Read-Host -Prompt "Enter your OpenAI API key (or press Enter to skip)"
    
    if ([string]::IsNullOrEmpty($OpenAIApiKey)) {
        Write-Host "⚠️  Skipping OpenAI configuration. You can set this up later in Azure Portal." -ForegroundColor Yellow
        $SkipOpenAIKey = $true
    }
}

# Initialize azd if not already done
Write-Host "`n🚀 Initializing Azure Developer CLI..." -ForegroundColor Yellow

if (!(Test-Path ".azure")) {
    Write-Host "Initializing azd environment..." -ForegroundColor White
    azd init --environment $EnvironmentName --location $Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to initialize azd environment" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ azd environment already initialized" -ForegroundColor Green
}

# Set environment variables
Write-Host "`n⚙️  Configuring environment..." -ForegroundColor Yellow

# Create or update .env file
$envContent = @"
AZURE_ENV_NAME=$EnvironmentName
AZURE_LOCATION=$Location
REACT_APP_USE_MOCK_DATA=false
"@

if (!$SkipOpenAIKey) {
    $envContent += "`nOPENAI_API_KEY=$OpenAIApiKey"
}

$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "✅ Environment configuration updated" -ForegroundColor Green

# Login to Azure
Write-Host "`n🔐 Azure Authentication..." -ForegroundColor Yellow
azd auth login

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to authenticate with Azure" -ForegroundColor Red
    exit 1
}

# Deploy the application
Write-Host "`n🚀 Deploying Octopets to Azure..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor White

azd up

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}

# Success message
Write-Host "`n🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Get and display application URLs
Write-Host "`n📍 Getting application URLs..." -ForegroundColor Yellow
azd show --output table

if (!$SkipOpenAIKey) {
    Write-Host "`n✅ OpenAI integration is configured and ready to use!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Post-deployment steps:" -ForegroundColor Yellow
    Write-Host "1. Go to Azure Portal" -ForegroundColor White
    Write-Host "2. Find your Container App (octopets-backend)" -ForegroundColor White
    Write-Host "3. Add environment variable: OpenAI__ApiKey = your-openai-api-key" -ForegroundColor White
    Write-Host "4. Restart the container app" -ForegroundColor White
}

Write-Host "`n🧪 Test your deployment:" -ForegroundColor Yellow
Write-Host "1. Open the frontend URL to access the web app" -ForegroundColor White
Write-Host "2. Go to {backend-url}/scalar/v1 to test the API" -ForegroundColor White
Write-Host "3. Try the /api/pet-analysis/health endpoint" -ForegroundColor White

Write-Host "`n🎯 Your Octopets application is now live!" -ForegroundColor Green