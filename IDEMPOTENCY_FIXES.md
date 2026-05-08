# Bicep Idempotency Fixes

## Summary
Updated Bicep infrastructure templates to ensure idempotency when running `az deployment group create` multiple times. The deployment should now work correctly on subsequent runs without attempting to re-provision resources or failing.

## Changes Made

### 1. **Key Vault Module (modules/keyvault.bicep)**
**Issue**: Placeholder values (`placeholder-update-in-azure-portal`) were being set for Entra ID secrets on every deployment, overwriting any real values set manually.

**Fix**: 
- Added optional parameters for Entra ID secrets: `bffClientId`, `bffClientSecret`, `bffTenantId`, `apiAudience`
- All these parameters default to empty strings
- Secrets are only created when a non-empty value is provided using `if (!empty(param))`
- This prevents overwriting of manually-configured secrets on re-deployments

```bicep
// Only create BffClientSecret if a value is provided
resource bffClientSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(bffClientSecret)) {
  parent: keyVault
  name: 'BffClientSecret'
  properties: {
    value: bffClientSecret
  }
}
```

### 2. **Key Vault Access Policies Module (modules/keyvault-access-policies.bicep)**
**Issue**: Using `'add'` mode caused cumulative additions of access policies on each deployment.

**Fix**:
- Changed the access policy operation from `'add'` to `'replace'`
- This ensures policies are idempotently set rather than accumulated

```bicep
resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2025-05-01' = {
  parent: keyVault
  name: 'replace'  // Changed from 'add'
  properties: {
    // ...
  }
}
```

### 3. **Container Apps Module (modules/container-apps.bicep)**
**Issue**: No explicit ordering for dependent container apps; CORS policies referenced other apps that might not be fully deployed.

**Fixes**:
- Reordered container app declarations: API first, then Frontend, then BFF
- This ensures proper deployment order due to implicit dependencies from symbolic references
- API app has no dependencies (can deploy first)
- Frontend app depends on API through implicit references in template
- BFF app depends on Frontend for CORS policy (uses `frontendContainerApp.properties.configuration.ingress.fqdn`)

### 4. **Main Template (main.bicep)**
**Issue**: Removed unnecessary explicit `dependsOn` declarations that were conflicting with implicit symbolic dependencies.

**Fix**:
- Removed explicit `dependsOn` entries from the containerApps module
- Symbolic references in the module calls create implicit dependencies that are automatically handled by Bicep
- This satisfies the Bicep linter and maintains proper deployment ordering

## Resource Naming Stability

The infrastructure already uses stable naming patterns that ensure idempotency:

- **SQL Server**: Uses `uniqueString(projectName, environment, location)` - stable for same inputs
- **Container Registry**: Stable name without random suffixes (unless overridden)
- **Key Vault**: Static name based on `projectName` and `environment`
- **Container Apps Environment**: Static name based on `projectName` and `environment`
- **Container Apps**: Static names based on `environment`

## Testing the Idempotency

To test that the infrastructure is now idempotent:

```bash
# First deployment
az deployment group create \
  --resource-group <your-rg> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

# Second deployment (should complete successfully with no errors)
az deployment group create \
  --resource-group <your-rg> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

Both deployments should succeed without attempting to recreate existing resources or failing due to conflicts.

## Key Vault Secrets Management

For Entra ID configuration secrets, you have two options:

1. **During Deployment** (new): Pass them as parameters to the Bicep template
   ```bash
   az deployment group create \
     --resource-group <your-rg> \
     --template-file infra/main.bicep \
     --parameters infra/main.bicepparam \
                   bffClientId='<value>' \
                   bffClientSecret='<value>' \
                   bffTenantId='<value>' \
                   apiAudience='<value>'
   ```

2. **After Deployment** (existing approach): Set them manually in Azure Portal or via Azure CLI after the Key Vault is created
   ```bash
   az keyvault secret set --vault-name <kv-name> --name BffClientId --value '<value>'
   ```

## Bicep Validation

The templates have been validated and compile successfully:
```
az bicep build --file infra/main.bicep
```

Some non-critical warnings remain:
- BCP318 warnings for conditional module references (expected for `useExistingRegistry` pattern)
- `use-secure-value-for-secure-inputs` warnings for password parameters (correct behavior)

These warnings do not affect deployment functionality.
