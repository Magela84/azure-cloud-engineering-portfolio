#!/usr/bin/env bash
# Lab 05 bootstrap for Azure Cloud Shell — creates ~/lab05 with the Bicep base.
mkdir -p ~/lab05/bicep && cd ~/lab05

cat > bicep/main.bicep <<'EOF'
@description('Region.')
param location string = resourceGroup().location
@description('Naming prefix.')
param namePrefix string = 'azlab05'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.30.0.0/16' ]
    }
    subnets: [
      {
        name: 'pe-subnet'
        properties: {
          addressPrefix: '10.30.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
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
    publicNetworkAccess: 'Enabled'
  }
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
    publicNetworkAccess: 'Enabled'
  }
}

output vnetName string = vnet.name
output subnetName string = vnet.properties.subnets[0].name
output storageAccountName string = storage.name
output keyVaultName string = kv.name
EOF

echo "=== Lab 05 files created in ~/lab05 ==="
find . -type f | sort
