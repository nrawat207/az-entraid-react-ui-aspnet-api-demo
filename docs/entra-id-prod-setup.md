# Microsoft Entra ID Production Setup Guide

This document provides step-by-step instructions for setting up Microsoft Entra ID (Azure AD) app registrations for production deployment.

## Overview

You need to create TWO app registrations:
1. **BFF Application** - Handles user authentication with Entra ID
2. **API Application** - Protected resource with scopes

## Prerequisites

- Azure Entra ID tenant access
- Global Administrator or Application Administrator role
- Deployed Container Apps (to get the FQDN URLs)

## Step 1: Get Deployment URLs

After deploying to Azure Container Apps, retrieve your application URLs:

```bash
# BFF URL
BFF_FQDN=$(az containerapp show --name bff-dev --resource-group <rg> --query "properties.configuration.ingress.fqdn" -o tsv)
echo "https://$BFF_FQDN"

# Frontend URL  
FRONTEND_FQDN=$(az containerapp show --name frontend-dev --resource-group <rg> --query "properties.configuration.ingress.fqdn" -o tsv)
echo "https://$FRONTEND_FQDN"
```

## Step 2: Create API App Registration

### In Azure Portal:

1. Go to **Azure Entra ID** → **App registrations** → **New registration**

2. **Register an application**
   - Name: `entra-demo-api`
   - Supported account types: `Accounts in this organizational directory only` (or your preference)
   - Click **Register**

3. Copy these values to save:
   - **Application (client) ID** - You'll need this
   - **Directory (tenant) ID** - You'll need this

4. Go to **Expose an API**
   - Click **Set** next to "Application ID URI"
   - Use format: `api://<Application-ID>`
   - Example: `api://12345678-1234-1234-1234-123456789012`
   - Click **Save**

5. Add a scope:
   - Click **Add a scope**
   - Scope name: `access_as_user`
   - Who can consent: `Admins and users`
   - Admin consent display name: `Access the API on behalf of users`
   - Admin consent description: `Allows the application to access the API on behalf of the user`
   - Click **Add scope**

6. Copy the full scope: `api://your-api-id/access_as_user`

7. Go to **Manifest** and ensure:
   ```json
   "optionalClaims": {
     "accessToken": [
       {
         "name": "groups",
         "essential": false
       }
     ]
   }
   ```

## Step 3: Create BFF App Registration

### In Azure Portal:

1. Go to **Azure Entra ID** → **App registrations** → **New registration**

2. **Register an application**
   - Name: `entra-demo-bff`
   - Supported account types: Same as API app
   - Redirect URI: 
     - Platform: **Web**
     - URI: `https://<BFF_FQDN>/signin-oidc`
     - Example: `https://bff-dev.azurecontainerapps.io/signin-oidc`
   - Click **Register**

3. Copy these values:
   - **Application (client) ID**
   - **Directory (tenant) ID**

4. Create a client secret:
   - Go to **Certificates & secrets** → **Client secrets** → **New client secret**
   - Description: `Production secret`
   - Expires: Choose 24 months or your policy
   - Copy the **Value** (not the ID) - This is sensitive!

5. Configure API permissions:
   - Go to **API permissions** → **Add a permission**
   - Select **APIs my organization uses**
   - Search for `entra-demo-api` (the API app you created)
   - Select **access_as_user**
   - Choose **User consent** or **Admin consent + user consent**
   - Click **Add permissions**

6. Grant admin consent (if required by your org):
   - Click **Grant admin consent for [Tenant]**
   - Confirm

## Step 4: Update Key Vault with Entra ID Credentials

```bash
KEYVAULT_NAME="entra-demo-kv-xxxxx"

# API configuration
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "ApiAudience" \
  --value "api://your-api-app-id"

# BFF configuration
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "BffTenantId" \
  --value "<your-tenant-id>"

az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "BffClientId" \
  --value "<your-bff-app-id>"

az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "BffClientSecret" \
  --value "<your-bff-client-secret>"

# API audience (full scope value)
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "ApiScope" \
  --value "api://your-api-id/access_as_user"
```

## Step 5: Update Container Apps Configuration

Update the BFF container app environment variables:

```bash
# Get BFF container app
az containerapp update \
  --name bff-dev \
  --resource-group <resource-group> \
  --set-env-vars \
    AzureAd__TenantId=$TENANT_ID \
    AzureAd__ClientId=$BFF_CLIENT_ID \
    AzureAd__ClientSecret=$BFF_CLIENT_SECRET \
    AzureAd__ApiScope=$API_SCOPE \
    AzureAd__RedirectUri=https://$BFF_FQDN

# Get API container app
az containerapp update \
  --name api-dev \
  --resource-group <resource-group> \
  --set-env-vars \
    AzureAd__TenantId=$TENANT_ID \
    AzureAd__Audience=$API_AUDIENCE
```

## Step 6: Configure API Permissions in BFF

The BFF needs to request an access token for the API.

Update `bff/Services/ApiClient.cs` to include token acquisition:

```csharp
// Request token for API scope from Entra ID
var result = await _confidentialClient.AcquireTokenOnBehalfOfAsync(
    scopes: new[] { apiScope },
    userAssertion: new UserAssertion(userToken));

var accessToken = result.AccessToken;
```

## Step 7: Test the Integration

1. **Test BFF authentication:**
   ```bash
   curl -L "https://$BFF_FQDN/auth/login"
   ```

2. **Login via browser:**
   - Navigate to `https://$FRONTEND_FQDN`
   - Click "Login"
   - Sign in with your Entra ID account

3. **Test API access:**
   - After login, navigate to Employees page
   - BFF should fetch employees from API with valid token

4. **Check Application Insights logs:**
   ```bash
   # View authentication events
   az monitor log-analytics query \
     --workspace <workspace-id> \
     --analytics-query "AppEvents | where Name contains 'auth' | limit 20"
   ```

## Optional: Configure Additional Features

### Multi-tenant Support
In BFF app registration → **Authentication**:
- Common endpoint: Change to `https://login.microsoftonline.com/common`
- Update CORS in Bicep

### Custom Branding
In Entra ID → **Company branding**:
- Add logo, banner, contact info
- These appear on Entra ID consent screens

### Conditional Access
Create policies to require MFA, device compliance, etc.

## Troubleshooting

### "Invalid client secret"
- Verify client secret is correct (not the ID)
- Check expiration date hasn't passed
- Regenerate if needed

### "Consent denied"
- Verify user has permission in your org
- Admin may need to grant consent
- Check API permissions in BFF app registration

### "Invalid scope"
- Verify scope format: `api://<app-id>/scope-name`
- Ensure scope is exposed in API app registration
- Check BFF API permissions include the scope

### Token acquisition fails
- Verify BFF can access API scope
- Check Network is allowing service-to-service communication
- Enable diagnostic logs in App Insights

## References

- [Microsoft identity platform documentation](https://learn.microsoft.com/entra/identity-platform/)
- [OAuth 2.0 and OpenID Connect protocols](https://learn.microsoft.com/entra/identity-platform/active-directory-v2-protocols)
- [Backend-for-Frontend (BFF) pattern](https://learn.microsoft.com/azure/architecture/patterns/backends-for-frontends)
