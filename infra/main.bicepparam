using './main.bicep'

param location = 'eastus'
param environment = 'dev'
param projectName = 'entra-demo'
// IMPORTANT: The following values are placeholders and MUST be overridden by pipeline with actual secrets
// Never commit real passwords to this file
param registryUsername = 'registryUsernameFromDevOps'
param registryPassword = 'registryPasswordFromDevOps'
param sqlAdminUsername = 'sqladmin'
param sqlAdminPassword = 'sqlPasswordFromDevOps'

// Use existing ACR registry instead of creating new one
param useExistingRegistry = true
param existingRegistryName = 'entrademodevacr'
param existingRegistryUrl = 'entrademodevacr.azurecr.io'
