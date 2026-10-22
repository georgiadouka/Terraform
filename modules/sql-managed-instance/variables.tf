variable "name" {
  description = "Globally unique SQL Managed Instance name."
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

variable "subnet_id" {
  description = "Dedicated delegated subnet ID."
  type        = string
}

variable "network_security_group_name" {
  description = "Network security group name."
  type        = string
}

variable "route_table_name" {
  description = "Route table name."
  type        = string
}

variable "security_rules" {
  description = "Security rules for the SQL Managed Instance NSG, keyed by rule name. The service adds and enforces its own mandatory management rules (Microsoft.Sql-managedInstances_UseOnly_mi-*); define only rules for your own traffic, and do not use that prefix. Setting this replaces the default client TDS rule. See the network-security-group module for the rule schema."
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
  nullable = false
  default = {
    "allow-tds-inbound" = {
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      description                = "Client TDS connections from the virtual network."
      destination_port_range     = "1433"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  validation {
    condition     = alltrue([for rule_name in keys(var.security_rules) : !startswith(rule_name, "Microsoft.Sql-managedInstances_UseOnly_")])
    error_message = "security_rules keys must not use the Microsoft.Sql-managedInstances_UseOnly_ prefix, which is reserved for service-managed rules."
  }
}

variable "routes" {
  description = "User-defined routes for the SQL Managed Instance route table, keyed by route name, for example a 0.0.0.0/0 route to a firewall. The service adds and enforces its own mandatory routes (Microsoft.Sql-managedInstances_UseOnly_*); do not use that prefix. See the route-table module for the route schema."
  type = map(object({
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for route_name in keys(var.routes) : !startswith(route_name, "Microsoft.Sql-managedInstances_UseOnly_")])
    error_message = "routes keys must not use the Microsoft.Sql-managedInstances_UseOnly_ prefix, which is reserved for service-managed routes."
  }
}

variable "sku_name" {
  description = "SQL Managed Instance SKU."
  type        = string
  default     = "GP_Gen5"
}

variable "vcores" {
  description = "SQL Managed Instance vCore count."
  type        = number
  default     = 4
}

variable "storage_size_in_gb" {
  description = "SQL Managed Instance storage in GiB, in increments of 32."
  type        = number
  default     = 32

  validation {
    condition     = var.storage_size_in_gb >= 32 && var.storage_size_in_gb % 32 == 0
    error_message = "storage_size_in_gb must be at least 32 and a multiple of 32."
  }
}

variable "license_type" {
  description = "LicenseIncluded or BasePrice for eligible Azure Hybrid Benefit licenses."
  type        = string
  default     = "LicenseIncluded"

  validation {
    condition     = contains(["LicenseIncluded", "BasePrice"], var.license_type)
    error_message = "license_type must be LicenseIncluded or BasePrice."
  }
}

variable "azuread_administrator" {
  description = "Microsoft Entra administrator. Authentication is Entra-only."
  type = object({
    login_username = string
    object_id      = string
    principal_type = optional(string, "User")
    tenant_id      = optional(string)
  })

  validation {
    condition     = contains(["Application", "Group", "User"], var.azuread_administrator.principal_type)
    error_message = "principal_type must be Application, Group, or User."
  }
}

variable "tags" {
  description = "Tags applied to SQL Managed Instance resources."
  type        = map(string)
  default     = {}
}
