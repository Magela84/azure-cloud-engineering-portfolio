# =====================================================================
# Lab 01 - Secure baseline stack (Terraform)
# Same resources as the Bicep version, so you can compare the two tools
# side by side: RG + VNet/subnet/NSG + hardened Storage + RBAC Key Vault.
# =====================================================================

data "azurerm_client_config" "current" {}

locals {
  suffix   = substr(sha1("${var.name_prefix}${var.environment}"), 0, 5)
  rg_name  = "${var.name_prefix}-${var.environment}-rg"
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

# ---------- Network ----------
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

# ---------- Storage (hardened) ----------
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
  # network_rules intentionally omitted: default_action "Allow" equals the Azure
  # default, and declaring it inline caused a phantom perpetual diff (see RCA in
  # lab-notes.md). When locking down in Lab 07, manage rules via the dedicated
  # azurerm_storage_account_network_rules resource with default_action = "Deny".
}

# ---------- Key Vault (RBAC model) ----------
resource "azurerm_key_vault" "kv" {
  name                       = lower("${var.name_prefix}-${local.suffix}-kv")
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}
