param location string
param keyVaultName string
param environment string
param tenantId string
@secure()
param appInsightsConnectionString string
@secure()
param sqlAdminPassword string
param sqlServerFqdn string
param sqlDatabaseName string
// Optional secrets - only create if provided (not empty)
param bffClientId string = ''
@secure()
param bffClientSecret string = ''
param bffTenantId string = ''
param apiAudience string = ''

var skuName = 'standard'
var enabledForDeployment = true
var enabledForTemplateDeployment = true
var enabledForDiskEncryption = false
var enableSoftDelete = true
var softDeleteRetentionDays = 7

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      name: skuName
      family: 'A'
    }
    accessPolicies: []
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionDays
  }

  tags: {
    environment: environment
  }
}

// Only create BffClientSecret if a value is provided
resource bffClientSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(bffClientSecret)) {
  parent: keyVault
  name: 'BffClientSecret'
  properties: {
    value: bffClientSecret
  }
}

// Only create BffTenantId if a value is provided
resource bffTenantIdResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(bffTenantId)) {
  parent: keyVault
  name: 'BffTenantId'
  properties: {
    value: bffTenantId
  }
}

// Only create BffClientId if a value is provided
resource bffClientIdResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(bffClientId)) {
  parent: keyVault
  name: 'BffClientId'
  properties: {
    value: bffClientId
  }
}

// Only create ApiAudience if a value is provided
resource apiAudienceResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(apiAudience)) {
  parent: keyVault
  name: 'ApiAudience'
  properties: {
    value: apiAudience
  }
}

// SQL Admin Password - used by applications to construct connection strings
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlAdminPassword'
  properties: {
    value: sqlAdminPassword
  }
}

// SQL Connection String - constructed with server details and password reference
// Note: Applications should fetch SqlAdminPassword from Key Vault and construct the connection string
resource sqlConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=sqladmin;Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApplicationInsights--ConnectionString'
  properties: {
    value: appInsightsConnectionString
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
