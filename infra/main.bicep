targetScope = 'resourceGroup'

param location string = resourceGroup().location
param environment string
param projectName string
param registryUsername string
@secure()
param registryPassword string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string

var tags = {
  environment: environment
  project: projectName
  createdDate: utcNow('u')
}

var uniqueSuffix = uniqueString(resourceGroup().id)
var keyVaultName = '${projectName}-kv-${uniqueSuffix}'
var logAnalyticsWorkspaceName = '${projectName}-law-${environment}'
var appInsightsName = '${projectName}-ai-${environment}'
var sqlServerName = '${projectName}-sql-${uniqueSuffix}'
var sqlDatabaseName = '${projectName}db'
var containerRegistryName = '${projectName}acr${replace(uniqueSuffix, '-', '')}'
var containerAppsEnvironmentName = '${projectName}-cae-${environment}'

// Get current user principal ID for Key Vault access
var currentUserPrincipalId = 'placeholder' // This will be replaced during deployment if needed

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

// Deploy Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
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
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
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
    managedIdentityPrincipalId: 'placeholder' // Will be updated after container apps are created
  }
}

// Deploy Container Apps (Frontend, BFF, API)
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    location: location
    environment: environment
    containerAppsEnvironmentId: containerAppsEnv.outputs.containerAppsEnvironmentId
    registryUrl: containerRegistry.outputs.registryUrl
    registryUsername: registryUsername
    registryPassword: registryPassword
    keyVaultUri: keyVault.outputs.keyVaultUri
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    apiBaseUrl: containerApps.outputs.apiUrl
    bffRedirectUri: containerApps.outputs.bffUrl
  }
  dependsOn: [
    containerAppsEnv
    containerRegistry
    keyVault
    monitoring
  ]
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
  sqlDatabaseName: sql.outputs.sqlDatabaseName
  containerRegistryName: containerRegistry.outputs.registryName
  containerRegistryUrl: containerRegistry.outputs.registryUrl
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

output sqlConnectionString string = sql.outputs.connectionString
