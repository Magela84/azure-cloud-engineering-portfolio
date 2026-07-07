# =====================================================================
# Lab 02 - Reusable modules + remote state
# One resource group, then the SAME storage module instantiated twice
# with different inputs. This is the core value of modules: write once,
# reuse with parameters, stay DRY.
# =====================================================================

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

# Instance 1: a "data" storage account (LRS)
module "storage_data" {
  source              = "./modules/storage"
  name                = lower("${var.name_prefix}${local.suffix}data")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  replication_type    = "LRS"
  tags                = merge(local.common_tags, { role = "data" })
}

# Instance 2: a "logs" storage account (GRS) — same module, different inputs
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
