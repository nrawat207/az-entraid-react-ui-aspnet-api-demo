param keyVaultName string
param tenantId string
param principalIds array

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: keyVaultName
}

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2025-05-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      for principalId in principalIds: {
        tenantId: tenantId
        objectId: principalId
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
  }
}
