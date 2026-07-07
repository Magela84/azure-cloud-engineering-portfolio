// Network module: VNet, a workload subnet, and an NSG that denies inbound by default.
@description('Region.')
param location string

@description('Naming prefix.')
param namePrefix string

@description('Tags to apply.')
param tags object

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // Deny all inbound explicitly (above Azure's default rules) to show intent.
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.20.0.0/16' ]
    }
    subnets: [
      {
        name: 'workload'
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
