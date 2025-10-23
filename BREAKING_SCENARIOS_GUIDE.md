# PostgreSQL Connectivity Breaking Scenarios Guide

This guide provides comprehensive breaking scenarios to test PostgreSQL connectivity issues and their impact on the Octopets application. These scenarios are designed for testing SRE troubleshooting capabilities and understanding failure modes.

## 🎯 **Objectives**
- Create realistic production failure scenarios
- Test frontend resilience to backend database issues  
- Provide diagnostic challenges for SRE agents
- Document recovery procedures for each scenario

---

## 📋 **Pre-Requisites**
- Working Octopets application deployed to Azure Container Apps
- PostgreSQL Flexible Server running in Sweden Central
- Azure CLI access with appropriate permissions
- Access to Azure Portal

## 🔧 **Current Working State Documentation**

Before breaking anything, document the current working state:

```bash
# Backend API Status
curl https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health

# Frontend Access
curl https://octopets-prod-web.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/

# Database Server Status  
az postgres flexible-server show --name octopets-prod-postgres --resource-group octopets-prod-rg --query "state"

# Current Connection String (stored in Key Vault)
az keyvault secret show --vault-name octopets-prod-kv --name PostgresConnectionString --query "value"
```

---

## 🚨 **Breaking Scenarios**

### **Scenario 1: Wrong Database Server Hostname**
**Difficulty:** Easy | **Impact:** High | **Detection:** Easy

#### How to Break:
1. Edit `infrastructure/main.bicep`
2. Find the `connectionStringSecret` resource (around line 326)
3. Replace the connection string:

```bicep
// ORIGINAL (working)
value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'

// BREAKING CHANGE - Wrong hostname
value: 'Host=octopets-wrong-postgres.postgres.database.azure.com;Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
```

4. Deploy the change:
```bash
az deployment group create --resource-group "octopets-prod-rg" --template-file "infrastructure/main.bicep" --parameters location="swedencentral" environment="prod" appName="octopets" dbAdminLogin="octopetsadmin" dbAdminPassword="OctoPets2024!" --mode Incremental
```

5. Restart Container App to pick up new connection string:
```bash
az containerapp restart --name octopets-prod-api --resource-group octopets-prod-rg
```

#### Expected Impact:
- ❌ Backend health checks fail (`/health` returns 503)
- ❌ Frontend listings page shows "Unable to load listings"
- ❌ API calls return connection timeout errors
- ❌ Container App status shows "Unhealthy"

#### How to Fix:
```bash
# 1. Restore correct connection string in main.bicep
# 2. Redeploy infrastructure
az deployment group create --resource-group "octopets-prod-rg" --template-file "infrastructure/main.bicep" --parameters location="swedencentral" environment="prod" appName="octopets" dbAdminLogin="octopetsadmin" dbAdminPassword="OctoPets2024!" --mode Incremental

# 3. Restart Container App
az containerapp restart --name octopets-prod-api --resource-group octopets-prod-rg
```

---

### **Scenario 2: Authentication Failure (Wrong Username)**
**Difficulty:** Easy | **Impact:** High | **Detection:** Easy

#### How to Break:
```bicep
// BREAKING CHANGE - Wrong username
value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=wronguser;Password=${dbAdminPassword};SSL Mode=Require'
```

#### Expected Impact:
- ❌ Authentication errors in backend logs
- ❌ All API endpoints return 500 errors
- ❌ Container App shows "Unhealthy" status

#### Diagnostic Clues:
```bash
# Check logs for authentication errors
az containerapp logs show --name octopets-prod-api --resource-group octopets-prod-rg --follow
```

---

### **Scenario 3: Wrong Database Password**
**Difficulty:** Easy | **Impact:** High | **Detection:** Easy

#### How to Break:
```bicep
// BREAKING CHANGE - Wrong password
value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${dbAdminLogin};Password=WrongPassword123!;SSL Mode=Require'
```

#### Expected Impact:
- ❌ Authentication failures in logs
- ❌ Database connection pool exhaustion
- ❌ 500 errors on all database endpoints

---

### **Scenario 4: Wrong Database Name**
**Difficulty:** Easy | **Impact:** Medium | **Detection:** Easy

#### How to Break:
```bicep
// BREAKING CHANGE - Non-existent database
value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=nonexistentdb;Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
```

#### Expected Impact:
- ❌ "Database does not exist" errors
- ❌ Entity Framework migration failures
- ❌ All CRUD operations fail

