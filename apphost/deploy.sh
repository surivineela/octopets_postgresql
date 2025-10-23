#!/bin/bash

# Octopets Deployment Script (Bash version)
# This script helps deploy the Octopets application with OpenAI integration to Azure

ENVIRONMENT_NAME=${1:-"octopets-prod"}
LOCATION=${2:-"eastus2"}
OPENAI_API_KEY=${3:-""}

echo "🐾 Octopets Deployment Script"
echo "============================"

# Check prerequisites
echo ""
echo "📋 Checking prerequisites..."

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI (azd) is not installed."
    echo "Please install it from: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Octopets.AppHost.csproj" ]; then
    echo "❌ Please run this script from the apphost directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Get OpenAI API key if not provided
if [ -z "$OPENAI_API_KEY" ]; then
    echo ""
    echo "🔑 OpenAI API Key Configuration"
    echo "You need an OpenAI API key for the pet analysis features."
    echo "You can get one at: https://platform.openai.com/"
    echo ""
    read -p "Enter your OpenAI API key (or press Enter to skip): " OPENAI_API_KEY
    
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "⚠️  Skipping OpenAI configuration. You can set this up later in Azure Portal."
        SKIP_OPENAI=true
    fi
fi

# Initialize azd if not already done
echo ""
echo "🚀 Initializing Azure Developer CLI..."

if [ ! -d ".azure" ]; then
    echo "Initializing azd environment..."
    azd init --environment "$ENVIRONMENT_NAME" --location "$LOCATION"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to initialize azd environment"
        exit 1
    fi
else
    echo "✅ azd environment already initialized"
fi

# Set environment variables
echo ""
echo "⚙️  Configuring environment..."

# Create or update .env file
cat > .env << EOF
AZURE_ENV_NAME=$ENVIRONMENT_NAME
AZURE_LOCATION=$LOCATION
REACT_APP_USE_MOCK_DATA=false
EOF

if [ -n "$OPENAI_API_KEY" ]; then
    echo "OPENAI_API_KEY=$OPENAI_API_KEY" >> .env
fi

echo "✅ Environment configuration updated"

# Login to Azure
echo ""
echo "🔐 Azure Authentication..."
azd auth login

if [ $? -ne 0 ]; then
    echo "❌ Failed to authenticate with Azure"
    exit 1
fi

# Deploy the application
echo ""
echo "🚀 Deploying Octopets to Azure..."
echo "This may take 5-10 minutes..."

azd up

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed"
    exit 1
fi

# Success message
echo ""
echo "🎉 Deployment completed successfully!"
echo "====================================="

# Get and display application URLs
echo ""
echo "📍 Getting application URLs..."
azd show --output table

if [ "$SKIP_OPENAI" != "true" ]; then
    echo ""
    echo "✅ OpenAI integration is configured and ready to use!"
else
    echo ""
    echo "⚠️  Post-deployment steps:"
    echo "1. Go to Azure Portal"
    echo "2. Find your Container App (octopets-backend)"
    echo "3. Add environment variable: OpenAI__ApiKey = your-openai-api-key"
    echo "4. Restart the container app"
fi

echo ""
echo "🧪 Test your deployment:"
echo "1. Open the frontend URL to access the web app"
echo "2. Go to {backend-url}/scalar/v1 to test the API"
echo "3. Try the /api/pet-analysis/health endpoint"

echo ""
echo "🎯 Your Octopets application is now live!"