param location string
param environment string
param containerAppsEnvironmentId string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string
param keyVaultUri string
param appInsightsConnectionString string
param apiBaseUrl string
param bffRedirectUri string

// Frontend Container App
resource frontendContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'frontend-${environment}'
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
          image: '${registryUrl}/frontend:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'VITE_API_BASE_URL'
              value: apiBaseUrl
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'cpu'
            custom: {
              rule: 'cpu < 70'
            }
          }
        ]
      }
    }
  }

  tags: {
    environment: environment
  }
}

// BFF Container App
resource bffContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'bff-${environment}'
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
        {
          name: 'app-insights-connection-string'
          value: appInsightsConnectionString
        }
      ]
      ingress: {
        external: true
        targetPort: 5001
        transport: 'Auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
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
    }
    template: {
      containers: [
        {
          name: 'bff'
          image: '${registryUrl}/bff:latest'
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
              name: 'ApplicationInsights__ConnectionString'
              secretRef: 'app-insights-connection-string'
            }
            {
              name: 'AzureAd__RedirectUri'
              value: 'https://${bffContainerApp.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'Api__BaseUrl'
              value: apiBaseUrl
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'cpu'
            custom: {
              rule: 'cpu < 70'
            }
          }
        ]
      }
    }
  }

  tags: {
    environment: environment
  }
}

// API Container App
resource apiContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'api-${environment}'
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
        {
          name: 'app-insights-connection-string'
          value: appInsightsConnectionString
        }
      ]
      ingress: {
        external: false
        targetPort: 5002
        transport: 'Auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
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
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${registryUrl}/api:latest'
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
              name: 'ApplicationInsights__ConnectionString'
              secretRef: 'app-insights-connection-string'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'cpu'
            custom: {
              rule: 'cpu < 70'
            }
          }
        ]
      }
    }
  }

  tags: {
    environment: environment
  }
}

output frontendUrl string = 'https://${frontendContainerApp.properties.configuration.ingress.fqdn}'
output bffUrl string = 'https://${bffContainerApp.properties.configuration.ingress.fqdn}'
output apiUrl string = 'http://${apiContainerApp.properties.configuration.ingress.fqdn}:5002'
output frontendPrincipalId string = frontendContainerApp.identity.principalId
output bffPrincipalId string = bffContainerApp.identity.principalId
output apiPrincipalId string = apiContainerApp.identity.principalId