---

### **Scenario 5: SSL/TLS Configuration Issues**
**Difficulty:** Medium | **Impact:** Medium | **Detection:** Medium

#### How to Break:
```bicep
// BREAKING CHANGE - Disable SSL (Azure PostgreSQL requires SSL)
value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Disable'
```

#### Expected Impact:
- ❌ SSL handshake failures
- ❌ Connection rejected by Azure PostgreSQL
- ❌ Security policy violations

---

### **Scenario 6: Network/Firewall Issues**
**Difficulty:** Medium | **Impact:** High | **Detection:** Medium

#### How to Break:
```bash
# Remove Container App IP from PostgreSQL firewall rules
az postgres flexible-server firewall-rule delete --name octopets-prod-postgres --resource-group octopets-prod-rg --rule-name "AllowContainerApps" --yes
```

#### Expected Impact:
- ❌ Connection timeouts
- ❌ Network-level blocking
- ❌ TCP connection failures

#### How to Fix:
```bash
# Get Container App outbound IP
CONTAINER_APP_IP=$(az containerapp show --name octopets-prod-api --resource-group octopets-prod-rg --query "properties.outboundIpAddresses[0]" -o tsv)

# Add firewall rule back
az postgres flexible-server firewall-rule create --name octopets-prod-postgres --resource-group octopets-prod-rg --rule-name "AllowContainerApps" --start-ip-address $CONTAINER_APP_IP --end-ip-address $CONTAINER_APP_IP
```

---

### **Scenario 7: Connection Pool Exhaustion**
**Difficulty:** Hard | **Impact:** Medium | **Detection:** Hard

#### How to Break:
Modify `backend/Program.cs`:
```csharp
// Add connection string options to reduce pool size
builder.Services.AddDbContext<AppDbContext>(options => 
    options.UseNpgsql(connectionString, npgsqlOptions => {
        npgsqlOptions.CommandTimeout(5); // Very short timeout
    }));
```

#### Expected Impact:
- ⚠️ Intermittent 500 errors under load
- ⚠️ "Connection pool exhausted" in logs
- ⚠️ Performance degradation

---

### **Scenario 8: PostgreSQL Server Resource Exhaustion**
**Difficulty:** Hard | **Impact:** Medium | **Detection:** Hard

#### How to Break:
```bash
# Scale PostgreSQL to smallest possible tier
az postgres flexible-server update --name octopets-prod-postgres --resource-group octopets-prod-rg --sku-name Standard_B1ms --storage-size 32
```

#### Expected Impact:
- ⚠️ Slow database responses
- ⚠️ Query timeouts
- ⚠️ Performance degradation

---

### **Scenario 9: Missing Database Schema/Tables**
**Difficulty:** Medium | **Impact:** High | **Detection:** Medium

#### How to Break:
```bash
# Connect to PostgreSQL and drop tables
# (Requires database connection string)
psql "Host=octopets-prod-postgres.postgres.database.azure.com;Database=octopetsdb;Username=octopetsadmin;Password=OctoPets2024!;SSL Mode=Require"

-- Drop critical tables
DROP TABLE IF EXISTS "Reviews" CASCADE;
DROP TABLE IF EXISTS "Listings" CASCADE;
```

#### Expected Impact:
- ❌ Entity Framework table not found errors
- ❌ 500 errors on specific endpoints
- ❌ Migration status inconsistencies

#### How to Fix:
```bash
cd backend
dotnet ef database update --connection "Host=octopets-prod-postgres.postgres.database.azure.com;Database=octopetsdb;Username=octopetsadmin;Password=OctoPets2024!;SSL Mode=Require"
```

---

### **Scenario 10: PostgreSQL Database Server Stopped** ⭐
**Difficulty:** Easy | **Impact:** Critical | **Detection:** Easy

#### How to Break:
```bash
# Stop the PostgreSQL server completely
az postgres flexible-server stop --name octopets-prod-postgres --resource-group octopets-prod-rg
```

#### Expected Impact:
- 🔥 **Complete application failure**
- ❌ All database connections fail with "server not responding"
- ❌ Health checks return 503 Service Unavailable
- ❌ Frontend shows "Unable to load listings" everywhere
- ❌ Container App status shows "Degraded"

