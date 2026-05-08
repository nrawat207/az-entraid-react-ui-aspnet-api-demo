# CI/CD Pipeline Setup Guide

## Pipeline Architecture

The Azure DevOps pipeline automates the complete build and deployment workflow:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Code Push (develop/main)                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  STAGE 0: VALIDATE          │
                │  - Bicep syntax check       │
                │  - Parameter validation     │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  STAGE 1: WHAT-IF           │
                │  - Preview all changes      │
                │  - Review before deploy     │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  STAGE 2: BUILD & TEST      │
                │  - Frontend build           │
                │  - BFF build                │
                │  - API build                │
                │  - Run unit tests           │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  STAGE 3: DOCKER            │
                │  - Build images             │
                │  - Push to ACR              │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  STAGE 4: DEPLOY            │
                │  (if develop branch)        │
                │  - Deploy Bicep infra       │
                │  - Update container apps    │
                │  - Health checks            │
                └──────────────────────────────┘
```

## Prerequisites

### 1. Azure DevOps Setup

- Azure DevOps project created
- Git repository connected (GitHub or Azure Repos)
- Service connections configured
- Variable groups created

### 2. Service Connections

In **Azure DevOps → Project Settings → Service connections**, create:

#### a) Azure Resource Manager (Dev)
- **Name:** `AzureServiceConnection`
- **Scope:** Subscription or Resource Group
- **Resource Group:** `entra-demo-dev-rg`

#### b) Azure Container Registry
- **Name:** `AcrConnection`
- **Registry:** `entrademodevacr.azurecr.io`
- **Authentication:** Admin account or Service Principal

### 3. Variable Groups

In **Azure DevOps → Pipelines → Library → Variable Groups**:

#### Group: `entra-demo-dev-vars`
Create and mark secrets with lock icon:

```
Non-Secret Values:
- sqlAdminUsernameDev = sqladmin

Secret Values (Mark as Secret ⭐):
- registryUsername = <your-acr-admin-username>
- registryPassword = <your-acr-admin-password>
- sqlAdminPasswordDev = <strong-password>
- BffTenantId = <your-entra-tenant-id>
- BffClientId = <bff-app-client-id>
- BffClientSecret = <bff-app-secret>
- ApiAudience = api://<api-app-client-id>
```

**How to Mark as Secret:**
1. Click the lock icon next to the variable
2. It will show a padlock 🔒
3. Value will be masked in logs

## Pipeline Stages Explained

### Stage 0: Validate Infrastructure

Validates Bicep templates WITHOUT making changes.

```bash
az deployment group validate \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters \
    registryUsername="$(registryUsername)" \
    registryPassword="$(registryPassword)" \
    sqlAdminPassword="$(sqlAdminPasswordDev)"
```

**Checks:**
✅ Bicep syntax is correct  
✅ All parameters are valid  
✅ Resource types exist  
✅ No duplicate resource names  
✅ Template logic is correct

**Fails If:**
❌ Syntax errors found  
❌ Required parameters missing  
❌ Resource group doesn't exist  
❌ Insufficient permissions  
❌ Parameter type mismatches

### Stage 1: What-If (Preview)

Shows all changes that WILL be made during deployment without applying them.

```bash
az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters \
    registryUsername="$(registryUsername)" \
    registryPassword="$(registryPassword)" \
    sqlAdminPassword="$(sqlAdminPasswordDev)"
```

**Output Shows:**
- Which resources will be **Created** (new)
- Which will be **Modified** (updated)
- Which will be **Deleted** (removed)
- Which have **No Change** (already correct)

**Use This To:**
- Review infrastructure changes before they happen
- Catch accidental deletions
- Understand deployment impact
- Verify configuration changes

**Example Output:**
```
Resource and property changes are indicated with these symbols:
  + Create
  ~ Modify
  - Delete
  = No change

...
+ Microsoft.KeyVault/vaults/secrets 'entra-demo-kv-dev/SqlAdminPassword'
~ Microsoft.App/containerApps 'api-dev'
  - modify properties.template.containers[0].image
