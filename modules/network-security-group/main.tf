variable "name" {
  description = "Network security group name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "security_rules" {
  description = "Security rules keyed by rule name. Port ranges default to \"*\". Set exactly one of the singular or plural form for source and destination addresses."
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    description                  = optional(string)
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for rule_name in keys(var.security_rules) :
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_.-]{0,78}[a-zA-Z0-9_])?$", rule_name))
    ])
    error_message = "security_rules keys must be 1-80 characters, start with a letter or digit, end with a letter, digit, or underscore, and contain only letters, digits, underscores, periods, or hyphens."
  }

  validation {
    condition = alltrue([
      for rule in values(var.security_rules) :
      rule.priority >= 100 && rule.priority <= 4096 && rule.priority == floor(rule.priority)
    ])
    error_message = "Every security rule priority must be a whole number from 100 through 4096."
  }

  validation {
    condition = alltrue([
      for rule in values(var.security_rules) :
      contains(["Inbound", "Outbound"], rule.direction) &&
      contains(["Allow", "Deny"], rule.access) &&
      contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], rule.protocol)
    ])
    error_message = "Every security rule needs direction Inbound or Outbound, access Allow or Deny, and protocol Tcp, Udp, Icmp, Esp, Ah, or *."
  }

  validation {
    condition = alltrue([
      for direction in ["Inbound", "Outbound"] : (
        length([for rule in values(var.security_rules) : rule.priority if rule.direction == direction]) ==
        length(distinct([for rule in values(var.security_rules) : rule.priority if rule.direction == direction]))
      )
    ])
    error_message = "Security rule priorities must be unique within each direction."
  }

  validation {
    condition = alltrue([
      for rule in values(var.security_rules) :
      !(rule.source_port_range != null && rule.source_port_ranges != null) &&
      !(rule.destination_port_range != null && rule.destination_port_ranges != null)
    ])
    error_message = "Set either the singular or the plural form of source_port_range(s) and destination_port_range(s), not both."
  }

  validation {
    condition = alltrue([
      for rule in values(var.security_rules) :
      (rule.source_address_prefix == null) != (rule.source_address_prefixes == null) &&
      (rule.destination_address_prefix == null) != (rule.destination_address_prefixes == null)
    ])
    error_message = "Every security rule must set exactly one of source_address_prefix or source_address_prefixes, and exactly one of destination_address_prefix or destination_address_prefixes."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs associated with the network security group, keyed by stable logical name."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the network security group."
  type        = map(string)
  default     = {}
}

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

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnet_ids

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.this.id

  # Rules are in place before subnets start enforcing the group.
  depends_on = [azurerm_network_security_rule.this]
}

output "id" {
  description = "Network security group ID."
  value       = azurerm_network_security_group.this.id
}

output "name" {
  description = "Network security group name."
  value       = azurerm_network_security_group.this.name
}

output "security_rule_ids" {
  description = "Security rule IDs keyed by rule name."
  value       = { for key, rule in azurerm_network_security_rule.this : key => rule.id }
}
