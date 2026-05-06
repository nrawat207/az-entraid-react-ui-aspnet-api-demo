# Deployment Checklist & Final Setup

Complete this checklist to finalize your infrastructure and pipeline setup.

## ✅ Phase 1: Azure Setup (One-Time)

- [ ] **Azure Subscription**
  - [ ] Subscription ID noted: `__________________`
  - [ ] Sufficient quota for resources (VMs, databases, etc.)
  - [ ] Billing alerts configured

- [ ] **Resource Groups Created**
  ```bash
  az group create --name entra-demo-dev-rg --location eastus
  az group create --name entra-demo-prod-rg --location eastus
  ```
  - [ ] Development RG created: `entra-demo-dev-rg`
  - [ ] Production RG created: `entra-demo-prod-rg`

- [ ] **Azure Container Registry**
  ```bash
  az acr create --resource-group entra-demo-dev-rg \
    --name entrademodevacr --sku Basic
  ```
  - [ ] ACR created: `entrademodevacr`
  - [ ] Admin credentials obtained

- [ ] **Key Vault (Optional for Pipeline)**
  - [ ] Created in dev resource group
  - [ ] Soft delete enabled
  - [ ] Access policies configured

---

## ✅ Phase 2: Azure DevOps Setup (One-Time)

- [ ] **Azure DevOps Project**
  - [ ] Project created: `__________________`
  - [ ] Git repository connected
  - [ ] Repository cloned locally

- [ ] **Service Connections**
  1. **Azure Resource Manager (Dev)**
     - [ ] Name: `AzureServiceConnection`
     - [ ] Subscription: `__________________`
     - [ ] Resource Group: `entra-demo-dev-rg`
     - [ ] Test connection successful ✓

  2. **Docker Registry (ACR)**
     - [ ] Name: `AcrConnection`
     - [ ] Registry: `entrademodevacr.azurecr.io`
     - [ ] Username: `__________________`
     - [ ] Password: `__________________`
     - [ ] Test connection successful ✓

- [ ] **Variable Groups**
  1. Create Group: `entra-demo-dev-vars`
     - [ ] Non-Secret Variables:
       - `sqlAdminUsernameDev` = `sqladmin`
     - [ ] Secret Variables (Mark with 🔒):
       - `registryUsername` = `__________________` 🔒
       - `registryPassword` = `__________________` 🔒
       - `sqlAdminPasswordDev` = `__________________` 🔒
       - `BffTenantId` = `__________________` 🔒
       - `BffClientId` = `__________________` 🔒
       - `BffClientSecret` = `__________________` 🔒
       - `ApiAudience` = `__________________` 🔒

---

## ✅ Phase 3: Infrastructure Validation

- [ ] **Bicep Syntax Check**
  ```bash
  cd infra
  az bicep validate -f main.bicep
  ```
  - [ ] Validation passed with no errors

- [ ] **Template Validation**
  ```bash
  az deployment group validate \
    --resource-group entra-demo-dev-rg \
    --template-file infra/main.bicep \
    --parameters infra/main.bicepparam \
    --parameters \
      registryUsername="test" \
      registryPassword="test" \
      sqlAdminPassword="test"
  ```
  - [ ] Validation passed
  - [ ] No linter warnings

- [ ] **What-If Preview**
  ```bash
  az deployment group what-if \
    --resource-group entra-demo-dev-rg \
    --template-file infra/main.bicep \
    --parameters infra/main.bicepparam \
    --parameters \
      registryUsername="$ACR_USERNAME" \
      registryPassword="$ACR_PASSWORD" \
      sqlAdminPassword="$SQL_PASSWORD"
  ```
  - [ ] Preview shows expected resources to create
  - [ ] No unexpected deletions
  - [ ] Review changes approved

---

## ✅ Phase 4: Manual Infrastructure Deployment (Recommended First Time)

First-time setup: Deploy manually to verify everything works.

```bash
# Set variables
export ACR_USERNAME=<your-acr-username>
export ACR_PASSWORD=<your-acr-password>
export SQL_ADMIN_PASSWORD=<strong-password>
export RESOURCE_GROUP=entra-demo-dev-rg

# Deploy
cd infra
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=eastus \
    environment=dev \
    projectName=entra-demo \
    registryUsername="$ACR_USERNAME" \
    registryPassword="$ACR_PASSWORD" \
    sqlAdminUsername="sqladmin" \
    sqlAdminPassword="$SQL_ADMIN_PASSWORD"
```

- [ ] Deployment started successfully
- [ ] Monitor status:
  ```bash
  az deployment group show \
    --resource-group $RESOURCE_GROUP \
    --name main \
    --query "properties.provisioningState"
  ```
  - [ ] Status: `Succeeded`
  - [ ] Deployment completed (10-15 minutes)

---

## ✅ Phase 5: Verify Deployed Resources

```bash
# List all resources
az resource list --resource-group entra-demo-dev-rg --output table

# Check Key Vault
az keyvault show --name $(az resource list \
  --resource-group entra-demo-dev-rg \
  --resource-type "Microsoft.KeyVault/vaults" \
  --query "[0].name" -o tsv)

# Check SQL Server
az sql server list --resource-group entra-demo-dev-rg --output table

# Check Container Apps
az containerapp list --resource-group entra-demo-dev-rg --output table

# Get Container App URLs
az containerapp show --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn"
```

- [ ] Key Vault created and accessible
- [ ] SQL Server created with database
- [ ] Container Registry accessible
- [ ] 3 Container Apps created (frontend, bff, api)
- [ ] Each has correct FQDN/URL

---

