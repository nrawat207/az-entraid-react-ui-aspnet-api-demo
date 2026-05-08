# Azure Entra ID + React + ASP.NET Core - Enterprise Deployment Complete

## 📋 Executive Summary

This repository contains a complete, production-ready enterprise deployment of a modern web application with:

- **Frontend:** React 19 + Vite (TypeScript)
- **Backend-for-Frontend:** ASP.NET Core 10.0 (OpenID Connect + Cookie auth)
- **Protected API:** ASP.NET Core 10.0 (JWT bearer auth)
- **Infrastructure:** Azure Container Apps, SQL Database, Key Vault, App Insights
- **Authentication:** Microsoft Entra ID (Azure AD)
- **CI/CD:** Azure DevOps Pipelines
- **Observability:** Azure Monitor + Log Analytics

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Internet / Users                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                ┌──────────▼──────────┐
                │  Azure Front Door   │
                │   (Optional CDN)    │
                └──────────┬──────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Frontend    │    │    BFF      │    │   API       │
│ (React)     │◄──►│ (.NET 10.0) │◄──►│ (.NET 10.0) │
│ Port 3000   │    │ Port 5001   │    │ Port 5002   │
└────────────┬┘    └──────┬──────┘    └──────┬──────┘
             │             │                 │
             │  Cookies    │  Bearer Token   │
             │             │                 │
             └─────────────┼─────────────────┘
                           │
                ┌──────────▼──────────┐
                │  Entra ID (OIDC)    │
                │  login.microsoft... │
                └─────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              Azure Container Apps Environment                   │
├─────────────────────────────────────────────────────────────────┤
│  - Ingress routing (Frontend external, API internal)            │
│  - Auto-scaling (CPU-based)                                     │
│  - Integrated logging to Log Analytics                          │
│  - Network isolation with CORS policies                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Data & Secrets Layer                         │
├────────────────────┬──────────────────┬──────────────────┐       │
│  Azure SQL         │  Azure Key       │  Application     │       │
│  Database          │  Vault           │  Insights        │       │
│  (Employee data)   │  (Secrets,       │  + Log Analytics │       │
│                    │   credentials)   │  (Observability) │       │
└────────────────────┴──────────────────┴──────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 Deliverables

### Infrastructure as Code
- ✅ **Bicep Templates** (`infra/`)
  - `main.bicep` - Orchestrator
  - `modules/keyvault.bicep` - Secret management
  - `modules/monitoring.bicep` - App Insights + Log Analytics
  - `modules/sql.bicep` - Database
  - `modules/container-registry.bicep` - Image registry
  - `modules/container-apps-env.bicep` - Container Apps environment
  - `modules/container-apps.bicep` - Frontend, BFF, API deployments

### Containerization
- ✅ **Dockerfiles** (Multi-stage, production-optimized)
  - `frontend/Dockerfile` - Node.js alpine
  - `bff/Dockerfile` - .NET 10.0 runtime
  - `api/Dockerfile` - .NET 10.0 runtime
  - `.dockerignore` - Optimize build context

### Application Configuration
- ✅ **Key Vault Integration**
  - BFF & API updated with `Azure.Identity` and `Azure.Extensions.AspNetCore.Configuration.Secrets`
  - Managed Identity authentication (no hardcoded secrets)
  - Environment-specific appsettings

- ✅ **Health Checks**
  - `/health` endpoints on BFF and API
  - Container health probes configured

- ✅ **CORS Configuration**
  - Dynamic origin configuration
  - Environment-based settings

### CI/CD Pipeline
- ✅ **Azure DevOps Pipeline** (`azure-pipelines.yml`)
  - **Build Stage:** Compile, test, lint all services
  - **Docker Stage:** Build and push images to ACR
  - **Deploy Dev:** Auto-deploy on `develop` branch
  - **Deploy Prod:** Manual approval for `main` branch

### Documentation
- ✅ `.azure/deployment-plan.md` - Step-by-step deployment
- ✅ `docs/entra-id-prod-setup.md` - Entra ID configuration guide
- ✅ `docs/ci-cd-setup.md` - CI/CD pipeline setup
- ✅ `docs/DEPLOYMENT.md` - This file

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install tools
- Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli
- .NET 10.0 SDK: https://dotnet.microsoft.com/download
- Node.js 20+: https://nodejs.org/
- Docker: https://www.docker.com/products/docker-desktop

