#!/usr/bin/env bash
# Lab 02 bootstrap for Azure Cloud Shell — creates ~/lab02 with all files.
mkdir -p ~/lab02/terraform/modules/storage ~/lab02/bicep && cd ~/lab02

cat > terraform/providers.tf <<'EOF'
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
EOF

cat > terraform/variables.tf <<'EOF'
variable "location" {
  type    = string
  default = "eastus"
}
variable "name_prefix" {
  type    = string
  default = "azlab02"
}
EOF

cat > terraform/main.tf <<'EOF'
locals {
  suffix = substr(sha1("${var.name_prefix}${var.location}"), 0, 5)
  common_tags = {
    lab       = "lab-02"
    managedBy = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

module "storage_data" {
  source              = "./modules/storage"
  name                = lower("${var.name_prefix}${local.suffix}data")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  replication_type    = "LRS"
  tags                = merge(local.common_tags, { role = "data" })
}

module "storage_logs" {
  source              = "./modules/storage"
  name                = lower("${var.name_prefix}${local.suffix}logs")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  replication_type    = "GRS"
  tags                = merge(local.common_tags, { role = "logs" })
}

output "data_storage_name" {
  value = module.storage_data.name
}
output "logs_storage_name" {
  value = module.storage_logs.name
}
EOF

cat > terraform/modules/storage/main.tf <<'EOF'
resource "azurerm_storage_account" "this" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.replication_type
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}
EOF

cat > terraform/modules/storage/variables.tf <<'EOF'
variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "replication_type" {
  type    = string
  default = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "ZRS"], var.replication_type)
    error_message = "replication_type must be LRS, GRS, or ZRS."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
EOF

cat > terraform/modules/storage/outputs.tf <<'EOF'
output "name" { value = azurerm_storage_account.this.name }
output "id"   { value = azurerm_storage_account.this.id }
EOF

cat > bicep/storage-module.bicep <<'EOF'
@minLength(3)
@maxLength(24)
param name string
param location string
@allowed([ 'Standard_LRS', 'Standard_GRS', 'Standard_ZRS' ])
param sku string = 'Standard_LRS'
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: sku }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

output name string = storage.name
output id string = storage.id
EOF

cat > bicep/main.bicep <<'EOF'
targetScope = 'subscription'
param location string = 'eastus'
param registryLoginServer string
param namePrefix string = 'azlab02b'

var suffix = substring(uniqueString(subscription().id, namePrefix), 0, 5)
var tags = { lab: 'lab-02', managedBy: 'bicep' }

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namePrefix}-rg'
  location: location
  tags: tags
}

module dataStore 'br:${registryLoginServer}/bicep/modules/storage:v1' = {
  name: 'data-store'
  scope: rg
  params: {
    name: toLower('${namePrefix}${suffix}data')
    location: location
    sku: 'Standard_LRS'
    tags: tags
  }
}

output dataStorageName string = dataStore.outputs.name
EOF

echo "=== Lab 02 files created in ~/lab02 ==="
find . -type f | sort
