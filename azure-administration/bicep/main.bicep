// A storage account to administer — the day-to-day admin tasks (locks,
// tags, lifecycle, inventory) are done against it with the CLI in the lab.
@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azadmin'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}${suffix}sa')
  location: location
  tags: {
    environment: 'dev'
    owner: 'platform-team'
  }
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