= Microsoft.Sql/servers 'entra-demo-sql-xxxxx'
```

### Stage 2: Build & Test

Builds all applications and runs unit tests.

**Steps:**
1. **Frontend Build**
   - `npm install` - Install dependencies
   - `npm run build` - Build React app with Vite
   - `npm run lint` - ESLint code quality checks

2. **BFF Build**
   - `dotnet restore` - Restore NuGet packages
   - `dotnet build` - Compile .NET code
   - `dotnet test` - Run unit tests

3. **API Build**
   - `dotnet restore` - Restore NuGet packages
   - `dotnet build` - Compile .NET code
   - `dotnet test` - Run unit tests

**Artifacts Generated:**
- `frontend/dist/` - Built React app (static files)
- `bff/bin/Release/` - Compiled BFF binaries
- `api/bin/Release/` - Compiled API binaries
- Test reports (xUnit/NUnit)

**Fails If:**
❌ Compilation errors  
❌ Linting failures  
❌ Unit test failures  
❌ TypeScript type errors

### Stage 3: Build & Push Docker

Creates Docker images from built artifacts and pushes to Azure Container Registry.

**Before Pushing:**
- Validates ACR login credentials
- Confirms ACR registry exists
- Verifies network connectivity

**Images Created:**
```
entrademodevacr.azurecr.io/entra-demo/frontend:latest
entrademodevacr.azurecr.io/entra-demo/frontend:develop-<build-id>
entrademodevacr.azurecr.io/entra-demo/frontend:<git-commit-sha>

entrademodevacr.azurecr.io/entra-demo/bff:latest
entrademodevacr.azurecr.io/entra-demo/bff:develop-<build-id>
entrademodevacr.azurecr.io/entra-demo/bff:<git-commit-sha>

entrademodevacr.azurecr.io/entra-demo/api:latest
entrademodevacr.azurecr.io/entra-demo/api:develop-<build-id>
entrademodevacr.azurecr.io/entra-demo/api:<git-commit-sha>
```

**Tags Explained:**
- `latest` - Most recent successful build
- `develop-<id>` - Branch-specific build tracking
- `<sha>` - Git commit SHA for version tracking

### Stage 4: Deploy (Idempotent Infrastructure)

Deploys infrastructure using Bicep templates with **idempotent operations**—safe to run multiple times.

**Deployment Process:**

1. **Deploy Bicep Infrastructure**
   ```bash
   az deployment group create \
     --resource-group entra-demo-dev-rg \
     --template-file infra/main.bicep \
     --parameters ... (secrets from pipeline variables)
   ```

2. **Resource Deployment Order** (automatic, parallel where possible):
   - ✅ Monitoring (Log Analytics + App Insights)
   - ✅ SQL Database
   - ✅ Container Registry (if not using existing)
   - ✅ Key Vault with initial secrets
   - ✅ Container Apps Environment
   - ✅ Container Apps (Frontend, BFF, API in order)

3. **Post-Deployment Configuration**
   - Update Key Vault with Entra ID secrets (from pipeline variables)
   - Verify container app provisioning state
   - Trigger container apps to pull latest image

4. **Health Verification**
   - BFF responds to `/health` endpoint
   - API provisioning state is "Succeeded"
   - Containers are in "Running" state

**Idempotency Guarantees:**
- ✅ Re-running deployment is safe (won't fail)
- ✅ Existing resources are left unchanged if parameters didn't change
- ✅ Only modified resources are updated
- ✅ Key Vault secrets won't be overwritten with placeholders
- ✅ Access policies are properly merged (replace mode)

**Example - Running Deployment Twice:**
```bash
# First run: Creates all resources
$ az deployment group create ... 
Deployment succeeded. Resources created: 15

