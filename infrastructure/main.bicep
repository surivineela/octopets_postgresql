// Azure Infrastructure for Octopets Application - Sweden Central
@description('Location for all resources')
param location string = 'swedencentral'

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Application name')
param appName string = 'octopets'

@description('Database administrator login')
@secure()
param dbAdminLogin string

@description('Database administrator password')
@secure()
param dbAdminPassword string

// Variables
var resourceGroupName = '${appName}-${environment}-rg'
var postgresServerName = '${appName}-${environment}-postgres'
var databaseName = '${appName}db'
var containerAppEnvName = '${appName}-${environment}-env'
var containerAppBackendName = '${appName}-${environment}-api'
var containerAppFrontendName = '${appName}-${environment}-web'
var containerRegistryName = '${appName}${environment}registry'
var keyVaultName = '${appName}-${environment}-kv'
var logAnalyticsName = '${appName}-${environment}-logs'
var appInsightsName = '${appName}-${environment}-insights'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: dbAdminLogin
    administratorLoginPassword: dbAdminPassword
    version: '15'
    storage: {
      storageSizeGB: 32
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// PostgreSQL Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule - Allow Azure Services
resource postgresFirewallAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Container Apps Environment
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Container App (Backend API)
resource containerAppBackend 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: containerAppBackendName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        corsPolicy: {
          allowedOrigins: [
            '*'  // Allow all origins for now - will configure specific domains after deployment
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      }
      secrets: [
        {
          name: 'postgres-connection'
          value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
        }
        {
          name: 'appinsights-key'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.properties.adminUserEnabled ? containerRegistry.name : ''
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'octopets-api'
          image: '${containerRegistry.properties.loginServer}/octopets-backend:latest'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ConnectionStrings__octopetsdb'
              secretRef: 'postgres-connection'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 30
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
}

// Container App (Frontend)
resource containerAppFrontend 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: containerAppFrontendName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
      }
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.properties.adminUserEnabled ? containerRegistry.name : ''
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'octopets-frontend'
          image: '${containerRegistry.properties.loginServer}/octopets-frontend:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'REACT_APP_API_URL'
              value: 'BACKEND_URL_PLACEHOLDER'  // Will be updated after backend deployment
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
}

// Key Vault Secrets
resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'PostgresConnectionString'
  properties: {
    // BREAKING CHANGE #1: Wrong hostname - simulating DNS/networking issue
    // Original: value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
    value: 'Host=octopets-wrong-postgres.postgres.database.azure.com;Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
  }
}

// Outputs
output postgresServerName string = postgresServer.name
output postgresFqdn string = postgresServer.properties.fullyQualifiedDomainName
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output backendAppName string = containerAppBackend.name
output backendAppUrl string = 'https://${containerAppBackend.properties.configuration.ingress.fqdn}'
output frontendAppName string = containerAppFrontend.name
output frontendAppUrl string = 'https://${containerAppFrontend.properties.configuration.ingress.fqdn}'
output keyVaultName string = keyVault.name
output resourceGroupName string = resourceGroupName