// =====================================================================
// Lab 04 - Security & Identity
// Provisions the identity building blocks you'll test by hand:
//   * a user-assigned Managed Identity (a passwordless Azure AD identity)
//   * an RBAC Key Vault
//   * a Storage Account with SHARED-KEY AUTH DISABLED (forces Azure AD)
//   * a role assignment granting the managed identity "Key Vault Secrets User"
//
// Deploy at RESOURCE GROUP scope:
//   az group create -n azlab04-rg -l eastus
//   az deployment group create -g azlab04-rg --template-file main.bicep
// =====================================================================

@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azlab04'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

// Built-in role definition IDs (stable GUIDs).
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User (read secrets)

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-mi'
  location: location
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: toLower('${namePrefix}-${suffix}-kv')
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}${suffix}sa')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // <-- the security upgrade: no account keys, Azure AD only
  }
}

// Grant the managed identity permission to READ secrets from the vault.
resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, mi.id, secretsUserRoleId)
  scope: kv
  properties: {
    principalId: mi.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

output managedIdentityName string = mi.name
output managedIdentityClientId string = mi.properties.clientId
output managedIdentityPrincipalId string = mi.properties.principalId
output keyVaultName string = kv.name
output storageAccountName string = storage.name
