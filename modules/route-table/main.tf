resource "azurerm_route_table" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  bgp_route_propagation_enabled = var.bgp_route_propagation_enabled
  tags                          = var.tags
}

resource "azurerm_route" "this" {
  for_each = var.routes

  name                   = each.key
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

# Azure can return a subnet ID with different casing than configured, for
# example a lowercase resource group name after SQL Managed Instance updates its
# subnet. Resource IDs are case-insensitive, so the association compares the
# lowercase ID: it ignores subnet_id itself and is replaced only when the
# lowercase ID changes, which still moves it to a genuinely different subnet.
resource "terraform_data" "subnet_id" {
  for_each = var.subnet_ids

  input = lower(each.value)
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = var.subnet_ids

  subnet_id      = each.value
  route_table_id = azurerm_route_table.this.id

  # Routes are in place before subnets start using the table.
  depends_on = [azurerm_route.this]

  lifecycle {
    ignore_changes       = [subnet_id]
    replace_triggered_by = [terraform_data.subnet_id[each.key]]
  }
}
