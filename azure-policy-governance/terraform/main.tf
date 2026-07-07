# =====================================================================
# Lab 03 - Governance as Code (Terraform)
# Consume a BUILT-IN Azure Policy ("Allowed locations") and assign it to
# a resource group so only eastus resources are permitted there.
# Shows the common pattern: reuse Microsoft's built-in policies rather
# than writing your own.
# =====================================================================

# Look up the built-in policy by its display name (no need to hardcode the GUID).
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

  # Built-in policies take parameters. This one wants the list of allowed regions.
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
