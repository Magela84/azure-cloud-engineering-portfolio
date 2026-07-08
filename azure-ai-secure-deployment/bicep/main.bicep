// =====================================================================
// Secure AI deployment — an Azure AI Services account, deployed the way a
// cloud engineer should: keys OFF (Azure AD only), a managed identity,
// and its usage/logs streamed to Log Analytics. This is the "run AI
// securely" skill employers want — built on identity + monitoring.
//
// Deploy at RESOURCE GROUP scope:
//   az group create -n azai-rg -l eastus
//   az deployment group create -g azai-rg --template-file main.bicep
// =====================================================================

@description('Region.')
param location string = resourceGroup().location

@description('Naming prefix.')
param namePrefix string = 'azai'

@description('AI resource kind. AIServices = the unified Azure AI Services / Foundry account. If it errors on your subscription (terms/approval), try CognitiveServices.')
@allowed([ 'AIServices', 'CognitiveServices' ])
param aiKind string = 'AIServices'

@description('Public network access. Set Disabled + a private endpoint for private-only (see the guide).')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

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

resource ai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${namePrefix}-${suffix}-ai'
  location: location
  kind: aiKind
  sku: {
    name: 'S0'
  }
  // A passwordless identity for the AI service (used to reach Key Vault, storage, etc.).
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // A custom subdomain is required for Azure AD auth and private endpoints.
    customSubDomainName: toLower('${namePrefix}${suffix}')
    // THE security win: turn OFF API keys so the only way in is Azure AD.
    disableLocalAuth: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow' // tighten to 'Deny' + private endpoint for production (see guide)
    }
  }
}

// Stream the AI service's logs and metrics into the workspace for monitoring.
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ai-to-law'
  scope: ai
  properties: {
    workspaceId: law.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output aiAccountName string = ai.name
output aiEndpoint string = ai.properties.endpoint
output aiIdentityPrincipalId string = ai.identity.principalId
output workspaceName string = law.name
