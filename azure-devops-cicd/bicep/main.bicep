// Small, clean sample template used to demonstrate the CI pipeline.
// The pipeline compiles this on every push; a syntax error here would
// turn the build red before anyone could deploy it.
@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azcicd'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

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
  }
}

output storageAccountName string = storage.name
