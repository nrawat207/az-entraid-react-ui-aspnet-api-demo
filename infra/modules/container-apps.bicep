param location string
param environment string
param containerAppsEnvironmentId string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string
param imageRepository string = 'entra-demo'
param keyVaultUri string

var frontendAppName = 'frontend-${environment}'
var bffAppName = 'bff-${environment}'
var apiAppName = 'api-${environment}'
var internalApiBaseUrl = 'http://${apiAppName}'

// Frontend Container App
resource frontendContainerApp 'Microsoft.App/containerApps@2026-01-01' = {
  name: frontendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: registryUrl
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: registryPassword
        }
      ]
      ingress: {
        external: true
        targetPort: 3000
        transport: 'Auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: '${registryUrl}/${imageRepository}/frontend:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'VITE_API_BASE_URL'
              value: ''
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }

  tags: {
    environment: environment
  }
}

// BFF Container App
resource bffContainerApp 'Microsoft.App/containerApps@2026-01-01' = {
  name: bffAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: registryUrl
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: registryPassword
        }
        {
          name: 'keyvault-uri'
          value: keyVaultUri
        }
      ]
      ingress: {
        external: true
        targetPort: 5001
        transport: 'Auto'
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: [
            'https://${frontendContainerApp.properties.configuration.ingress.fqdn}'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposeHeaders: [
            '*'
          ]
          maxAge: 600
          allowCredentials: true
        }
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'bff'
          image: '${registryUrl}/${imageRepository}/bff:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: environment == 'prod' ? 'Production' : 'Development'
            }
            {
              name: 'KeyVault__Uri'
              secretRef: 'keyvault-uri'
            }
            {
              name: 'AzureAd__RedirectUri'
              value: ''
            }
            {
              name: 'Api__BaseUrl'
              value: internalApiBaseUrl
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }

  tags: {
    environment: environment
  }
}

// API Container App
resource apiContainerApp 'Microsoft.App/containerApps@2026-01-01' = {
  name: apiAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: registryUrl
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: registryPassword
        }
        {
          name: 'keyvault-uri'
          value: keyVaultUri
        }
      ]
      ingress: {
        external: false
        targetPort: 5002
        transport: 'Auto'
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: [
            'https://${bffContainerApp.properties.configuration.ingress.fqdn}'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposeHeaders: [
            '*'
          ]
          maxAge: 600
          allowCredentials: true
        }
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${registryUrl}/${imageRepository}/api:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: environment == 'prod' ? 'Production' : 'Development'
            }
            {
              name: 'KeyVault__Uri'
              secretRef: 'keyvault-uri'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }

  tags: {
    environment: environment
  }
}

output frontendUrl string = 'https://${frontendContainerApp.properties.configuration.ingress.fqdn}'
output bffUrl string = 'https://${bffContainerApp.properties.configuration.ingress.fqdn}'
output apiUrl string = 'https://${apiContainerApp.properties.configuration.ingress.fqdn}'
output frontendPrincipalId string = frontendContainerApp.identity.principalId
output bffPrincipalId string = bffContainerApp.identity.principalId
output apiPrincipalId string = apiContainerApp.identity.principalId
