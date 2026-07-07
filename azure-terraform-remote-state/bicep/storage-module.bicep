// Reusable hardened storage module — this is what we PUBLISH to the
// private Bicep module registry (Azure Container Registry).
@description('Storage account name (3-24 lowercase alphanumerics).')
@minLength(3)
@maxLength(24)
param name string

@description('Region.')
param location string

@allowed([ 'Standard_LRS', 'Standard_GRS', 'Standard_ZRS' ])
param sku string = 'Standard_LRS'

@description('Tags.')
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

output name string = storage.name
output id string = storage.id
