# Deployment Plan - Azure Entra ID React + BFF + API

## Pre-Deployment Checklist

### 1. Azure Resources Setup
- [ ] Create or select Azure Resource Group
- [ ] Verify Azure CLI is installed: `az --version`
- [ ] Authenticate: `az login`
- [ ] Set subscription: `az account set --subscription "subscription-id"`

### 2. Container Registry Setup
```bash
# Login to Azure Container Registry
az acr login --name <registry-name>

# Build and push images
az acr build --registry <registry-name> --image frontend:latest --file frontend/Dockerfile .
az acr build --registry <registry-name> --image bff:latest --file bff/Dockerfile .
az acr build --registry <registry-name> --image api:latest --file api/Dockerfile .
```

### 3. Infrastructure Deployment

#### Using Bicep Parameters File
```bash
cd infra

# Validate the deployment
az deployment group validate \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters main.bicepparam

# Deploy infrastructure
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters location=eastus \
  environment=dev \
  projectName=entra-demo \
  registryUsername=$REGISTRY_USERNAME \
  registryPassword=$REGISTRY_PASSWORD \
  sqlAdminUsername=sqladmin \
  sqlAdminPassword=$SQL_ADMIN_PASSWORD
```

### 4. Post-Deployment Configuration

#### Update Key Vault Secrets
```bash
# After deployment, retrieve outputs
KEYVAULT_NAME=$(az deployment group show \
  --resource-group <resource-group-name> \
  --name main \
  --query "properties.outputs.infrastructureInfo.value.keyVaultName" \
  --output tsv)

# Update Entra ID secrets (replace with actual values from your Entra app registrations)
az keyvault secret set --vault-name $KEYVAULT_NAME --name BffTenantId --value "<your-tenant-id>"
az keyvault secret set --vault-name $KEYVAULT_NAME --name BffClientId --value "<your-bff-client-id>"
az keyvault secret set --vault-name $KEYVAULT_NAME --name BffClientSecret --value "<your-bff-client-secret>"
az keyvault secret set --vault-name $KEYVAULT_NAME --name ApiAudience --value "<your-api-audience>"

# Update SQL connection string
az keyvault secret set --vault-name $KEYVAULT_NAME --name SqlConnectionString --value "<connection-string>"
```

#### Update Container Apps Environment Variables
After deployment, update the Container Apps with actual Key Vault URI and other secrets.

### 5. Entra ID Configuration

Create two app registrations in your Azure Entra ID tenant:

#### BFF App Registration
1. Register application name: `entra-demo-bff`
2. Supported account types: Choose appropriate for your org
3. Redirect URI: `https://<bff-fqdn>/signin-oidc`
4. Client secret: Create and store in Key Vault
5. API Permissions: Request API scope from API app registration

#### API App Registration
1. Register application name: `entra-demo-api`
2. Supported account types: Same as BFF
3. Expose an API:
   - Application ID URI: `api://<api-app-id>`
   - Add scope: `access_as_user`
4. Copy scope value to Key Vault

### 6. Verify Deployment

```bash
# Get application URLs
FRONTEND_URL=$(az deployment group show \
  --resource-group <resource-group-name> \
  --name main \
  --query "properties.outputs.applicationUrls.value.frontendUrl" \
  --output tsv)

BFF_URL=$(az deployment group show \
  --resource-group <resource-group-name> \
  --name main \
  --query "properties.outputs.applicationUrls.value.bffUrl" \
  --output tsv)

echo "Frontend: $FRONTEND_URL"
echo "BFF: $BFF_URL"

# Test health endpoints
curl $BFF_URL/health
curl $BFF_URL/api/employees  # Should require auth
```

## Environment-Specific Parameters

### Development
```bicepparam
location = 'eastus'
environment = 'dev'
projectName = 'entra-demo'
```

### Test/Staging
```bicepparam
location = 'eastus'
environment = 'test'
projectName = 'entra-demo'
```

### Production
```bicepparam
location = 'eastus'
environment = 'prod'
projectName = 'entra-demo'
```

## Rollback Procedure

To rollback to previous version:
```bash
# Get previous deployment name
az deployment group list --resource-group <resource-group-name> --query "[].name" --output table

# Redeploy from earlier version
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Monitoring & Diagnostics

### View Application Insights
```bash
# Get App Insights name
APP_INSIGHTS=$(az deployment group show \
  --resource-group <resource-group-name> \
  --name main \
  --query "properties.outputs.infrastructureInfo.value.appInsightsName" \
  --output tsv)

# View in Azure Portal
echo "https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/<resource-group-name>/providers/microsoft.insights/components/$APP_INSIGHTS"
```

### Query Logs
```bash
# Use Log Analytics to query application logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AppEvents | where Name contains 'login' | take 10"
```

## Troubleshooting

### Container Apps Not Starting
```bash
# Check container logs
az containerapp logs show --name bff-dev --resource-group <resource-group-name>
az containerapp logs show --name api-dev --resource-group <resource-group-name>
```

### Key Vault Access Issues
```bash
# Verify managed identity has access
az keyvault show --name $KEYVAULT_NAME --query properties.accessPolicies
```

### CORS Issues
Check Container Apps configuration for allowed origins matching Frontend URL.
