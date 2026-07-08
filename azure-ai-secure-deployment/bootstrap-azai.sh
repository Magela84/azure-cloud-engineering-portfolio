#!/usr/bin/env bash
# Secure AI deployment bootstrap for Azure Cloud Shell — creates ~/azai.
mkdir -p ~/azai/bicep && cd ~/azai

cat > bicep/main.bicep <<'EOF'
@description('Region.')
param location string = resourceGroup().location
@description('Naming prefix.')
param namePrefix string = 'azai'
@description('AI resource kind. AIServices = unified Azure AI Services / Foundry. Fallback: CognitiveServices.')
@allowed([ 'AIServices', 'CognitiveServices' ])
param aiKind string = 'AIServices'
@description('Public network access.')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource ai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${namePrefix}-${suffix}-ai'
  location: location
  kind: aiKind
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: toLower('${namePrefix}${suffix}')
    disableLocalAuth: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: { defaultAction: 'Allow' }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ai-to-law'
  scope: ai
  properties: {
    workspaceId: law.id
    logs: [ { categoryGroup: 'allLogs', enabled: true } ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}

output aiAccountName string = ai.name
output aiEndpoint string = ai.properties.endpoint
output aiIdentityPrincipalId string = ai.identity.principalId
output workspaceName string = law.name
EOF

echo "=== Secure AI files created in ~/azai ==="
find . -type f | sort