#### Diagnostic Symptoms:
```bash
# Check server status - should show "Stopped"
az postgres flexible-server show --name octopets-prod-postgres --resource-group octopets-prod-rg --query "state"

# Backend logs will show connection timeouts
az containerapp logs show --name octopets-prod-api --resource-group octopets-prod-rg --follow

# Health endpoint will fail
curl https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health
```

#### How to Fix:
```bash
# Start the PostgreSQL server
az postgres flexible-server start --name octopets-prod-postgres --resource-group octopets-prod-rg

# Wait for server to be ready (2-5 minutes)
az postgres flexible-server show --name octopets-prod-postgres --resource-group octopets-prod-rg --query "state"

# Verify connectivity is restored
curl https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health
```

---

## 🛠️ **SRE Diagnostic Tools**

### Essential Commands for Troubleshooting:

```bash
# 1. Check Container App Status
az containerapp show --name octopets-prod-api --resource-group octopets-prod-rg --query "properties.runningStatus"

# 2. View Application Logs
az containerapp logs show --name octopets-prod-api --resource-group octopets-prod-rg --follow

# 3. Check PostgreSQL Server Status
az postgres flexible-server show --name octopets-prod-postgres --resource-group octopets-prod-rg

# 4. Test Health Endpoints
curl -v https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health
curl -v https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/health/ready

# 5. Test API Endpoints
curl -v https://octopets-prod-api.yellowmushroom-e7e19f03.swedencentral.azurecontainerapps.io/api/listings

# 6. Check Connection String (in Key Vault)
az keyvault secret show --vault-name octopets-prod-kv --name PostgresConnectionString --query "value"

# 7. Check Firewall Rules
az postgres flexible-server firewall-rule list --name octopets-prod-postgres --resource-group octopets-prod-rg

# 8. Check Container App Environment
az containerapp env show --name octopets-prod-env --resource-group octopets-prod-rg
```

### Log Analysis Keywords:
- `Npgsql.NpgsqlException` - PostgreSQL connection errors
- `Connection timeout expired` - Network/server unavailable
- `Authentication failed` - Wrong credentials
- `database "xyz" does not exist` - Wrong database name
- `Connection pool exhausted` - Too many connections
- `SSL connection required` - SSL configuration issues

---

## 📊 **Scenario Summary Table**

| Scenario | Complexity | Impact | Detection | Recovery Time | SRE Learning Focus |
|----------|------------|--------|-----------|---------------|-------------------|
| Wrong Hostname | Easy | High | Easy | 5-10 min | Infrastructure config |
| Wrong Username | Easy | High | Easy | 5-10 min | Authentication |
| Wrong Password | Easy | High | Easy | 5-10 min | Secret management |
| Wrong Database | Easy | Medium | Easy | 5-10 min | Database configuration |
| SSL Issues | Medium | Medium | Medium | 10-15 min | Security policies |
| Firewall | Medium | High | Medium | 10-20 min | Network troubleshooting |
| Pool Exhaustion | Hard | Medium | Hard | 15-30 min | Performance analysis |
| Resource Exhaustion | Hard | Medium | Hard | 20-40 min | Capacity planning |
| Missing Schema | Medium | High | Medium | 10-30 min | Database migrations |
| **Server Stopped** | **Easy** | **Critical** | **Easy** | **5-10 min** | **Infrastructure monitoring** |

---

## 🎯 **Recommended Testing Sequence**

1. **Start Simple**: Begin with Scenario 10 (Server Stopped) - most obvious failure
2. **Progress to Configuration**: Try Scenarios 1-4 (connection string issues)
3. **Advanced**: Move to Scenarios 6-9 (network, performance, schema)
4. **Document Everything**: Keep notes on symptoms and resolution steps

---

## ⚠️ **Important Notes**

- **Always backup** current configuration before breaking
- **Test one scenario at a time** to avoid confusion
- **Document symptoms** before revealing the root cause to SRE
- **Have restoration procedures ready** for each scenario
- **Monitor costs** - some scenarios may incur additional Azure charges

---

## 🔄 **Restoration Checklist**

After testing each scenario, ensure:
- [ ] PostgreSQL server is running (`Ready` state)
- [ ] Connection string is correct in Key Vault
- [ ] Container App is healthy
- [ ] Frontend loads listings successfully
- [ ] All API endpoints return expected responses
- [ ] No error logs in Container App

---

*This guide enables comprehensive testing of database connectivity failure modes and recovery procedures for the Octopets application.*