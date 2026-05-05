# CI/CD Pipeline Setup Guide

## Prerequisites

Before running the Azure DevOps pipeline, ensure you have:

1. **Azure DevOps Project** created
2. **Service Connections** configured:
   - `AzureServiceConnection` - For dev environment
   - `AzureServiceConnectionProd` - For prod environment
   - `AcrConnection` - For Azure Container Registry
3. **Variable Groups** in Azure DevOps
4. **GitHub/Azure Repos** repository connected

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