# Verify installations
az --version
dotnet --list-sdks
node --version
docker --version
```

### 2. Local Development

```bash
# Start database (Docker)
docker run -d -p 1433:1433 \
  -e "SA_PASSWORD=P@ssw0rd123!" \
  mcr.microsoft.com/mssql/server:2022-latest

# Run BFF
cd bff
dotnet run

# Run API (in another terminal)
cd api
dotnet run

# Run Frontend (in another terminal)
cd frontend
npm install
npm run dev
```

### 3. Deploy to Azure (Idempotent Process)

The infrastructure templates are now **idempotent**, meaning you can run the deployment commands multiple times safely. Subsequent deployments will update only what has changed and won't fail or try to recreate existing resources.

#### Step 3.1: Prepare Azure Account

```bash
# Login to Azure
az login

# List your subscriptions
az account list --output table

# Set default subscription (optional)
az account set --subscription "<subscription-id-or-name>"

# Create resource group (safe to run multiple times)
az group create \
  --name entra-demo-dev-rg \
  --location centralindia

# Verify resource group created
az group show --name entra-demo-dev-rg
```

#### Step 3.2: Initial Infrastructure Deployment

```bash
# Set variables for easier reuse
export ACR_USERNAME="<your-acr-username>"
export ACR_PASSWORD="<your-acr-password>"
export SQL_PASSWORD="<strong-sql-password>"
export BFF_TENANT_ID="<entra-tenant-id>"
export BFF_CLIENT_ID="<bff-app-client-id>"
export BFF_CLIENT_SECRET="<bff-app-secret>"
export API_AUDIENCE="api://<api-app-client-id>"

# Navigate to infra directory
cd infra

# VALIDATE infrastructure (preview mode, no changes)
az deployment group validate \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD

# WHAT-IF preview (shows what will change)
az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD

# DEPLOY infrastructure (main deployment)
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD

# Output deployment information
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query properties.outputs
```

#### Step 3.3: Configure Key Vault Secrets (Post-Deployment)

After infrastructure is deployed, configure Entra ID secrets in Key Vault:

```bash
# Get the Key Vault name
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Set Entra ID secrets (only if you have actual values)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name BffClientSecret \
  --value "$BFF_CLIENT_SECRET"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name BffTenantId \
  --value "$BFF_TENANT_ID"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name BffClientId \
  --value "$BFF_CLIENT_ID"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name ApiAudience \
  --value "$API_AUDIENCE"

# Verify secrets were created
az keyvault secret list --vault-name $KV_NAME --query "[].name"
```

#### Step 3.4: Build and Push Docker Images

```bash
# Login to ACR
az acr login --name entrademodevacr

# Build and push Frontend image
az acr build \
  --registry entrademodevacr \
  --image entra-demo/frontend:latest \
  --file frontend/Dockerfile \
  .

# Build and push BFF image
az acr build \
  --registry entrademodevacr \
  --image entra-demo/bff:latest \
  --file bff/Dockerfile \
  .

# Build and push API image
az acr build \
  --registry entrademodevacr \
  --image entra-demo/api:latest \
  --file api/Dockerfile \
  .

# Verify images were pushed
az acr repository list --name entrademodevacr
```

#### Step 3.5: Verify Deployment (Optional but Recommended)

```bash
# Check deployment status
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.provisioningState"

# Get container app URLs
az containerapp list \
  --resource-group entra-demo-dev-rg \
  --query "[].properties.configuration.ingress.fqdn"

# Check container app status
az containerapp show \
  --name frontend-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.provisioningState"

# View container logs (if needed)
az containerapp logs show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --tail 50
```

#### Step 3.6: Redeployment (Run Again Safely)

The infrastructure is idempotent. You can run the deployment command again anytime to:
- Update to new Docker image versions
- Change infrastructure parameters
- Apply updates

```bash
# Just run the deployment again - it will only update what changed
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD
```

## 🔐 Security Features

| Feature | Implementation | Benefit |
|---------|-----------------|---------|
| **Zero Secrets in Code** | Key Vault + Managed Identity | Prevents credential leaks |
| **HTTPS Everywhere** | TLS 1.3 enforced | Encrypted communications |
| **Secure Cookies** | HttpOnly + Secure flags | Prevents XSS token theft |
| **CORS Protection** | Dynamic origin validation | Prevents CSRF attacks |
| **JWT Validation** | Entra ID token validation | Proves token authenticity |
| **Network Isolation** | API internal, Frontend external | Limits exposure surface |
| **Application Insights** | Telemetry + alerts | Detects anomalies |
| **Managed Identities** | No service principals | Azure AD native auth |

## 📊 Observability

### Metrics & Logs

Access Application Insights:
```bash
# Get App Insights name
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.infrastructureInfo.value.appInsightsName" \
  -o tsv