# Second run: Only updates what changed
$ az deployment group create ...
Deployment succeeded. Resources modified: 0
# (Nothing changed because parameters are identical)
```

## Triggering the Pipeline

### Automatic Triggers

Pipeline automatically runs when:
- Code is pushed to `develop` branch (deploys to dev)
- Code is pushed to `main` branch (requires approval before prod)
- Pull request is created to `main` or `develop`

### Manual Trigger

In **Azure DevOps → Pipelines**:
1. Click your pipeline
2. Click "Run pipeline"
3. Select branch
4. Click "Run"

## Environment-Specific Settings

### Development (`develop` branch)

| Setting | Value |
|---------|-------|
| **Auto-Deploy** | Yes |
| **Approval** | None required |
| **Database** | Basic tier (2GB) |
| **Container Replicas** | 1 instance |
| **Secrets Storage** | Key Vault |
| **Logs Retention** | 30 days |

### Production (`main` branch)

```yaml
# Currently commented out - uncomment when ready
# Requires manual approval before deployment
# Uses different resource group (entra-demo-prod-rg)
# Uses different database tier (Standard/Premium)
# Higher replica count (2-3 instances)
```

## Secrets Management

### How Secrets Are Handled

1. **In Pipeline Variable Groups** (Pipeline/Runtime Secrets)
   - Marked with lock icon 🔒 in Azure DevOps
   - Automatically masked in pipeline logs
   - Passed securely to Bicep deployment as parameters
   - Never visible in pipeline output or logs
   - Stored encrypted in Azure DevOps

2. **In Key Vault** (Application Runtime Secrets)
   - SQL admin password
   - Entra ID credentials (BFF Client Secret, Tenant ID, etc.)
   - App Insights connection string
   - Accessed by containers via Managed Identity
   - Can be updated independently without redeployment

3. **Never in Parameter Files**
   - `main.bicepparam` contains only non-sensitive defaults
   - Real values are ALWAYS passed at deployment time
   - Never commit secrets to git repository

### Key Vault Secrets Configuration

The Bicep templates have been updated to safely handle secrets in an **idempotent** way:

#### Optional Secrets (Entra ID Configuration)

These secrets are **optional** and only created if a value is provided:
- `BffClientSecret`
- `BffTenantId`
- `BffClientId`
- `ApiAudience`

**Benefits:**
- ✅ First deployment can skip optional secrets
- ✅ Secrets won't be overwritten with placeholders on redeploy
- ✅ Can be manually updated in Key Vault after deployment
- ✅ Safe to run deployment multiple times

**How to Set Optional Secrets:**

Option 1: During initial deployment
```bash
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    bffClientSecret="$BFF_CLIENT_SECRET" \
    bffTenantId="$BFF_TENANT_ID" \
    bffClientId="$BFF_CLIENT_ID" \
    apiAudience="$API_AUDIENCE"
