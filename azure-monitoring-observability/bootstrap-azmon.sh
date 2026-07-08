#!/usr/bin/env bash
# Monitoring & Observability bootstrap for Azure Cloud Shell — creates ~/azmon.
mkdir -p ~/azmon/bicep && cd ~/azmon

cat > bicep/main.bicep <<'EOF'
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
output workspaceGuid string = law.properties.customerId
output workspaceResourceId string = law.id
output storageAccountName string = storage.name
EOF

echo "=== Monitoring files created in ~/azmon ==="
find . -type f | sort
