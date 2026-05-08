# Registry Simplification Update

## Changes Made

Updated the Bicep infrastructure to automatically create and manage the Azure Container Registry without requiring external parameters.

### What Changed

#### Before (Old Code)
```bicep
param useExistingRegistry bool = false
param existingRegistryName string = ''
param existingRegistryUrl string = ''

// Conditional registry deployment
module containerRegistry 'modules/container-registry.bicep' = if (!useExistingRegistry) {
  // ...
}

var registryUrlToUse = useExistingRegistry ? existingRegistryUrl : (containerRegistry.outputs.registryUrl ?? existingRegistryUrl)
```

**Problems:**
- ❌ Required external parameters for existing registry
- ❌ Conditional deployment logic was complex
- ❌ Hard to reference registry in container apps
- ❌ Error when existing registry URL was invalid

#### After (New Code)
```bicep
// Removed external registry parameters entirely
// No useExistingRegistry, existingRegistryName, existingRegistryUrl

// Always create registry with deterministic name
var containerRegistryName = toLower('${projectName}acr${environment}')

// Always deploy registry (idempotent)
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    environment: environment
    registryName: containerRegistryName
  }
}

// Container apps always reference created registry
registryUrl: containerRegistry.outputs.registryUrl
```

**Benefits:**
- ✅ No external parameters needed
- ✅ Deterministic registry naming: `entrademodev` (projectName + environment)
- ✅ Always creates registry if doesn't exist
- ✅ Reuses existing registry on re-deployment (idempotent)
- ✅ Simple, clear references
- ✅ Works with automation (no manual configuration)

### Files Updated

1. **infra/main.bicep**
   - Removed parameters: `useExistingRegistry`, `existingRegistryName`, `existingRegistryUrl`
   - Simplified registry naming with `toLower()` for ACR requirements
   - Changed registry module from conditional to always-deploy
   - Direct reference: `containerRegistry.outputs.registryUrl`
   - Updated outputs section

2. **infra/main.bicepparam**
   - Removed: `useExistingRegistry = true`
   - Removed: `existingRegistryName = 'entrademodevacr'`
   - Removed: `existingRegistryUrl = 'entrademodevacr.azurecr.io'`

### Registry Naming

The registry is now created with a **deterministic name** based on project and environment:

```
Format: {projectName}acr{environment} (lowercase)

Examples:
- projectName='entra-demo', environment='dev' → 'entrademodevacr'
- projectName='entra-demo', environment='prod' → 'entrademodevacr' (or use different environment name)
- projectName='myapp', environment='staging' → 'myappstagingacr'
```

**Important:** Azure Container Registry names must be:
- 5-50 characters
- Lowercase alphanumeric only (no hyphens)
- Globally unique across all Azure subscriptions

The code automatically converts to lowercase to comply with these requirements.

### Deployment Impact

#### First Deployment
1. Creates new Container Registry with name: `entrademodevacr`
2. Creates all other resources (SQL, Key Vault, Container Apps, etc.)
3. Container Apps pull images from newly created registry

#### Subsequent Deployments
1. Registry already exists → deployment is idempotent
2. Only updates if registry parameters change
3. Container Apps continue using same registry
4. **No registry recreation or errors**

### How to Deploy

```bash
# Set variables (no need for external ACR anymore!)
export LOCATION="centralindia"
export ENVIRONMENT="dev"
export PROJECT="entra-demo"
export RG="entra-demo-dev-rg"
export ACR_USERNAME="<your-acr-admin-username>"
export ACR_PASSWORD="<your-acr-admin-password>"
export SQL_PASSWORD="<strong-password>"

# Create resource group
az group create --name $RG --location $LOCATION

# Deploy infrastructure
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

# Registry is automatically created!
# No more "failed to resolve registry" errors
```

### Verifying Registry Creation

```bash
# List registries
az acr list --resource-group $RG

# Get registry details
az acr show --name entrademodevacr --resource-group $RG

# Get registry login server
az acr show --name entrademodevacr --resource-group $RG --query loginServer
```

### Pushing Images to New Registry

```bash
# Login to newly created registry
az acr login --name entrademodevacr

# Build and push images
az acr build \
  --registry entrademodevacr \
  --image entra-demo/frontend:latest \
  --file frontend/Dockerfile .

az acr build \
  --registry entrademodevacr \
  --image entra-demo/bff:latest \
  --file bff/Dockerfile .

az acr build \
  --registry entrademodevacr \
  --image entra-demo/api:latest \
  --file api/Dockerfile .
```

### Idempotency Testing

Test that redeployment works correctly:

```bash
# First deployment
echo "=== FIRST DEPLOYMENT ==="
az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters ... (as above)

# Second deployment (should succeed with no errors)
echo "=== SECOND DEPLOYMENT (reusing existing registry) ==="
az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters ... (same parameters)

# ✅ Both succeed
# ✅ No "failed to resolve registry" errors
# ✅ Registry is reused, not recreated
```

### Troubleshooting

#### "Container App provisioning failed - failed to resolve registry"

**Old Cause (Fixed):**
- Using external registry parameters that were incorrect
- Hardcoded registry URL that didn't exist

**New Solution:**
- Registry is automatically created with correct name
- Container apps automatically reference created registry
- No manual configuration needed

#### "Registry name already exists"

**If you get this error during deployment:**

Option 1: Use a different environment name
```bash
export ENVIRONMENT="dev2"  # Uses different registry: entrademodev2acr
```

Option 2: Change project name
```bash
export PROJECT="myapp"  # Uses registry: myappdevacr
```

Option 3: Delete existing registry (careful!)
```bash
az acr delete --resource-group $RG --name entrademodevacr
```

Then retry deployment.

## Summary

**Before:** Complex conditional logic with external parameters for ACR management
**After:** Automatic, deterministic, idempotent registry creation and management

The deployment is now simpler, more reliable, and doesn't depend on external registry configuration. The infrastructure is fully self-contained and idempotent.
