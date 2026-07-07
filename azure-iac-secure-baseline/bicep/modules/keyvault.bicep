// Key Vault module: RBAC-authorization model (modern best practice over access policies).
@description('Region.')
param location string

@description('Globally-unique Key Vault name (3-24 chars).')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Tags to apply.')
param tags object

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true      // use Azure RBAC, not legacy access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: null         // keep null in lab so you can fully purge on teardown
    publicNetworkAccess: 'Enabled'      // tighten in Lab 07
  }
}

output keyVaultUri string = kv.properties.vaultUri
output keyVaultId string = kv.id
