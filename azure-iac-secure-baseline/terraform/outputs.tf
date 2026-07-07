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
