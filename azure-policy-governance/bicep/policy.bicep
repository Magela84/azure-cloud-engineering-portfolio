// =====================================================================
// Lab 03 - Governance as Code (Bicep)
// A CUSTOM policy that DENIES any storage account created with public
// blob access enabled. Defined and assigned at SUBSCRIPTION scope so it
// applies everywhere in the subscription.
//
// Deploy:
//   az deployment sub create --location eastus --template-file policy.bicep
// =====================================================================
targetScope = 'subscription'

@description('Naming prefix.')
param namePrefix string = 'azlab03'

resource policyDef 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: '${namePrefix}-deny-public-blob'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Deny storage accounts that allow public blob access'
    description: 'Storage accounts must have allowBlobPublicAccess = false.'
    metadata: {
      category: 'Storage'
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess'
            equals: true
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource assignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: '${namePrefix}-deny-public-blob-assign'
  properties: {
    displayName: 'Deny public blob storage (Lab 03)'
    description: 'Assignment of the custom deny-public-blob policy.'
    policyDefinitionId: policyDef.id
    enforcementMode: 'Default' // 'Default' enforces (deny); 'DoNotEnforce' = audit-only dry run
  }
}

output policyDefinitionId string = policyDef.id
output assignmentName string = assignment.name
