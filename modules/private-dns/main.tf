resource "azurerm_private_dns_zone" "this" {
  for_each = var.zone_names

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  # Keyed by the link names, which are known at plan time; the VNet ID is not
  # on the first apply.
  for_each = setintersection(var.zone_names, toset(keys(var.virtual_network_link_names)))

  name                  = var.virtual_network_link_names[each.value]
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value].name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Links every zone to each VNet in virtual_network_links, keyed
# <link key>/<zone name>.
resource "azurerm_private_dns_zone_virtual_network_link" "virtual_networks" {
  for_each = {
    for pair in setproduct(keys(var.virtual_network_links), tolist(var.zone_names)) :
    "${pair[0]}/${pair[1]}" => {
      link = var.virtual_network_links[pair[0]]
      zone = pair[1]
    }
  }

  name                  = each.value.link.name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone].name
  virtual_network_id    = each.value.link.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
