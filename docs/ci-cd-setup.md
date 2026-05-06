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
  --parameters infra/main.bicepparam
```

**Checks:**
✅ Bicep syntax is correct  
✅ All parameters are valid  
✅ Resource types exist  
✅ No duplicate resource names  

**Fails If:**
❌ Syntax errors found  
❌ Required parameters missing  
❌ Resource group doesn't exist  
❌ Insufficient permissions

### Stage 1: What-If (Preview)

Shows all changes that WILL be made during deployment.

```bash
az deployment group what-if \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep
```

**Output:**
- Which resources will be Created
- Which will be Modified
- Which will be Deleted

**Use This To:**
- Review infrastructure changes before they happen
- Catch accidental deletions
- Understand deployment impact

### Stage 2: Build & Test

Builds all applications and runs tests.

- **Frontend:** npm build, ESLint
- **BFF:** dotnet build, unit tests
- **API:** dotnet build, unit tests

**Artifacts Generated:**
- `frontend/dist/` - Built React app
- `bff/` - Compiled .NET binaries
- `api/` - Compiled .NET binaries

### Stage 3: Build & Push Docker

Creates Docker images and pushes to Azure Container Registry.

**Images Created:**
- `entrademodevacr.azurecr.io/entra-demo/frontend:<build-id>`
- `entrademodevacr.azurecr.io/entra-demo/bff:<build-id>`
- `entrademodevacr.azurecr.io/entra-demo/api:<build-id>`

**Also Tagged:**
- `latest` - Most recent build
- `<branch>-<build-id>` - Branch tracking

### Stage 4: Deploy

Deploys infrastructure and applications (only on `develop` branch).

**Steps:**
1. Deploy Bicep infrastructure
   - Key Vault with secrets
   - SQL Database
   - Container Registry
   - Container Apps Environment
   - Container Apps (Frontend, BFF, API)

2. Update container app images with new builds

3. Verify health checks pass
   - BFF responds to `/health`
   - API provisioning state is "Succeeded"

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

1. **In Variable Groups** (Pipeline Secrets)
   - Marked with lock icon 🔒
   - Masked in logs
   - Passed as environment variables
   - Never visible in pipeline output

2. **In Key Vault** (Runtime Secrets)
   - SQL admin password
   - Entra ID credentials
   - App Insights connection string
   - Accessed by containers via managed identity

3. **Never in Parameter Files**
   - `main.bicepparam` contains placeholders only
   - Real values passed at deployment time

### Adding New Secrets to Pipeline

1. Go to **Pipelines → Library → Variable Groups**
2. Click `entra-demo-dev-vars`
3. Click "+ Add"
4. Enter secret name and value
5. Click lock icon to mark as secret ⭐
6. Click "Save"

Pipeline automatically picks up new variables.

## Monitoring & Troubleshooting

### View Pipeline Runs

1. **Azure DevOps → Pipelines**
2. Select your pipeline
3. Click on a run to view details
4. Click "Logs" for detailed output

### Common Issues

#### Validation Fails

**Error:** `Template validation failed`

**Fix:**
```bash
# Check error details in pipeline logs
# Likely causes:
# - Resource group doesn't exist: az group create ...
# - Missing secret variables: Check Variable Groups
# - Parameter type mismatch: Check main.bicep parameters

az deployment group validate \
  --resource-group entra-demo-dev-rg \
  --template-file infra/main.bicep \
  --parameters main.bicepparam \
  --parameters \
    registryUsername="test" \
    registryPassword="test" \
    sqlAdminPassword="test"
```

#### Docker Build Fails

**Error:** `Docker build failed` or `ACR push failed`

**Fix:**
```bash
# Verify ACR credentials in Variable Group
az acr login --name entrademodevacr

# Check ACR exists
az acr list --output table

# Check Docker images built locally
docker images | grep entra-demo
```

#### Deployment Fails

**Error:** `Container App won't start` or `Health check failed`

**Fix:**
```bash
# Check container app logs
az containerapp logs show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg

# Check provisioning state
az containerapp show \
  --name bff-dev \
  --resource-group entra-demo-dev-rg \
  --query "properties.provisioningState"

# Verify Key Vault access
az keyvault secret list \
  --vault-name <vault-name>
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
git commit -m "Update pipeline"
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
