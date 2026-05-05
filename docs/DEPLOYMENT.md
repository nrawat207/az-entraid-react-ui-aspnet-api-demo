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

### 3. Deploy to Azure

```bash
# Login to Azure
az login

# Create resource group
az group create --name entra-demo-dev-rg --location eastus

# Deploy infrastructure
cd infra
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=eastus \
    environment=dev \
    projectName=entra-demo \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword=$SQL_PASSWORD

# Build and push Docker images
az acr build --registry entrademodevacr \
  --image frontend:latest \
  --file frontend/Dockerfile .

# (Repeat for bff and api)
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

### Container won't start
```bash
# Check logs
az containerapp logs show --name bff-dev --resource-group entra-demo-dev-rg

# Check image exists in ACR
az acr repository list --name entrademodevacr

# Verify Key Vault access
az keyvault show --name entra-demo-kv-xxxxx
```

### Authentication fails
```bash
# Verify Entra ID secrets in Key Vault
az keyvault secret list --vault-name entra-demo-kv-xxxxx

# Check BFF logs for auth errors
az containerapp logs show --name bff-dev --resource-group entra-demo-dev-rg
```

### Database connection fails
```bash
# Check SQL Server firewall
az sql server firewall-rule list \
  --resource-group entra-demo-dev-rg \
  --server entra-demo-sql-xxxxx

# Verify connection string in Key Vault
az keyvault secret show --vault-name entra-demo-kv-xxxxx --name SqlConnectionString
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
