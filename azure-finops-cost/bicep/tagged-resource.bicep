// Cost allocation through TAGS.
// Tags are labels on resources. Cost reports can group by tag, so tagging
// with a cost center / owner / environment lets you answer "who spent what".
@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azfin'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

// These tags are what make cost reporting useful — you can slice spend by them.
var costTags = {
  costCenter: 'engineering-123'
  environment: 'dev'
  owner: 'platform-team'
  project: 'finops-demo'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}${suffix}sa')
  location: location
  tags: costTags
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
output appliedTags object = costTags
