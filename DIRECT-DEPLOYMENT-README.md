# Octopets - Direct Azure Container Apps Deployment

This project has been converted from .NET Aspire to direct Azure Container Apps deployment for simplified architecture and maximum control over individual services.

## Architecture Overview

### Previous (Aspire)
```
AppHost (Orchestrator) → ServiceDefaults → Individual Services
```

### Current (Direct Container Apps)
```
Individual Services → Direct Azure Container Apps deployment
```

## Local Development

### Prerequisites
- .NET 9.0 SDK
- Docker Desktop
- Node.js 18+
- Azure CLI (for deployment)

### Option 1: Docker Compose (Recommended)
```bash
# Set your OpenAI API key
export OPENAI_API_KEY="your-api-key-here"  # Linux/Mac
# OR
$env:OPENAI_API_KEY = "your-api-key-here"  # PowerShell

# Start all services
docker-compose up --build

# Frontend: http://localhost:3000
# Backend: http://localhost:5000
# API Documentation: http://localhost:5000/scalar/v1
```

### Option 2: Manual Development
```bash
# Terminal 1: Start Backend
cd backend
dotnet run

# Terminal 2: Start Frontend  
cd frontend
npm start

# Set environment variables:
# REACT_APP_API_BASE_URL=http://localhost:5000/api
# REACT_APP_USE_MOCK_DATA=false
```

## Azure Deployment

### Prerequisites
- Azure CLI installed and authenticated (`az login`)
- OpenAI API key set as environment variable

### Deployment Scripts

#### PowerShell (Windows)
```powershell
# Set your OpenAI API key
$env:OPENAI_API_KEY = "your-api-key-here"

# Run deployment
.\deploy-container-apps.ps1
```

#### Bash (Linux/Mac)
```bash
# Set your OpenAI API key
export OPENAI_API_KEY="your-api-key-here"

# Make script executable and run
chmod +x deploy-container-apps.sh
./deploy-container-apps.sh
```

### Custom Deployment
```bash
# Custom resource group and location
.\deploy-container-apps.ps1 -ResourceGroup "my-rg" -Location "West US 2"
```

## Project Structure

```
octopets/
├── backend/                 # ASP.NET Core API
│   ├── Controllers/
│   ├── Services/
│   ├── Models/
│   └── Dockerfile
├── frontend/                # React TypeScript App
│   ├── src/
│   ├── public/
│   └── Dockerfile
├── docker-compose.yml       # Local development orchestration
├── docker-compose.override.yml  # Development overrides
├── deploy-container-apps.ps1     # Windows deployment script
├── deploy-container-apps.sh      # Linux/Mac deployment script
└── deployment-info.json          # Generated deployment details
```

## Key Changes from Aspire

### Removed
- ❌ `/apphost` folder (Aspire orchestrator)
- ❌ `/servicedefaults` folder (Aspire shared config)
- ❌ `azure.yaml` (Aspire-specific deployment)
- ❌ `builder.AddServiceDefaults()` calls
- ❌ `app.MapDefaultEndpoints()` calls

### Added
- ✅ Docker Compose for local development
- ✅ Direct Container Apps deployment scripts
- ✅ Standard .NET health checks and telemetry
- ✅ Environment variable-based configuration
- ✅ Individual service Dockerfiles

## Configuration

### Backend Environment Variables
```bash
ASPNETCORE_ENVIRONMENT=Production
OpenAI__ApiKey=your-api-key-here
EnableSwagger=true
```

### Frontend Environment Variables
```bash
REACT_APP_API_BASE_URL=https://your-backend.azurecontainerapps.io/api
REACT_APP_USE_MOCK_DATA=false
```

## Monitoring & Observability

### Health Checks
- Backend: `https://your-backend.azurecontainerapps.io/health`
- Frontend: `https://your-frontend.azurecontainerapps.io/`

### Application Insights
Configured automatically in Azure Container Apps for telemetry and monitoring.

### API Documentation
- Swagger/Scalar UI: `https://your-backend.azurecontainerapps.io/scalar/v1`

## Scaling Configuration

### Backend
- Min replicas: 1
- Max replicas: 3
- CPU: 0.5 cores
- Memory: 1.0 GB

### Frontend
- Min replicas: 1
- Max replicas: 5
- CPU: 0.25 cores  
- Memory: 0.5 GB

## Security Features

- HTTPS enforcement
- CORS configuration
- API key management through environment variables
- Container registry authentication
- Network isolation within Container Apps Environment

## Troubleshooting

### Local Development Issues
```bash
# Check Docker containers
docker-compose ps

# View logs
docker-compose logs backend
docker-compose logs frontend

# Rebuild containers
docker-compose up --build --force-recreate
```

### Azure Deployment Issues
```bash
# Check container app status
az containerapp show --name octopets-backend --resource-group rg-octopets

# View logs
az containerapp logs show --name octopets-backend --resource-group rg-octopets --follow

# Update environment variables
az containerapp update --name octopets-backend --resource-group rg-octopets --set-env-vars "KEY=VALUE"
```

## Migration Benefits

✅ **Simplified Architecture** - No orchestrator dependency  
✅ **Direct Control** - Individual service scaling and configuration  
✅ **Reduced Complexity** - Standard Container Apps patterns  
✅ **Better Debugging** - Direct access to individual services  
✅ **Flexible Deployment** - Can deploy services independently  

## Cost Optimization

- Frontend uses minimal resources (0.25 CPU, 0.5GB RAM)
- Backend scales based on demand (1-3 replicas)
- Container registry uses Basic tier
- No additional Aspire hosting costs