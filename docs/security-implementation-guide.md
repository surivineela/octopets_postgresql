# 🔒 Security Implementation Guide: Migrating to Azure Managed Identity

This guide provides step-by-step instructions for implementing Azure Managed Identity authentication with OpenAI, eliminating the need for API key-based authentication.

## 🚨 Current Security Risks

### API Key-Based Authentication Vulnerabilities:

1. **Secret Exposure**
   - Keys stored in plain text configuration files
   - Visible in environment variables and container logs
   - Risk of accidental version control commits
   - Network transmission exposure

2. **Access Control Limitations**
   - No fine-grained permissions
   - Broad access scope
   - Manual rotation required
   - Difficult usage auditing

3. **Operational Risks**
   - Shared keys across environments
   - Key extraction from running containers
   - No centralized governance
   - Manual lifecycle management

## 🎯 Recommended Solution: Azure Managed Identity

### Benefits:
- ✅ No secrets to manage
- ✅ Automatic credential rotation
- ✅ Fine-grained RBAC permissions
- ✅ Comprehensive audit logging
- ✅ Azure-native integration
- ✅ Zero-trust security model

## 📋 Implementation Steps

### Phase 1: Azure OpenAI Service Setup (Week 1)

#### Step 1: Create Azure OpenAI Resource
```bash
# Create Azure OpenAI service
az cognitiveservices account create \
    --name "octopets-openai-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --location "East US" \
    --kind "OpenAI" \
    --sku "S0" \
    --custom-domain "octopets-openai-${ENVIRONMENT}"

# Deploy GPT-4o-mini model
az cognitiveservices account deployment create \
    --name "octopets-openai-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --deployment-name "gpt-4o-mini" \
    --model-name "gpt-4o-mini" \
    --model-version "2024-07-18" \
    --model-format "OpenAI" \
    --scale-type "Standard" \
    --capacity 10
```

#### Step 2: Configure Managed Identity for Container Apps
```bash
# Create user-assigned managed identity
az identity create \
    --name "id-octopets-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --location "East US"

# Get identity details
IDENTITY_ID=$(az identity show \
    --name "id-octopets-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --query id -o tsv)

IDENTITY_CLIENT_ID=$(az identity show \
    --name "id-octopets-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --query clientId -o tsv)
```

#### Step 3: Assign RBAC Permissions
```bash
# Get OpenAI resource ID
OPENAI_RESOURCE_ID=$(az cognitiveservices account show \
    --name "octopets-openai-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --query id -o tsv)

# Assign Cognitive Services OpenAI User role
az role assignment create \
    --assignee "$IDENTITY_CLIENT_ID" \
    --role "Cognitive Services OpenAI User" \
    --scope "$OPENAI_RESOURCE_ID"
```

### Phase 2: Application Code Updates (Week 2)

#### Step 1: Update Dependencies
Add to `backend/Octopets.Backend.csproj`:
```xml
<PackageReference Include="Azure.Identity" Version="1.10.4" />
<PackageReference Include="Azure.AI.OpenAI" Version="1.0.0-beta.12" />
```

