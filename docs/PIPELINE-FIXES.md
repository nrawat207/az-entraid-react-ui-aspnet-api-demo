# Pipeline Deployment Fixes - Summary

## Issues Fixed

### 1. ✅ Container Registry (ACR) Name Error
**Problem**: Bicep was creating a new ACR with an invalid name `entra-demoacrmopo3z5as2ppe` (contains hyphens converted incorrectly, too long).

**Solution**:
- Updated `main.bicep` to support using an **existing ACR** instead of creating a new one
- Added parameters:
  - `useExistingRegistry` (boolean) - Set to `true` to skip ACR creation
  - `existingRegistryName` - Name of existing ACR (e.g., `entrademodevacr`)
  - `existingRegistryUrl` - Full URL of existing ACR (e.g., `entrademodevacr.azurecr.io`)
- Made the container registry module conditional: `module containerRegistry ... = if (!useExistingRegistry)`
- Updated container apps to use either new or existing registry URL

**Files Modified**:
- `infra/main.bicep` - Added conditional registry deployment
- `infra/main.bicepparam` - Set `useExistingRegistry = true` and configured existing registry details
- `azure-pipelines.yml` - Pass existing registry parameters to all deployment steps

---

### 2. ✅ Microsoft.OperationalInsights Registration
**Problem**: Subscription not registered for `Microsoft.OperationalInsights` provider, causing monitoring module deployment to fail.

**Solution**:
- Added provider registration step before Bicep validation in `ValidateInfra` stage
- Registers all required providers:
  - `Microsoft.OperationalInsights`
  - `Microsoft.ContainerRegistry`
  - `Microsoft.ContainerService`
  - `Microsoft.Sql`
  - `Microsoft.KeyVault`
  - `Microsoft.Insights`

**Files Modified**:
- `azure-pipelines.yml` - New task "Register required Azure providers" in ValidateInfra stage

---

### 3. ✅ Parameter Bug Fix
**Problem**: In ValidateInfra stage, `registryPassword` was being passed as `$(registryUsername)` (copy-paste error).

**Solution**:
- Fixed parameter passing to use correct variable: `registryPassword="$(registryPassword)"`
- Also fixed in WhatIfInfra and DeployToDev stages

**Files Modified**:
- `azure-pipelines.yml` - All deployment steps now use correct parameter mapping

---

### 4. ⚠️ SQL Database Provisioning - Region Restriction (REQUIRES ACTION)
**Problem**: Error states "Provisioning is restricted in this region" for SQL Database in eastus.

**Possible Solutions**:
- **Option A**: Change region in `main.bicepparam`:
  ```bicep
  param location = 'westus2'  # or 'canadacentral', 'northeurope', etc.
  ```
  
- **Option B**: Disable SQL deployment if not needed (modify Bicep to make SQL optional)
  
- **Option C**: Contact Azure Support for region provisioning exceptions

**Recommended**:
Try changing location to `westus2` or check Azure region availability for SQL Database in your subscription tier.

---

## Pre-Deployment Checklist

✅ **Manual Setup (Already Done)**:
- [ ] Resource group created: `entra-demo-dev-rg`
- [ ] Container Registry created: `entrademodevacr` in `eastus`
- [ ] ACR login credentials obtained

✅ **Pipeline Variable Group Setup (REQUIRED)**:

Create a variable group named `entra-demo-dev-vars` in Azure DevOps with these secrets:

```
registryUsername = <ACR username>
registryPassword = <ACR password>
sqlAdminUsernameDev = sqladmin
sqlAdminPasswordDev = <strong password>
imageRepository = entra-demo
```

**How to Create in Azure DevOps**:
1. Go to Pipelines → Library → Variable Groups
2. Click "+ Variable group"
3. Name: `entra-demo-dev-vars`
4. Add variables (mark passwords as Secret with lock icon)
5. Save
6. Allow pipeline access

---

## Updated Pipeline Parameters

The pipeline now passes these parameters to Bicep:

```powershell
# Original parameters
location = "$(azureLocationDev)"              # eastus (or your region)
environment = "dev"
projectName = "entra-demo"
imageRepository = "$(imageRepository)"        # entra-demo
registryUsername = "$(registryUsername)"      # From variable group
registryPassword = "$(registryPassword)"      # From variable group (secret)
sqlAdminUsername = "$(sqlAdminUsernameDev)"   # From variable group
sqlAdminPassword = "$(sqlAdminPasswordDev)"   # From variable group (secret)

# NEW parameters for existing ACR
useExistingRegistry = true
existingRegistryName = "entrademodevacr"
existingRegistryUrl = "entrademodevacr.azurecr.io"
```

---

## Deployment Flow

1. **Validate Infrastructure**
   - Register Azure providers (NEW)
   - Validate Bicep templates
   
2. **What-If Analysis**
   - Preview infrastructure changes
   
3. **Build & Test**
   - Build Frontend (Node.js)
   - Build BFF (.NET 10)
   - Build API (.NET 10)
   
4. **Build & Push Docker Images**
   - Push to existing ACR (entrademodevacr)
   
5. **Deploy to Development**
   - Deploy infrastructure via Bicep (using existing ACR)
   - Update container apps with new images
   - Verify health checks

---

## Troubleshooting

### If you still get ACR errors:
- Verify ACR exists: `az acr list --resource-group entra-demo-dev-rg`
- Verify ACR URL format: `entrademodevacr.azurecr.io`
- Check credentials in variable group

### If OperationalInsights still fails:
```powershell
az provider show --namespace Microsoft.OperationalInsights --query "registrationState"
# Should return "Registered"
```

### If SQL still fails:
Check region availability:
```powershell
az provider show --namespace Microsoft.Sql --query "resourceTypes[?resourceType=='servers'].locations[]"
```

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `infra/main.bicep` | Added ACR parameters, made registry conditional |
| `infra/main.bicepparam` | Configured existing ACR settings |
| `azure-pipelines.yml` | Added provider registration, fixed parameters |

---

## Next Steps

1. Verify the variable group is created in Azure DevOps
2. Update region if needed based on SQL availability
3. Trigger pipeline and monitor ValidateInfra stage
4. Check provider registration completes successfully
5. Proceed with deployment if validation passes