```

Option 2: Update after deployment (recommended)
```bash
# Get Key Vault name from deployment outputs
KV_NAME=$(az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.outputs.keyVaultName.value" -o tsv)

# Set or update secrets at any time
az keyvault secret set \
  --vault-name $KV_NAME \
  --name BffClientSecret \
  --value "$BFF_CLIENT_SECRET"

# No need to redeploy - containers pick up changes automatically
```

#### Required Secrets

These secrets are created automatically:
- `SqlAdminPassword` - Created from deployment parameter
- `SqlConnectionString` - Auto-generated from server details
- `ApplicationInsights--ConnectionString` - Auto-generated

### Adding New Secrets to Pipeline

To add a new secret to your CI/CD pipeline:

1. Go to **Azure DevOps → Pipelines → Library → Variable Groups**
2. Click `entra-demo-dev-vars`
3. Click "+ Add"
4. Enter variable name and value
5. **Click the lock icon 🔒 to mark as Secret** (critical step!)
6. Click "Save"
7. Pipeline automatically picks up new variables on next run

### Secret Rotation Practices

**For Pipeline Secrets (ACR credentials, SQL password):**
1. Update Variable Group value
2. Re-run pipeline (deployment will use new value)

**For Key Vault Secrets (Entra ID credentials):**
1. Update in Key Vault using CLI or Portal
2. No pipeline changes needed
3. Containers automatically refresh on next restart

## Testing Idempotency

The infrastructure is now **idempotent** - you can safely run deployments multiple times.

### Manual Idempotency Testing

Test locally before committing:

```bash
# 1. First deployment - creates everything
echo "=== FIRST DEPLOYMENT ==="
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    registryUsername="$ACR_USERNAME" \
    registryPassword="$ACR_PASSWORD" \
    sqlAdminPassword="$SQL_PASSWORD"

# Note the deployment time and resource count

# 2. Second deployment - should succeed with no errors
echo "=== SECOND DEPLOYMENT (should be fast - no changes) ==="
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    registryUsername="$ACR_USERNAME" \
    registryPassword="$ACR_PASSWORD" \
    sqlAdminPassword="$SQL_PASSWORD"

# Should complete much faster (only validating, not creating)

# 3. Check deployment details
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.{provisioningState:provisioningState, timestamp:timestamp}"
```

### Expected Behavior

**First Run:**
```
✅ Deployment succeeded
📊 Created resources: ~15
⏱️  Duration: 3-5 minutes
```

**Second Run (same parameters):**
```
✅ Deployment succeeded
📊 Modified resources: 0
⏱️  Duration: 30-60 seconds (validation only)
```

**After Parameter Change:**
```
✅ Deployment succeeded
📊 Modified resources: 1-3 (only changed ones)
⏱️  Duration: 1-2 minutes (updates only)
```

### What-If Testing

Before applying changes, use what-if to preview impact:

```bash
# See what WILL change
az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    registryUsername="$NEW_USERNAME" \
    registryPassword="$NEW_PASSWORD" \
    sqlAdminPassword="$NEW_PASSWORD"
```

This safely shows:
- ✅ Resources being created
- ⚠️  Resources being modified
- 🚨 Resources being deleted (alert!)
- ➡️  Resources unchanged

## Monitoring & Troubleshooting

### View Pipeline Runs

1. **Azure DevOps → Pipelines**
2. Select your pipeline
3. Click on a run to view details
4. Click "Logs" for detailed output
5. Search for specific stage or task

### Deployment Status Verification

```bash
# Check overall deployment status
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.provisioningState"

# List all resources in deployment
az deployment group list-resources \
  --resource-group entra-demo-dev-rg \
  --query "[].{Name:name, Type:type, State:properties.provisioningState}"

# Check individual container app status
az containerapp show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.{provisioningState:provisioningState, latestRevisionName:latestRevisionName}"
```

### Common Issues & Fixes

#### Issue 1: Validation Fails

**Error:** `Template validation failed`

**Common Causes:**
- Resource group doesn't exist
- Missing required variables in Variable Group
- Parameter type mismatch
- Bicep syntax error

**Fix:**
```bash
# Validate locally first
az deployment group validate \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    registryUsername="test-user" \
    registryPassword="test-password" \
    sqlAdminPassword="Test@123456"

# Output will show exact error location and message

# Ensure resource group exists
az group create --name entra-demo-dev-rg --location centralindia

# Verify all required variables are in Variable Group
az pipelines variable list --pipeline-name "your-pipeline-name"
```

#### Issue 2: Docker Build Fails

**Error:** `Docker build failed` or `ACR push failed`

**Common Causes:**
- ACR login credentials incorrect
- ACR doesn't exist or wrong name
- Dockerfile path incorrect
- Docker build context has syntax errors

**Fix:**
```bash
# Verify ACR login works
az acr login --name entrademodevacr

# Check ACR exists and is accessible
az acr list --output table

# Check ACR credentials in Variable Group
# Go to: Azure DevOps → Pipelines → Library → Variable Groups
# Verify: registryUsername and registryPassword are set correctly

# Test building image locally
docker build --file frontend/Dockerfile --tag test-frontend:latest .
docker tag test-frontend:latest entrademodevacr.azurecr.io/entra-demo/frontend:test

# Push test image
az acr login --name entrademodevacr
docker push entrademodevacr.azurecr.io/entra-demo/frontend:test
```

#### Issue 3: Deployment Creates Duplicate Resources

**Error:** `Deployment failed: Resource already exists` or duplicate resource names

**Root Cause:** Not using idempotent deployment approach

**Fix:**
```bash
# Always use the same deployment name
# ❌ Wrong (creates new deployment each time):
az deployment group create --name "deploy-$(date +%s)" ...

# ✅ Correct (idempotent - updates existing):
az deployment group create --name main ...

# Delete old deployments to clean up
az deployment group delete \
  --resource-group entra-demo-dev-rg \
  --name "old-deployment-name"

# List all deployments
az deployment group list \
  --resource-group entra-demo-dev-rg \
  --query "[].name"
```

#### Issue 4: Container Won't Start

**Error:** `Container is not running` or `Health check failed`

**Common Causes:**
- Docker image not found or wrong tag
- Key Vault access denied
- Port configuration incorrect
- Missing environment variables

**Fix:**
```bash
# Check container status and logs
az containerapp logs show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --tail 50

# Check if image exists in ACR
az acr repository show-tags \
  --name entrademodevacr \
  --repository entra-demo/api

# Verify container app configuration
az containerapp show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.template.containers[0].image"

# Check Key Vault access (if using managed identity)
az containerapp show \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  --query "identity"

# Verify Key Vault has secrets
az keyvault secret list \
  --vault-name entra-demo-kv-dev \
  --query "[].name"
```

#### Issue 5: Key Vault Secrets Not Set

**Error:** `Secret not found` or `Access denied to Key Vault`

**Common Causes:**
- Secret wasn't created during deployment
- Managed identity doesn't have permission
- Wrong secret name
- Secret was accidentally deleted

**Fix:**
```bash
# List all secrets in Key Vault
az keyvault secret list \
  --vault-name entra-demo-kv-dev \
  --query "[].name"

# Set missing secret
az keyvault secret set \
  --vault-name entra-demo-kv-dev \
  --name BffClientSecret \
  --value "your-secret-value"

# Check managed identity permissions
az keyvault show \
  --name entra-demo-kv-dev \
  --query "properties.accessPolicies"

# Add access policy if needed
az keyvault set-policy \
  --name entra-demo-kv-dev \
  --object-id <managed-identity-principal-id> \
  --secret-permissions get list

# Verify container can access secret
az containerapp exec \
  --name api-dev \
  --resource-group entra-demo-dev-rg \
  -- /bin/sh -c "curl https://vault-name.vault.azure.net/secrets/secret-name?api-version=2021-06-01-preview"
```

#### Issue 6: Deployment Timeout (Slow)

**Error:** `Deployment timed out` or deployment taking very long

**Common Causes:**
- Creating too many resources
- Container image is very large
- Network connectivity issues
- Resource tier is too low

**Fix:**
```bash
# Check what's taking time
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.correlationId"

# View deployment operations
az deployment group operation list \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "[].{ProvisioningState:properties.provisioningState, TargetResource:properties.targetResource.id, Duration:properties.duration}"

# Increase timeout for Azure CLI
# Add --no-wait flag to return immediately
az deployment group create ... --no-wait

# Check status later
az deployment group show --resource-group entra-demo-dev-rg --name main
```

#### Issue 7: Idempotency Not Working (Redeployment Fails)

**Error:** `Deployment failed with same parameters` or unexpected modifications

**Common Causes:**
- Using conditional modules incorrectly
- Parameter values changed
- Resource naming changed
- Template logic error

**Fix:**
```bash
# Always check what-if before actual deployment
az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam

# Use exact same parameters each time
# Store parameters in file or variable
export DEPLOY_PARAMS="
  location=centralindia \
  environment=dev \
  projectName=entra-demo \
  registryUsername=$ACR_USERNAME \
  registryPassword=$ACR_PASSWORD \
  sqlAdminUsername=sqladmin \
  sqlAdminPassword=$SQL_PASSWORD
"

# Use saved parameters
az deployment group create \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters $DEPLOY_PARAMS

# Verify deployment details
az deployment group show \
  --resource-group entra-demo-dev-rg \
  --name main \
  --query "properties.{timestamp:timestamp, provisioningState:provisioningState}"
```

## Pipeline Troubleshooting in Azure DevOps

### View Detailed Logs

1. Go to **Pipelines → Your Pipeline → Select Run**
2. Click "Logs" tab
3. Expand stages to see detailed output
4. Search for "error" or "failed"

### Re-run Pipeline

If a stage fails:
1. Click "Run pipeline" and select same commit
2. Or click "Rerun failed jobs" button
3. Can rerun specific stages

### Debug Mode

Add debug output to troubleshoot:
```yaml
# In azure-pipelines.yml
variables:
  system.debug: true  # Enable debug logging
```

## Manual Pipeline Edit

To modify the pipeline:

1. **Azure DevOps → Pipelines → Your Pipeline**
2. Click "Edit"
3. Pipeline YAML editor opens
4. Make changes to `azure-pipelines.yml`
5. Click "Save" → "Save"

Or edit file directly in repo:
```bash
# Edit azure-pipelines.yml in your editor
git add azure-pipelines.yml
git commit -m "Update pipeline configuration"
git push origin develop
```

## Security Best Practices

✅ **DO:**
- Store all secrets in Variable Groups or Key Vault
- Mark sensitive variables with lock icon
- Use managed identities for Azure resource access
- Review What-If before every deployment
- Enable branch policies requiring PR reviews
- Rotate secrets regularly

❌ **DON'T:**
- Commit passwords to git
- Pass secrets as plain text in scripts
- Use service principals unnecessarily
- Skip What-If preview
- Allow direct pushes to main branch

## Next Steps

1. [Set up Entra ID for authentication](../docs/entra-id-prod-setup.md)
2. [Validate infrastructure with Bicep scripts](../.azure/infra-validation-deployment.md)
3. [Deploy to production](../docs/DEPLOYMENT.md)
4. [Monitor with Application Insights](../docs/DEPLOYMENT.md#observability)



## Step 1: Create Service Connections

### Azure Service Connections

In Azure DevOps → Project Settings → Service connections:

#### Development
1. New service connection → Azure Resource Manager
2. Name: `AzureServiceConnection`
3. Scope: Subscription level or Resource Group level
4. Save

#### Production
1. New service connection → Azure Resource Manager
2. Name: `AzureServiceConnectionProd`
3. Scope: Production subscription/resource group
4. Save

### Container Registry Service Connection

1. New service connection → Docker Registry
2. Name: `AcrConnection`
3. Docker registry: Azure Container Registry
4. Azure Subscription: (select your subscription)
5. Azure Container Registry: (select your ACR)
6. Save

## Step 2: Create Variable Groups

In Azure DevOps → Pipelines → Library → Variable groups:

### Development Variables
Create variable group: `entra-demo-dev-vars`

```
registryUsername          = <your-acr-username>
registryPassword          = <your-acr-password> (Mark as secret)
sqlAdminUsernameDev       = sqladmin
sqlAdminPasswordDev       = <strong-password> (Mark as secret)
BffTenantId               = <your-entra-tenant-id>
BffClientId               = <your-bff-client-id>
BffClientSecret           = <your-bff-client-secret> (Mark as secret)
ApiAudience               = api://<your-api-client-id>
```

### Production Variables
Create variable group: `entra-demo-prod-vars`

```
registryUsername          = <your-acr-username>
registryPassword          = <your-acr-password> (Mark as secret)
sqlAdminUsernameProd      = prodadmin
sqlAdminPasswordProd      = <strong-password> (Mark as secret)
BffTenantId               = <your-entra-tenant-id>
BffClientId               = <your-bff-prod-client-id>
BffClientSecret           = <your-bff-prod-client-secret> (Mark as secret)
ApiAudience               = api://<your-api-prod-client-id>
```

## Step 3: Create the Pipeline

1. In Azure DevOps → Pipelines → New pipeline
2. Select your repository
3. Choose "Existing Azure Pipelines YAML file"
4. Path: `azure-pipelines.yml`
5. Save and run

## Step 4: Configure Pipeline Settings

### Branch Policies (Optional but Recommended)

**For `main` branch:**
1. Require PR reviews
2. Require successful build
3. Require passing status checks

**For `develop` branch:**
1. Allow direct commits OR require PR reviews

### Environment Approvals

**For Production:**
1. Go to Pipelines → Environments → Create "production"
2. Add approval checks
3. Require approval before production deployment

## Step 5: Repository Structure

Ensure your repository has:

```
.
├── azure-pipelines.yml           # Main CI/CD pipeline
├── azure-pipelines.variables.yml # Environment variables
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
├── bff/
│   ├── Dockerfile
│   ├── bff.csproj
│   └── Program.cs
├── api/
│   ├── Dockerfile
│   ├── api.csproj
│   └── Program.cs
├── infra/
│   ├── main.bicep
│   ├── main.bicepparam
│   └── modules/
├── .azure/
│   └── deployment-plan.md
└── docs/
    └── entra-id-prod-setup.md
```

## Step 6: Secrets Management

### Store Sensitive Data in Azure DevOps

1. Go to Pipelines → Library → Secure files
2. Upload any certificates or config files needed
3. Reference in pipeline using:
   ```yaml
   - task: DownloadSecureFile@1
     inputs:
       secureFile: 'filename'
   ```

### Rotate Secrets

Regularly rotate:
- ACR credentials
- SQL admin passwords
- Entra ID client secrets
- Key Vault secrets

Update in:
1. Azure Key Vault
2. Azure DevOps Variable Groups
3. Container Apps environment

## Pipeline Triggers

### Auto-Trigger On:

**Develop branch:**
- Merges to `develop`
- Deploys to development environment automatically

**Main branch:**
- Merges to `main`
- Requires manual approval before prod deployment
- Deploys to production

### Manual Trigger:

Run pipeline manually in Azure DevOps:
1. Go to Pipelines
2. Select pipeline
3. Click "Run pipeline"
4. Select branch and run

## Monitoring & Logs

### View Pipeline Runs

1. Pipelines → Your pipeline
2. Select run to view details
3. Click "Logs" to see detailed output

### Common Issues

**ACR Push fails:**
- Verify ACR credentials
- Check ACR firewall rules
- Ensure image naming is correct

**Deployment fails:**
- Check Resource Group exists
- Verify RBAC permissions
- Review Bicep parameter values
- Check Key Vault access

**Container App won't start:**
- Check Application Insights logs
- Review Container App diagnostics
- Verify image can be pulled from ACR

## Rollback Procedure

### To rollback to previous deployment:

1. In Azure DevOps, go to previous successful run
2. Click "Re-run" or "Deploy" (if using Release pipeline)
3. Confirm rollback

OR

Use Azure CLI:
```bash
# Get previous revision
az containerapp revision list --name bff-dev --resource-group <rg>

# Activate previous revision
az containerapp revision activate --name bff-dev --resource-group <rg> \
  --revision bff-dev--xxxxx
```

## Performance Tips

1. **Cache Dependencies:**
   - Pipeline caches npm packages, NuGet packages
   - First build slower, subsequent builds faster

2. **Parallel Jobs:**
   - Frontend, BFF, API build in parallel
   - Docker builds run sequentially

3. **Build Matrix:**
   - Consider matrix strategy for multi-platform builds

## Security Best Practices

✅ DO:
- Use managed identities (not service principals when possible)
- Store secrets in Azure Key Vault
- Use Variable Groups with secret protection
- Enable branch protection on main
- Require approvals for production
- Use private ACR endpoints
- Scan container images for vulnerabilities

❌ DON'T:
- Hardcode secrets in pipeline
- Store passwords in git
- Use overly permissive RBAC roles
- Deploy unsigned images
- Skip security scans

## References

- [Azure DevOps Pipelines Documentation](https://learn.microsoft.com/azure/devops/pipelines/)
- [Service Connections](https://learn.microsoft.com/azure/devops/pipelines/library/service-endpoints)
- [Variable Groups](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups)
- [Container Apps Deployment](https://learn.microsoft.com/azure/container-apps/)