## ✅ Phase 6: Configure Entra ID (Microsoft 365 Tenant)

See [Entra ID Setup Guide](docs/entra-id-prod-setup.md)

- [ ] **BFF App Registration**
  - [ ] Name: `entra-demo-bff`
  - [ ] Supported account types: Selected
  - [ ] Redirect URIs: Added
  - [ ] Client secret created
  - [ ] Secret value saved: `__________________`

- [ ] **API App Registration**
  - [ ] Name: `entra-demo-api`
  - [ ] API scope `access_as_user` created
  - [ ] Client ID saved: `__________________`

- [ ] **Update Key Vault Secrets**
  ```bash
  az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name BffTenantId \
    --value <tenant-id>
  
  az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name BffClientId \
    --value <bff-client-id>
  
  az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name BffClientSecret \
    --value <bff-client-secret>
  
  az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name ApiAudience \
    --value "api://<api-client-id>"
  ```
  - [ ] All secrets updated in Key Vault

---

## ✅ Phase 7: Build & Push Docker Images

```bash
# Build frontend
cd frontend
npm ci
npm run build
cd ..

# Build and push images
az acr build --registry entrademodevacr \
  --image entra-demo/frontend:latest \
  --file frontend/Dockerfile .

az acr build --registry entrademodevacr \
  --image entra-demo/bff:latest \
  --file bff/Dockerfile .

az acr build --registry entrademodevacr \
  --image entra-demo/api:latest \
  --file api/Dockerfile .
```

- [ ] Frontend image built and pushed
- [ ] BFF image built and pushed
- [ ] API image built and pushed
- [ ] All images tagged as `latest`

---

## ✅ Phase 8: Deploy Container Apps with New Images

```bash
# Update container apps with new images
az containerapp update \
  --name frontend-dev \
  --resource-group entra-demo-dev-rg \
  --image entrademodevacr.azurecr.io/entra-demo/frontend:latest

az containerapp update \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --image entrademodevacr.azurecr.io/entra-demo/bff:latest

az containerapp update \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --image entrademodevacr.azurecr.io/entra-demo/api:latest
```

- [ ] Frontend updated and running
- [ ] BFF updated and running
- [ ] API updated and running

---

## ✅ Phase 9: Configure Pipeline for Automated Deployment

```bash
# Push code to Azure DevOps
git add .
git commit -m "Finalize infrastructure and pipeline setup"
git push origin develop
```

- [ ] Code pushed to `develop` branch
- [ ] Pipeline triggered automatically
- [ ] **Wait for pipeline to complete** (5-10 minutes)

**Pipeline Stages:**
- [ ] Stage 0: Validate ✓
- [ ] Stage 1: What-If ✓
- [ ] Stage 2: Build & Test ✓
- [ ] Stage 3: Build Docker ✓
- [ ] Stage 4: Deploy ✓

---

## ✅ Phase 10: Final Verification

```bash
# Get application URLs
echo "Frontend: https://$(az containerapp show --name frontend-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)"

echo "BFF: https://$(az containerapp show --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)"

echo "API: http://$(az containerapp show --name api-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)"

# Test health endpoints
BFF_URL=$(az containerapp show --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)

curl -k https://$BFF_URL/health

API_URL=$(az containerapp show --name api-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)

curl http://$API_URL/health
```

- [ ] Frontend URL accessible: `__________________`
- [ ] BFF URL accessible: `__________________`
- [ ] API URL accessible: `__________________`
- [ ] BFF health check responds: `{"status":"healthy"}`
- [ ] API health check responds: `{"status":"healthy"}`

---

## ✅ Phase 11: Production Deployment (Optional)

When ready to deploy to production:

```bash
# Create main branch and push
git checkout -b main
git push origin main
```

- [ ] Production pipeline runs (requires manual approval)
- [ ] Resources created in `entra-demo-prod-rg`
- [ ] Production database configured with Premium tier
- [ ] Higher replica count (2-3 instances)

---

## 🎯 Done!

Your infrastructure and CI/CD pipeline are now fully configured!

### Summary of Deployed Resources

| Component | Details |
|-----------|---------|
| **Resource Group** | `entra-demo-dev-rg` |
| **Container Registry** | `entrademodevacr.azurecr.io` |
| **Key Vault** | `entra-demo-kv-<suffix>` |
| **SQL Database** | `entra-demo-sql-<suffix>` / `entraddemodb` |
| **Container Apps Env** | `entra-demo-cae-dev` |
| **Frontend App** | `frontend-dev` (React 19) |
| **BFF App** | `bff-dev` (.NET 10) |
| **API App** | `api-dev` (.NET 10) |
| **Application Insights** | `entra-demo-ai-dev` |
| **Log Analytics** | `entra-demo-law-dev` |

### Next Steps

1. **Entra ID Setup** → [docs/entra-id-prod-setup.md](docs/entra-id-prod-setup.md)
2. **Monitor Application** → Azure Portal → Application Insights
3. **Configure Alerts** → Application Insights → Alert rules
4. **Auto-Scale** → Container Apps → Scale and replicas

### Documentation

- [Infrastructure Validation & Deployment](. azure/infra-validation-deployment.md)
- [CI/CD Pipeline Setup](docs/ci-cd-setup.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Entra ID Configuration](docs/entra-id-prod-setup.md)

### Support

For issues, check:
1. Pipeline logs: Azure DevOps → Pipelines → Your Pipeline → Logs
2. Container logs: `az containerapp logs show --name <app-name> ...`
3. Key Vault access: `az keyvault secret list --vault-name <vault-name>`
4. SQL Server: Azure Portal → SQL servers → Firewall rules

