param location string
param keyVaultName string
param environment string
param tenantId string
param managedIdentityPrincipalId string

var skuName = 'standard'
var enabledForDeployment = true
var enabledForTemplateDeployment = true
var enabledForDiskEncryption = false
var enableSoftDelete = true
var softDeleteRetentionDays = 7

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      name: skuName
      family: 'A'
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: managedIdentityPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
    ]
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

resource sqlConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: 'placeholder-update-after-sql-creation'
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
