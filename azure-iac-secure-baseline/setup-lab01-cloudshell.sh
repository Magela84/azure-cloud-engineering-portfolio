#!/usr/bin/env bash
# Lab 01 bootstrap for Azure Cloud Shell.
# Creates ~/lab01-iac with all Bicep + Terraform files, then cd into it.
set -e
ROOT=~/lab01-iac
mkdir -p "$ROOT/bicep/modules" "$ROOT/terraform"
cd "$ROOT"

# ---------------- Bicep: main.bicep ----------------
cat > bicep/main.bicep <<'EOF'
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
EOF

# ---------------- Bicep: parameters ----------------
cat > bicep/main.parameters.json <<'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "value": "eastus" },
    "environment": { "value": "lab" },
    "namePrefix": { "value": "azlab01" }
  }
}
EOF

# ---------------- Bicep: network module ----------------
cat > bicep/modules/network.bicep <<'EOF'
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
EOF

# ---------------- Bicep: storage module ----------------
cat > bicep/modules/storage.bicep <<'EOF'
@description('Region.')
param location string
@description('Globally-unique storage account name (3-24 lowercase alphanumerics).')
@minLength(3)
@maxLength(24)
param storageName string
@description('Tags to apply.')
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output storageAccountName string = storage.name
output storageAccountId string = storage.id
EOF

# ---------------- Bicep: keyvault module ----------------
cat > bicep/modules/keyvault.bicep <<'EOF'
@description('Region.')
param location string
@description('Globally-unique Key Vault name (3-24 chars).')
@minLength(3)
@maxLength(24)
param keyVaultName string
@description('Tags to apply.')
param tags object

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: null
    publicNetworkAccess: 'Enabled'
  }
}

output keyVaultUri string = kv.properties.vaultUri
output keyVaultId string = kv.id
EOF

# ---------------- Terraform: providers ----------------
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
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
EOF

# ---------------- Terraform: variables ----------------
cat > terraform/variables.tf <<'EOF'
variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Short environment tag."
  type        = string
  default     = "lab"
  validation {
    condition     = contains(["dev", "lab", "test"], var.environment)
    error_message = "environment must be one of: dev, lab, test."
  }
}

variable "name_prefix" {
  description = "Short lowercase prefix (3-8 chars)."
  type        = string
  default     = "azlab01"
  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 8
    error_message = "name_prefix must be 3-8 characters."
  }
}
EOF

# ---------------- Terraform: main ----------------
cat > terraform/main.tf <<'EOF'
data "azurerm_client_config" "current" {}

locals {
  suffix  = substr(sha1("${var.name_prefix}${var.environment}"), 0, 5)
  rg_name = "${var.name_prefix}-${var.environment}-rg"
  tags = {
    environment = var.environment
    managedBy   = "terraform"
    lab         = "lab-01-iac"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name_prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_storage_account" "sa" {
  name                            = lower("${var.name_prefix}${local.suffix}sa")
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_key_vault" "kv" {
  name                       = lower("${var.name_prefix}-${local.suffix}-kv")
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}
EOF

# ---------------- Terraform: outputs ----------------
cat > terraform/outputs.tf <<'EOF'
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}
EOF

echo ""
echo "Lab 01 files created in: $ROOT"
find . -type f | sort
