# Quick Deployment Guide

## Summary of Improvements

The infrastructure templates have been updated to be **fully idempotent** - meaning you can safely run deployments multiple times without errors or resource recreation.

### Key Benefits
- ✅ Run deployments repeatedly without fear of conflicts
- ✅ Safe to automate with CI/CD pipelines
- ✅ Secrets are no longer overwritten on re-deployment
- ✅ Only changed resources are updated
- ✅ Faster subsequent deployments (validation only)

---

## Deployment Sequence

### 1. Prerequisites
```bash
# Login
az login

# Set variables
export LOCATION="centralindia"
export ENVIRONMENT="dev"
export PROJECT="entra-demo"
export RG="entra-demo-${ENVIRONMENT}-rg"
export ACR_NAME="entrademodevacr"
export ACR_USERNAME="<your-acr-username>"
export ACR_PASSWORD="<your-acr-password>"
export SQL_PASSWORD="<strong-sql-password>"
```

### 2. Create Resource Group
```bash
az group create --name $RG --location $LOCATION
```

### 3. Deploy Infrastructure (Idempotent)
```bash
cd infra

az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=$LOCATION \
    environment=$ENVIRONMENT \
    projectName=$PROJECT \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminPassword=$SQL_PASSWORD
```

### 4. Configure Key Vault Secrets (Post-Deployment)
```bash
# Get Key Vault name
KV_NAME=$(az deployment group show \
  --resource-group $RG \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Set optional Entra ID secrets (if you have them)
az keyvault secret set --vault-name $KV_NAME --name BffClientSecret \
  --value "$BFF_CLIENT_SECRET"

az keyvault secret set --vault-name $KV_NAME --name BffTenantId \
  --value "$BFF_TENANT_ID"

az keyvault secret set --vault-name $KV_NAME --name BffClientId \
  --value "$BFF_CLIENT_ID"

az keyvault secret set --vault-name $KV_NAME --name ApiAudience \
  --value "$API_AUDIENCE"
```

### 5. Build and Push Docker Images
```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build frontend
az acr build --registry $ACR_NAME \
  --image entra-demo/frontend:latest \
  --file frontend/Dockerfile .

# Build BFF
az acr build --registry $ACR_NAME \
  --image entra-demo/bff:latest \
  --file bff/Dockerfile .

# Build API
az acr build --registry $ACR_NAME \
  --image entra-demo/api:latest \
  --file api/Dockerfile .
```

### 6. Verify Deployment
```bash
# Check deployment status
az deployment group show \
  --resource-group $RG \
  --name main \
  --query "properties.provisioningState"

# Get application URLs
az containerapp list \
  --resource-group $RG \
  --query "[].properties.configuration.ingress.fqdn"
```

---

## Idempotency Testing

### Test 1: Rerun with Same Parameters
```bash
# This should complete successfully and quickly
az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    location=$LOCATION \
    environment=$ENVIRONMENT \
    projectName=$PROJECT \
    registryUsername=$ACR_USERNAME \
    registryPassword=$ACR_PASSWORD \
    sqlAdminPassword=$SQL_PASSWORD

# Expected: "Deployment succeeded" in ~30 seconds
```

### Test 2: What-If (Safe Preview)
```bash
# See what WILL change before deployment
az deployment group what-if \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam

# Expected: "No changes" on second run with same parameters
```

### Test 3: Parameter Update
```bash
# Update only Docker images (push new version first)
az acr build --registry $ACR_NAME \
  --image entra-demo/api:latest \
  --file api/Dockerfile .

# Redeploy (only image config updates)
az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters ... (same as before)

# Expected: Container app quickly updates with new image
```

---

## Common Deployment Patterns

### Pattern 1: Initial Setup (First Time)
```bash
# 1. Deploy infrastructure
az deployment group create ... (as above)

# 2. Configure secrets manually (after getting Entra ID values)
az keyvault secret set --vault-name $KV_NAME --name BffClientSecret --value "..."

# 3. Deploy Docker images
az acr build --registry $ACR_NAME --image entra-demo/api:latest ...

# ✅ System is now live
```

