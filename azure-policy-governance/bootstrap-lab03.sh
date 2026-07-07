#!/usr/bin/env bash
# Lab 03 bootstrap for Azure Cloud Shell — creates ~/lab03 with all files.
mkdir -p ~/lab03/bicep ~/lab03/terraform && cd ~/lab03

cat > bicep/policy.bicep <<'EOF'
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
    enforcementMode: 'Default'
  }
}

output policyDefinitionId string = policyDef.id
output assignmentName string = assignment.name
EOF

cat > terraform/providers.tf <<'EOF'
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
EOF

cat > terraform/main.tf <<'EOF'
data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group" "rg" {
  name     = "azlab03-tf-rg"
  location = "eastus"
  tags = {
    lab = "lab-03"
  }
}

resource "azurerm_resource_group_policy_assignment" "loc" {
  name                 = "allowed-locations-eastus"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["eastus"]
    }
  })
}

output "assigned_policy" {
  value = data.azurerm_policy_definition.allowed_locations.display_name
}
output "test_resource_group" {
  value = azurerm_resource_group.rg.name
}
EOF

echo "=== Lab 03 files created in ~/lab03 ==="
find . -type f | sort