# Open in portal
# https://portal.azure.com/#@/resource/.../providers/microsoft.insights/components/...
```

### KQL Queries

**Failed Authentication Attempts:**
```kusto
AppEvents
| where Name == "AuthenticationFailed"
| summarize count() by tostring(CustomDimensions.Reason)
```

**API Response Times:**
```kusto
AppDependencies
| where DependencyType == "Http"
| summarize AvgDuration=avg(DurationMs) by Target
| sort by AvgDuration desc
```

**Container App Restarts:**
```kusto
ContainerAppConsoleLogs
| where ContainerAppName == "api-dev"
| where LogLevel == "Error"
| summarize count() by TimeGenerated
```

## 🔄 Deployment Environments

### Development (`develop` branch → `entra-demo-dev-rg`)
- Auto-deploy on push
- 1 replica per service
- Dev database tier
- Public debugging enabled

### Production (`main` branch → `entra-demo-prod-rg`)
- Manual approval required
- 2-3 replicas per service
- Premium database tier
- Monitoring/alerting enabled

## 📈 Scaling Considerations

### Horizontal Scaling
- Container Apps auto-scale based on CPU (0.5 → 3 replicas)
- Configure custom metrics in Bicep if needed

### Database Scaling
```bash
# Scale up SQL Database
az sql db update \
  --resource-group entra-demo-prod-rg \
  --server entra-demo-sql-xxxxx \
  --name entrademo-db \
  --edition Premium \
  --capacity 4
```

### CDN Integration (Optional)
Add Azure Front Door or CDN for:
- Global edge caching
- DDoS protection
- WAF rules

## 🆘 Troubleshooting

### Idempotency Testing

After deploying to Azure, verify the infrastructure is idempotent by running the deployment again:

```bash
# Set environment variables (same as before)
export ACR_USERNAME="<your-acr-username>"
export ACR_PASSWORD="<your-acr-password>"
export SQL_PASSWORD="<sql-password>"

# Run deployment a second time
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD

# Expected result:
# ✅ Deployment succeeds (no errors)
# ✅ Runs much faster (30-60 seconds vs 3-5 minutes for first deploy)
# ✅ No resources are recreated or modified (unless you changed parameters)
```

### Container won't start

**Error**: Container is in "Unhealthy" or "Error" state

```bash
# Get the Key Vault name for later use
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Check container logs
az containerapp logs show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --tail 100

# Check if Docker image exists in ACR
az acr repository list --name entrademodevacr
az acr repository show-tags --name entrademodevacr --repository entra-demo/bff

# Verify container app configuration
az containerapp show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.template.containers[0].image"

# Verify Key Vault access (if using managed identity)
az keyvault secret list --vault-name $KV_NAME --query "[].name"
```

### Authentication fails

**Error**: Login redirects to error page, or "401 Unauthorized" in API

```bash
# Get Key Vault name
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Verify Entra ID secrets exist in Key Vault
az keyvault secret list --vault-name $KV_NAME --query "[].name"

# Check if optional secrets are properly set (not empty placeholders)
echo "Checking BffClientSecret:"
az keyvault secret show --vault-name $KV_NAME --name BffClientSecret \
  --query "value" | head -c 20
echo "..."

# Check BFF logs for auth errors
az containerapp logs show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --tail 100 | grep -i "auth\|error\|unauthorized"

# If secrets are missing or have placeholder values, set them:
# Option 1: Using CLI
az keyvault secret set \
  --vault-name $KV_NAME \
  --name BffClientSecret \
  --value "your-actual-entra-secret"

# Option 2: Using Azure Portal
# 1. Open Key Vault in portal
# 2. Go to Secrets
# 3. Click BffClientSecret and update value
# 4. Container will pick up new value automatically
```

### Database connection fails

**Error**: "Cannot connect to database" or "SQL Server firewall" errors

```bash
# Get SQL Server name
SQL_SERVER=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.sqlServerName.value" -o tsv)