#### Step 2: Create Managed Identity OpenAI Service
Create `backend/Services/ManagedIdentityOpenAIService.cs`:
```csharp
using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Extensions.Options;

namespace Octopets.Backend.Services;

public class OpenAIConfiguration
{
    public string? Endpoint { get; set; }
    public string? DeploymentName { get; set; } = "gpt-4o-mini";
}

public interface IManagedIdentityOpenAIService
{
    Task<PetAnalysisResponse> AnalyzePetForVenueCompatibilityAsync(PetAnalysisRequest request);
    Task<List<string>> GetVenueRecommendations(string petType, string petBreed, string petSize, string activityLevel);
    Task<string> GenerateVenueDescription(string venueName, string venueType, List<string> allowedPets);
}

public class ManagedIdentityOpenAIService : IManagedIdentityOpenAIService
{
    private readonly OpenAIClient _openAIClient;
    private readonly OpenAIConfiguration _config;
    private readonly ILogger<ManagedIdentityOpenAIService> _logger;

    public ManagedIdentityOpenAIService(
        IOptions<OpenAIConfiguration> config,
        ILogger<ManagedIdentityOpenAIService> logger)
    {
        _config = config.Value;
        _logger = logger;

        if (string.IsNullOrEmpty(_config.Endpoint))
        {
            throw new InvalidOperationException("OpenAI endpoint not configured");
        }

        // Use Managed Identity for authentication
        var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            // Prefer managed identity in Azure, VS Code credential for local development
            ExcludeEnvironmentCredential = false,
            ExcludeInteractiveBrowserCredential = true,
            ExcludeAzurePowerShellCredential = true,
            ExcludeSharedTokenCacheCredential = true,
            ExcludeVisualStudioCredential = true,
            ExcludeVisualStudioCodeCredential = false,
            ExcludeManagedIdentityCredential = false,
            ExcludeAzureCliCredential = false
        });

        _openAIClient = new OpenAIClient(new Uri(_config.Endpoint), credential);

        _logger.LogInformation("OpenAI client initialized with Managed Identity authentication");
    }

    public async Task<PetAnalysisResponse> AnalyzePetForVenueCompatibilityAsync(PetAnalysisRequest request)
    {
        try
        {
            _logger.LogInformation("Analyzing pet {PetName} for venue {VenueName}", request.PetName, request.VenueName);

            var messages = new List<ChatRequestMessage>
            {
                new ChatRequestSystemMessage($@"
You are a professional pet behavior analyst and venue compatibility expert. 
Analyze the compatibility between the given pet and venue type, providing detailed insights and recommendations.

Respond with a valid JSON object matching this exact structure:
{{
    ""suitabilityScore"": ""score out of 10 with brief explanation"",
    ""recommendedVenueTypes"": [""array"", ""of"", ""suitable"", ""venue"", ""types""],
    ""venueRequirements"": [""array"", ""of"", ""specific"", ""requirements""],
    ""behaviorPrediction"": ""detailed behavior prediction"",
    ""safetyConsiderations"": [""array"", ""of"", ""safety"", ""considerations""],
    ""recommendedAmenities"": [""array"", ""of"", ""helpful"", ""amenities""],
    ""generalAdvice"": ""comprehensive advice for the pet owner""
}}"),
                new ChatRequestUserMessage($@"
Pet Details:
- Type: {request.PetType}
- Name: {request.PetName}
- Breed: {request.PetBreed}
- Age: {request.PetAge} years
- Size: {request.PetSize}
- Temperament: {request.PetTemperament}

Venue Details:
- Type: {request.VenueType}
- Name: {request.VenueName}

Please analyze this pet's compatibility with this venue type and provide detailed recommendations.")
            };

            var chatCompletionsOptions = new ChatCompletionsOptions(_config.DeploymentName, messages)
            {
                Temperature = 0.7f,
                MaxTokens = 1000,
                ResponseFormat = ChatCompletionsResponseFormat.JsonObject
            };

            var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions);
            var content = response.Value.Choices[0].Message.Content;

            _logger.LogInformation("Received OpenAI response for pet analysis");

            // Parse JSON response
            var analysisData = JsonSerializer.Deserialize<Dictionary<string, object>>(content);
            
            return new PetAnalysisResponse
            {
                PetName = request.PetName,
                SuitabilityScore = analysisData.GetValueOrDefault("suitabilityScore")?.ToString() ?? "Unable to analyze",
                RecommendedVenueTypes = ParseStringArray(analysisData.GetValueOrDefault("recommendedVenueTypes")),
                VenueRequirements = ParseStringArray(analysisData.GetValueOrDefault("venueRequirements")),
                BehaviorPrediction = analysisData.GetValueOrDefault("behaviorPrediction")?.ToString() ?? "Analysis unavailable",
                SafetyConsiderations = ParseStringArray(analysisData.GetValueOrDefault("safetyConsiderations")),
                RecommendedAmenities = ParseStringArray(analysisData.GetValueOrDefault("recommendedAmenities")),
                GeneralAdvice = analysisData.GetValueOrDefault("generalAdvice")?.ToString() ?? "Please consult with venue staff",
                AnalysisDate = DateTime.UtcNow
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error analyzing pet compatibility with OpenAI");
            
            return new PetAnalysisResponse
            {
                PetName = request.PetName,
                SuitabilityScore = "Unable to analyze - please try again later",
                RecommendedVenueTypes = ["Contact venue directly for pet policy information"],
                VenueRequirements = ["Verify pet-friendly status before visiting"],
                BehaviorPrediction = "Analysis unavailable",
                SafetyConsiderations = ["Always supervise your pet", "Bring necessary supplies"],
                RecommendedAmenities = ["Water bowls", "Pet waste stations"],
                GeneralAdvice = "Service temporarily unavailable. Please consult with venue staff about their pet policies.",
                AnalysisDate = DateTime.UtcNow
            };
        }
    }

    // Implementation of other methods...
    // (GetVenueRecommendations and GenerateVenueDescription follow similar patterns)
}
```

