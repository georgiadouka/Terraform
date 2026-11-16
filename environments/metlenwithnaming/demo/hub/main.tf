# Stand-in for the customer's existing hub VNet, so the demo can show hub
# peering in a subscription without a hub. A real hub holds the firewall and
# gateways; peering needs only the VNet, so this one has no subnets.
resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.address_space
  tags                = var.tags
}
