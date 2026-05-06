# Infrastructure Validation & Deployment Guide

This guide walks through validating and deploying the Bicep infrastructure to Azure.

## 📋 Prerequisites

Before deploying, ensure you have:

```bash
# Install Azure CLI
az --version

# Verify logged in
az account show

# Create resource groups if they don't exist
az group create --name entra-demo-dev-rg --location eastus
az group create --name entra-demo-prod-rg --location eastus

# Create Azure Container Registry
az acr create --resource-group entra-demo-dev-rg \
  --name entrademodevacr --sku Basic
```

## 🔐 Step 1: Prepare Secrets

Store sensitive values in a safe location (do NOT commit to git):

### For Development
```bash
# ACR (Azure Container Registry) credentials
ACR_USERNAME=<your-acr-admin-username>
ACR_PASSWORD=<your-acr-admin-password>

# SQL Admin credentials
SQL_ADMIN_USERNAME=sqladmin
SQL_ADMIN_PASSWORD=<strong-password-min-12-chars>

# Optional: Entra ID values (for later)
ENTRA_TENANT_ID=<your-tenant-id>
ENTRA_BFF_CLIENT_ID=<bff-app-id>
ENTRA_BFF_CLIENT_SECRET=<bff-app-secret>
```

### For Azure DevOps Variable Groups
Go to **Azure DevOps → Pipelines → Library → Variable Groups**

Create group `entra-demo-dev-vars`:
- `registryUsername` = `<your-acr-username>` [✓ Mark as Secret]
- `registryPassword` = `<your-acr-password>` [✓ Mark as Secret]
- `sqlAdminPasswordDev` = `<strong-password>` [✓ Mark as Secret]

## ✅ Step 2: Validate Bicep Templates

### Local Validation

```bash
cd infra

# Validate syntax only
az bicep validate -f main.bicep

# Validate against Azure (requires resource group to exist)
az deployment group validate \
  --resource-group entra-demo-dev-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=eastus \
    environment=dev \
    projectName=entra-demo \
    registryUsername="dummy-user" \
    registryPassword="dummy-pass" \
    sqlAdminUsername="sqladmin" \
    sqlAdminPassword="dummy-pass"

# Expected output: "Validation passed"
```

### What Validation Checks

✅ Bicep syntax is correct  
✅ All referenced resources exist  
✅ Parameter types match  
✅ No linter warnings (code quality)  
✅ Template can deploy without errors

## 👀 Step 3: Preview Changes with What-If

**What-If shows what WILL happen when you deploy WITHOUT making changes.**

```bash
cd infra

az deployment group what-if \
  --resource-group entra-demo-dev-rg \
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

### Interpreting What-If Output

```
Resource Deployments change summary:

Resource type                         | Change | Before  | After
──────────────────────────────────────┼────────┼─────────┼────────
Microsoft.KeyVault/vaults             | Create | -       | -
Microsoft.KeyVault/vaults/secrets     | Create | -       | -
Microsoft.Sql/servers                 | Create | -       | -
Microsoft.Sql/servers/databases       | Create | -       | -
Microsoft.OperationalInsights/...     | Create | -       | -
Microsoft.App/containerApps           | Create | -       | -
```

- **Create** = New resource will be created
- **Modify** = Existing resource will be updated
- **Delete** = Resource will be deleted (review carefully!)
- **No Change** = Resource is already correct

## 🚀 Step 4: Deploy Infrastructure

### Option A: Azure CLI (Manual)

```bash
cd infra

# Deploy
az deployment group create \
  --resource-group entra-demo-dev-rg \
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

# Monitor deployment
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "{status:properties.provisioningState, timestamp:properties.timestamp}"
```

### Option B: Azure DevOps Pipeline (Automated)

The pipeline automatically:

1. **Validates** Bicep syntax and parameters
2. **Shows What-If** preview of changes
3. **Builds & Tests** frontend, BFF, and API
4. **Builds & Pushes** Docker images to ACR
5. **Deploys** infrastructure and container apps
6. **Verifies** health checks pass

To trigger pipeline:
```bash
# Push to develop branch
git push origin develop

# Pipeline automatically triggers and deploys to dev
```

## 📊 Step 5: Verify Deployment

### Check Deployment Status

```bash
# List all resources in resource group
az resource list \
  --resource-group entra-demo-dev-rg \
  --output table

# Check specific resource status
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.{status:provisioningState, outputs:outputs}"
```

### Access Deployed Resources

```bash
# Get Key Vault URI
KEYVAULT_NAME=$(az resource list \
  --resource-group entra-demo-dev-rg \
  --resource-type "Microsoft.KeyVault/vaults" \
  --query "[0].name" -o tsv)

KEYVAULT_URI=$(az keyvault show \
  --name $KEYVAULT_NAME \
  --query "properties.vaultUri" -o tsv)

echo "Key Vault: $KEYVAULT_URI"

# Get Container App URLs
az containerapp list \
  --resource-group entra-demo-dev-rg \
  --query "[].{name:name, fqdn:properties.configuration.ingress.fqdn}" \
  --output table

# Get SQL Server details
az sql server list \
  --resource-group entra-demo-dev-rg \
  --query "[].{name:name, fqdn:fullyQualifiedDomainName}" \
  --output table
```

## 🔧 Troubleshooting

### Validation Fails

```
Error: Template validation failed due to: BCP033 ...
```

**Solution:**
- Check parameter types match the template
- Verify resource group exists: `az group show --name entra-demo-dev-rg`
- Check Azure quotas: `az deployment group validate` shows detailed errors

### Deployment Fails - Resource Already Exists

```
Error: The resource 'xxx' already exists in location 'eastus' ...
```

**Solution:**
- Resource names use `uniqueString(projectName, environment, location)` to avoid conflicts
- Change `projectName` parameter if deploying multiple instances
- Or delete existing resources: `az group delete --name entra-demo-dev-rg`

### Container App Won't Start

```bash
# Check logs
az containerapp logs show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg

# Check provisioning state
az containerapp show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.provisioningState"
```

### Key Vault Access Denied

```
Error: You do not have authorization to perform action ...
```

**Solution:**
- Container app managed identity needs access policy
- Pipeline adds this automatically
- Or manually: `az keyvault set-policy --name $KEYVAULT_NAME --object-id $PRINCIPAL_ID --secret-permissions get list`

## 🔐 Security Checklist

- ✅ Never commit passwords to git
- ✅ Store secrets in Azure DevOps Variable Groups (marked as secret)
- ✅ Store runtime secrets in Key Vault
- ✅ Use managed identities for container app access
- ✅ Use `@secure()` decorator for sensitive parameters
- ✅ Remove passwords from resource outputs
- ✅ Enable Key Vault soft delete and purge protection

## 📚 Related Documentation

- [Pipeline Setup Guide](../docs/ci-cd-setup.md)
- [Deployment Guide](../docs/DEPLOYMENT.md)
- [Entra ID Configuration](../docs/entra-id-prod-setup.md)
- [Azure Bicep Best Practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)