# Check SQL Server exists and firewall is open
az sql server show \
  --resource-group entra-demo-dev-rg \
  --name $SQL_SERVER

# Check firewall rules (should allow Azure services)
az sql server firewall-rule list \
  --resource-group entra-demo-dev-rg \
  --server $SQL_SERVER

# Verify connection string in Key Vault
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

az keyvault secret show \
  --vault-name $KV_NAME \
  --name SqlConnectionString \
  --query "value"

# Check API container logs for connection errors
az containerapp logs show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --tail 100 | grep -i "connection\|sql\|error"
```

### Key Vault Secrets Not Persisting After Redeployment

**Issue**: After running deployment the second time, Entra ID secrets (BffClientSecret, etc.) are overwritten or disappear

**Root Cause**: In the old code, the Bicep template was creating secrets with placeholder values on every deployment, overwriting any real values you had set

**Solution** (Fixed in New Code): 
- Optional secrets are only created if you provide a non-empty value
- Existing secrets are NEVER overwritten with placeholder values
- On subsequent deployments, secrets are left unchanged

**How to Set Optional Secrets:**

Option 1: During initial deployment (if you have values ready)
```bash
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=centralindia \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD \
    bffClientSecret="your-secret-value" \
    bffTenantId="your-tenant-id" \
    bffClientId="your-client-id" \
    apiAudience="api://your-api-id"
```

Option 2: Update after deployment (recommended - safer approach)
```bash
# First deployment: skip optional secrets
az deployment group create ... (as above without optional params)

# Later: Set/update secrets when you have Entra ID values
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

az keyvault secret set --vault-name $KV_NAME --name BffClientSecret \
  --value "your-actual-secret-value"

az keyvault secret set --vault-name $KV_NAME --name BffTenantId \
  --value "your-tenant-id"

# No need to redeploy - containers pick up new values automatically
```

Option 3: Update secrets anytime (safe - won't trigger redeployment)
```bash
# You can update secrets at any time without redeploying
# Containers will refresh on next restart
az keyvault secret set --vault-name $KV_NAME --name BffClientSecret \
  --value "updated-secret-value"

# Restart container to pick up new secret
az containerapp revision restart \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --revision bff-dev--<latest-revision>
```

### Verifying Idempotency Works

**Test 1: Redeployment with Same Parameters**
```bash
# Run deployment multiple times with identical parameters
# All subsequent runs should:
# ✅ Complete successfully (no errors)
# ✅ Complete faster (30-60 seconds)
# ✅ Show "No changes" in what-if output

az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters ... (same as before)

# Should output: "No changes" for all resources
```

**Test 2: Parameter Update**
```bash
# Change only one parameter
# what-if should show only that resource being modified

az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    ... (same as before except one param) \
    sqlAdminPassword="new-password"

# Should show: SqlAdminPassword resource being modified
# All other resources: No changes
```

**Test 3: Resource Preservation**
```bash
# Verify existing resources are not recreated
az deployment group list-resources \
  --resource-group entra-demo-dev-rg \
  --query "[].{Name:name, Type:type}" \
  --output table

# Run deployment again
az deployment group create ... (same parameters as before)

# List resources again - should be identical, no duplicates
az deployment group list-resources \
  --resource-group entra-demo-dev-rg \
  --query "[].{Name:name, Type:type}" \
  --output table
```

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Bicep Language](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Microsoft Entra ID](https://learn.microsoft.com/entra/identity/)
- [Azure DevOps Pipelines](https://learn.microsoft.com/azure/devops/pipelines/)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/)

## 🎯 Next Steps

1. **Review** the architecture and design
2. **Configure** Azure DevOps service connections and variable groups
3. **Setup** Entra ID app registrations (follow `docs/entra-id-prod-setup.md`)
4. **Deploy** infrastructure using `infra/main.bicep`
5. **Configure** Container Apps with Key Vault secrets
6. **Run** the CI/CD pipeline
7. **Monitor** applications in Application Insights

## 📝 License

[Specify your license here]

## 👥 Support

For questions or issues:
1. Check troubleshooting section
2. Review logs in Application Insights
3. Contact platform team
