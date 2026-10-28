resource "azurerm_network_security_group" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = var.security_rules

  name                         = each.key
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.this.name
  description                  = each.value.description
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = each.value.source_port_ranges == null ? coalesce(each.value.source_port_range, "*") : null
  source_port_ranges           = each.value.source_port_ranges
  destination_port_range       = each.value.destination_port_ranges == null ? coalesce(each.value.destination_port_range, "*") : null
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefix        = each.value.source_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefix   = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes
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

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnet_ids

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.this.id

  # Rules are in place before subnets start enforcing the group.
  depends_on = [azurerm_network_security_rule.this]

  lifecycle {
    ignore_changes       = [subnet_id]
    replace_triggered_by = [terraform_data.subnet_id[each.key]]
  }
}
