// =====================================================================
// Lab 01 - Secure baseline stack (Bicep)
// Deploys: VNet + subnet + NSG, a hardened Storage Account, and a Key Vault.
// Demonstrates: params, variables, modules, outputs, RBAC-enabled Key Vault.
//
// Deploy at SUBSCRIPTION scope so Bicep creates the resource group too.
//   az deployment sub create \
//     --location eastus \
//     --template-file main.bicep \
//     --parameters @main.parameters.json
// =====================================================================

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Short environment tag, e.g. dev / lab / prod.')
@allowed([ 'dev', 'lab', 'test' ])
param environment string = 'lab'

@description('A short, lowercase, globally-unique-ish prefix (3-8 chars).')
@minLength(3)
@maxLength(8)
param namePrefix string = 'azlab01'

// Deterministic-but-unique suffix so storage/keyvault names don't collide globally.
var suffix = substring(uniqueString(subscription().id, namePrefix), 0, 5)
var rgName = '${namePrefix}-${environment}-rg'

var tags = {
  environment: environment
  managedBy: 'bicep'
  lab: 'lab-01-iac'
}

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'network-deploy'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage-deploy'
  scope: rg
  params: {
    location: location
    storageName: toLower('${namePrefix}${suffix}sa')
    tags: tags
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault-deploy'
  scope: rg
  params: {
    location: location
    keyVaultName: toLower('${namePrefix}-${suffix}-kv')
    tags: tags
  }
}

output resourceGroupName string = rg.name
output vnetId string = network.outputs.vnetId
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultUri string = keyvault.outputs.keyVaultUri
