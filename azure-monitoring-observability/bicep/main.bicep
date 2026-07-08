// =====================================================================
// Monitoring & Observability
// A Log Analytics workspace, a storage account to observe, and a
// diagnostic setting that streams the storage account's metrics into
// the workspace so you can query them with KQL.
//
// Deploy at RESOURCE GROUP scope:
//   az group create -n azmon-rg -l eastus
//   az deployment group create -g azmon-rg --template-file main.bicep
// =====================================================================

@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azmon'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
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
  }
}

// Stream the storage account's metrics into the workspace.
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: storage
  properties: {
    workspaceId: law.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

output workspaceName string = law.name
// The customerId GUID is what 'az monitor log-analytics query -w <GUID>' needs.
output workspaceGuid string = law.properties.customerId
output workspaceResourceId string = law.id
output storageAccountName string = storage.name