### Pattern 2: Code Update (Update Docker Image Only)
```bash
# 1. Rebuild and push image
az acr build --registry $ACR_NAME --image entra-demo/api:latest --file api/Dockerfile .

# 2. Redeploy infrastructure (automatically picks up new image)
az deployment group create --resource-group $RG --template-file main.bicep ...

# ✅ New version deployed
```

### Pattern 3: Configuration Change (Update Parameter)
```bash
# 1. Change parameter (e.g., SQL password)
export SQL_PASSWORD="new-password-value"

# 2. Preview with what-if
az deployment group what-if --resource-group $RG --template-file main.bicep \
  --parameters ... (with new SQL_PASSWORD)

# 3. Deploy
az deployment group create --resource-group $RG --template-file main.bicep \
  --parameters ... (with new SQL_PASSWORD)

# ✅ Only affected resources are updated
```

### Pattern 4: Secret Update (No Redeployment Needed)
```bash
# Get Key Vault name
KV_NAME=$(az deployment group show --resource-group $RG --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Update secret
az keyvault secret set --vault-name $KV_NAME --name BffClientSecret \
  --value "new-secret-value"

# ❌ NO redeployment needed
# ✅ Containers automatically pick up new secret

# Optional: Restart container to force immediate refresh
az containerapp revision restart \
  --name bff-$ENVIRONMENT \
  --resource-group $RG \
  --revision bff-${ENVIRONMENT}--<revision-number>
```

---

## Troubleshooting Quick Reference

| Issue | Command | Notes |
|-------|---------|-------|
| Container won't start | `az containerapp logs show --name api-dev -g $RG` | Check logs for error details |
| Check secret exists | `az keyvault secret show --vault-name $KV_NAME --name BffClientSecret` | Verify secret was created |
| Verify image in ACR | `az acr repository show-tags --name $ACR_NAME --repository entra-demo/api` | Check if image was pushed |
| Validate template | `az deployment group validate --resource-group $RG --template-file main.bicep` | Catch errors before deploy |
| See what changed | `az deployment group what-if --resource-group $RG --template-file main.bicep` | Preview deployment |
| Check status | `az deployment group show --resource-group $RG --name main` | View deployment state |

---

## Important Notes

### What Changed in the Infrastructure

1. **Key Vault Secrets**: Optional secrets (BffClientSecret, etc.) are no longer overwritten with placeholders
2. **Access Policies**: Changed from 'add' to 'replace' mode for idempotency
3. **Container Apps Ordering**: Proper deployment order prevents CORS issues
4. **No Explicit dependsOn**: Relies on Bicep's symbolic reference tracking

### Best Practices

- ✅ Always use same deployment name (`main`)
- ✅ Use `what-if` before applying changes
- ✅ Store secrets separately from code
- ✅ Run deployment twice to verify idempotency
- ✅ Update secrets via Key Vault CLI, not redeployment
- ❌ Don't commit real secrets to git
- ❌ Don't manually edit resources (always use Bicep)
- ❌ Don't use different parameter files for same environment

### Secrets Management Flow

```
Initial Deployment
  ↓
Deploy Bicep (creates infrastructure)
  ↓
Manually Set Secrets in Key Vault
  ↓
Containers Start (read secrets from KV)
  ↓
Later: Update Secret → NO redeployment needed
```

---

## Key Vault Secrets Explained

| Secret | Type | Created How | Can Persist? |
|--------|------|-------------|--------------|
| `SqlAdminPassword` | Required | Automatic (from parameter) | ✅ Yes |
| `SqlConnectionString` | Required | Auto-generated | ✅ Yes |
| `ApplicationInsights--ConnectionString` | Required | Auto-generated | ✅ Yes |
| `BffClientSecret` | Optional | Only if provided | ✅ Yes (safe) |
| `BffTenantId` | Optional | Only if provided | ✅ Yes (safe) |
| `BffClientId` | Optional | Only if provided | ✅ Yes (safe) |
| `ApiAudience` | Optional | Only if provided | ✅ Yes (safe) |

**Optional secrets** are only created if you provide a non-empty value. On re-deployment, they are never overwritten.

---

## References

- [Detailed Deployment Guide](./DEPLOYMENT.md)
- [CI/CD Setup Guide](./ci-cd-setup.md)
- [Idempotency Fixes Documentation](../IDEMPOTENCY_FIXES.md)
- [Entra ID Setup Guide](./entra-id-prod-setup.md)
