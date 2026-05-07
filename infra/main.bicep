targetScope = 'resourceGroup'

param location string
param environment string
param projectName string
param registryUsername string
@secure()
param registryPassword string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string
param imageRepository string = 'entra-demo'
param existingRegistryName string = '' // Use existing ACR instead of creating new one
param existingRegistryUrl string = '' // URL of existing ACR (e.g., entrademodevacr.azurecr.io)
param useExistingRegistry bool = false // Set to true to skip ACR creation

var uniqueSuffix = uniqueString(projectName, environment, location)
var keyVaultName = '${projectName}-kv-${uniqueSuffix}'
var logAnalyticsWorkspaceName = '${projectName}-law-${environment}'
var appInsightsName = '${projectName}-ai-${environment}'
var sqlServerName = '${projectName}-sql-${uniqueSuffix}'
var sqlDatabaseName = '${projectName}db'
var containerRegistryName = '${projectName}acr${replace(uniqueSuffix, '-', '')}'
var containerAppsEnvironmentName = '${projectName}-cae-${environment}'
var registryUrlToUse = useExistingRegistry ? existingRegistryUrl : containerRegistry.outputs.registryUrl

// Deploy monitoring first (Log Analytics + App Insights)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    environment: environment
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    appInsightsName: appInsightsName
  }
}

// Deploy SQL Database
module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    environment: environment
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
  }
}

// Deploy Container Registry (only if not using existing)
module containerRegistry 'modules/container-registry.bicep' = if (!useExistingRegistry) {
  name: 'container-registry'
  params: {
    location: location
    environment: environment
    registryName: containerRegistryName
  }
}

// Deploy Container Apps Environment
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'container-apps-env'
  params: {
    location: location
    environment: environment
    containerAppsEnvironmentName: containerAppsEnvironmentName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Key Vault
// Note: The container app managed identities will be configured after they're created
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    keyVaultName: keyVaultName
    environment: environment
    tenantId: subscription().tenantId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    sqlAdminPassword: sqlAdminPassword
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.sqlDatabaseName
  }
}

// Deploy Container Apps (Frontend, BFF, API)
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    location: location
    environment: environment
    containerAppsEnvironmentId: containerAppsEnv.outputs.containerAppsEnvironmentId
    registryUrl: registryUrlToUse
    registryUsername: registryUsername
    registryPassword: registryPassword
    imageRepository: imageRepository
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

module keyVaultAccessPolicies 'modules/keyvault-access-policies.bicep' = {
  name: 'keyvault-access-policies'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    tenantId: subscription().tenantId
    principalIds: [
      containerApps.outputs.bffPrincipalId
      containerApps.outputs.apiPrincipalId
    ]
  }
}

// Outputs
output deploymentInfo object = {
  environment: environment
  projectName: projectName
  location: location
  resourceGroup: resourceGroup().name
  subscription: subscription().id
}

output infrastructureInfo object = {
  keyVaultName: keyVault.outputs.keyVaultName
  keyVaultUri: keyVault.outputs.keyVaultUri
  appInsightsName: monitoring.outputs.appInsightsName
  logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  sqlServerName: sql.outputs.sqlServerName
  sqlServerFqdn: sql.outputs.sqlServerFqdn
  sqlDatabaseName: sql.outputs.sqlDatabaseName
  containerRegistryName: useExistingRegistry ? existingRegistryName : containerRegistry.outputs.registryName
  containerRegistryUrl: registryUrlToUse
}

output applicationUrls object = {
  frontendUrl: containerApps.outputs.frontendUrl
  bffUrl: containerApps.outputs.bffUrl
  apiUrl: containerApps.outputs.apiUrl
}

output managedIdentities object = {
  frontendPrincipalId: containerApps.outputs.frontendPrincipalId
  bffPrincipalId: containerApps.outputs.bffPrincipalId
  apiPrincipalId: containerApps.outputs.apiPrincipalId
}

// Note: SQL Connection String is now stored securely in Key Vault (SqlConnectionString secret)
// Applications should fetch it from Key Vault using managed identities
