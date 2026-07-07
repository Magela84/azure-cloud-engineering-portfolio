// Storage module: hardened Storage Account.
// Security posture: TLS1_2 minimum, HTTPS-only, no public blob access, no shared-key
// where avoidable. Great talking points for an architecture/security review.
@description('Region.')
param location string

@description('Globally-unique storage account name (3-24 lowercase alphanumerics).')
@minLength(3)
@maxLength(24)
param storageName string

@description('Tags to apply.')
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // set false in Lab 06 once you wire up managed identity
    networkAcls: {
      defaultAction: 'Allow' // tighten to 'Deny' + Private Endpoint in Lab 07
      bypass: 'AzureServices'
    }
  }
}

output storageAccountName string = storage.name
output storageAccountId string = storage.id