#### Step 3: Update Service Registration
Update `backend/Program.cs`:
```csharp
// Remove old service registration
// builder.Services.AddScoped<IOpenAIService, OpenAIService>();

// Add new managed identity service
builder.Services.Configure<OpenAIConfiguration>(
    builder.Configuration.GetSection("OpenAI"));
builder.Services.AddScoped<IManagedIdentityOpenAIService, ManagedIdentityOpenAIService>();
```

#### Step 4: Update Configuration
Update `backend/appsettings.json`:
```json
{
  "OpenAI": {
    "Endpoint": "https://octopets-openai-demo.openai.azure.com/",
    "DeploymentName": "gpt-4o-mini"
  }
}
```

### Phase 3: Infrastructure Updates (Week 3)

#### Step 1: Update Azure Container Apps Configuration
```bash
# Update container app with managed identity
az containerapp update \
    --name octopetsapi \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --assign-identity "$IDENTITY_ID" \
    --set-env-vars \
        OpenAI__Endpoint="https://octopets-openai-${ENVIRONMENT}.openai.azure.com/" \
        OpenAI__DeploymentName="gpt-4o-mini" \
    --remove-env-vars OpenAI__ApiKey
```

#### Step 2: Update Bicep Templates
Create `infra/modules/openai.bicep`:
```bicep
@description('The name of the OpenAI service')
param openAIServiceName string

@description('The location for the OpenAI service')
param location string = resourceGroup().location

@description('The name of the managed identity')
param managedIdentityName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource openAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAIServiceName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAIServiceName
    publicNetworkAccess: 'Enabled' // Consider 'Disabled' for production
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Deploy GPT-4o-mini model
resource gptModel 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAIService
  name: 'gpt-4o-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: 10
  }
}

// Assign Cognitive Services OpenAI User role to managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAIService
  name: guid(openAIService.id, managedIdentity.id, 'CognitiveServicesOpenAIUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output openAIEndpoint string = openAIService.properties.endpoint
output openAIServiceName string = openAIService.name
```

### Phase 4: Security Hardening (Week 4)

#### Step 1: Implement Azure Key Vault (Optional)
```bash
# Create Key Vault for additional secrets
az keyvault create \
    --name "kv-octopets-${ENVIRONMENT}" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --location "East US" \
    --enable-rbac-authorization true

# Assign Key Vault Secrets User role
az role assignment create \
    --assignee "$IDENTITY_CLIENT_ID" \
    --role "Key Vault Secrets User" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-octopets-${ENVIRONMENT}/providers/Microsoft.KeyVault/vaults/kv-octopets-${ENVIRONMENT}"
```

#### Step 2: Enable Diagnostic Logging
```bash
# Enable diagnostic logs for OpenAI service
az monitor diagnostic-settings create \
    --name "openai-diagnostics" \
    --resource "$OPENAI_RESOURCE_ID" \
    --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-octopets-${ENVIRONMENT}/providers/Microsoft.OperationalInsights/workspaces/law-octopets-${ENVIRONMENT}" \
    --logs '[
        {
            "category": "Audit",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "RequestResponse",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        }
    ]'
```

## 🔍 Testing and Validation

### Local Development Testing
```bash
# Login to Azure CLI for local testing
az login

# Test the application locally
dotnet run --project backend
```

### Production Validation
```bash
# Verify managed identity authentication
curl -H "Authorization: Bearer $(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)" \
     "https://octopets-openai-${ENVIRONMENT}.openai.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-06-01" \
     -d '{"messages":[{"role":"user","content":"test"}],"max_tokens":10}'
```

## 📊 Security Monitoring

### Key Metrics to Monitor
- Authentication success/failure rates
- API usage patterns and anomalies
- Resource access violations
- Failed authorization attempts

### Alerting Rules
```bash
# Create alert for failed authentication attempts
az monitor metrics alert create \
    --name "OpenAI-Authentication-Failures" \
    --resource-group "rg-octopets-${ENVIRONMENT}" \
    --scopes "$OPENAI_RESOURCE_ID" \
    --condition "count AuthenticationFailures > 10" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --severity 2
```

## 🎯 Success Criteria

- ✅ No API keys in configuration files or environment variables
- ✅ All OpenAI requests authenticated via Managed Identity
- ✅ RBAC permissions configured with least privilege principle
- ✅ Comprehensive audit logging enabled
- ✅ Automated security monitoring in place
- ✅ Zero-trust network access implemented

## 📚 Additional Resources

- [Azure Managed Identity Best Practices](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/best-practice-recommendations)
- [OpenAI on Azure Security Guide](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/how-to/managed-identity)
- [Zero Trust Security Model](https://docs.microsoft.com/en-us/security/zero-trust/)
- [Azure Security Benchmark](https://docs.microsoft.com/en-us/security/benchmark/azure/)