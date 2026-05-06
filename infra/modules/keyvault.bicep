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

// Secrets for BFF (will be populated during deployment)
resource bffClientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'BffClientSecret'
  properties: {
    value: 'placeholder-update-in-azure-portal'
  }
}

resource bffTenantId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'BffTenantId'
  properties: {
    value: 'placeholder-update-in-azure-portal'
  }
}

resource bffClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'BffClientId'
  properties: {
    value: 'placeholder-update-in-azure-portal'
  }
}

resource apiAudience 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApiAudience'
  properties: {
    value: 'placeholder-update-in-azure-portal'
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
