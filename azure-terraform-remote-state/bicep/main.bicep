// Consumes the storage module FROM THE PRIVATE REGISTRY (not a local path).
// The br: reference points at your ACR. Replace <registry> via the guide, or
// deploy with the registry name passed in — see Part C.
targetScope = 'subscription'

@description('Region.')
param location string = 'eastus'

@description('Your ACR login server, e.g. azlab02acr.azurecr.io')
param registryLoginServer string

@description('Naming prefix.')
param namePrefix string = 'azlab02b'

var suffix = substring(uniqueString(subscription().id, namePrefix), 0, 5)
var tags = { lab: 'lab-02', managedBy: 'bicep' }

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namePrefix}-rg'
  location: location
  tags: tags
}

// Pull the module from the private registry: br:<server>/<path>:<tag>
module dataStore 'br:${registryLoginServer}/bicep/modules/storage:v1' = {
  name: 'data-store'
  scope: rg
  params: {
    name: toLower('${namePrefix}${suffix}data')
    location: location
    sku: 'Standard_LRS'
    tags: tags
  }
}

output dataStorageName string = dataStore.outputs.name
