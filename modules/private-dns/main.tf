variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "virtual_network_id" {
  description = "Virtual network linked to every private DNS zone."
  type        = string
}

variable "zone_names" {
  description = "Private DNS zone names."
  type        = set(string)
}

variable "virtual_network_link_names" {
  description = "VNet link names keyed by Private DNS zone name."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to private DNS zones."
  type        = map(string)
  default     = {}
}

resource "azurerm_private_dns_zone" "this" {
  for_each = var.zone_names

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.zone_names

  name                  = var.virtual_network_link_names[each.value]
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value].name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

output "zone_ids" {
  description = "Private DNS zone IDs keyed by zone name."
  value       = { for name, zone in azurerm_private_dns_zone.this : name => zone.id }
}
