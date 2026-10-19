variable "name" {
  description = "MySQL Flexible Server name."
  type        = string
}

variable "database_name" {
  description = "MySQL database name."
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

variable "delegated_subnet_id" {
  description = "Delegated MySQL subnet ID."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for MySQL."
  type        = string
}

variable "administrator_login" {
  description = "MySQL administrator login."
  type        = string
  default     = "mysqladminuser"

  validation {
    condition     = trimspace(var.administrator_login) != ""
    error_message = "administrator_login must be nonempty."
  }
}

variable "administrator_password" {
  description = "MySQL administrator password."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "MySQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"

  validation {
    condition     = trimspace(var.sku_name) != ""
    error_message = "sku_name must be nonempty."
  }
}

variable "version_number" {
  description = "MySQL version."
  type        = string
  default     = "8.0.21"

  validation {
    condition     = trimspace(var.version_number) != ""
    error_message = "version_number must be nonempty."
  }
}

variable "tags" {
  description = "Tags applied to MySQL resources."
  type        = map(string)
  default     = {}
}

variable "zone" {
  description = "Primary availability zone. Null lets Azure choose; subsequent failover zone changes are ignored."
  type        = string
  default     = null
  nullable    = true
}

variable "high_availability" {
  description = "Optional high availability. Requires a non-Burstable SKU; standby zone changes after failover are ignored. Plan zone-redundant HA at server creation."
  type = object({
    enabled                   = optional(bool, false)
    mode                      = optional(string, "ZoneRedundant")
    standby_availability_zone = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["SameZone", "ZoneRedundant"], var.high_availability.mode)
    error_message = "High availability mode must be SameZone or ZoneRedundant."
  }

  validation {
    condition     = !var.high_availability.enabled || !startswith(var.sku_name, "B_")
    error_message = "High availability requires a non-Burstable SKU (sku_name must not start with B_)."
  }

  validation {
    condition = (
      !var.high_availability.enabled ||
      var.zone == null ||
      var.high_availability.standby_availability_zone == null ||
      (var.high_availability.mode == "SameZone"
        ? var.zone == var.high_availability.standby_availability_zone
      : var.zone != var.high_availability.standby_availability_zone)
    )
    error_message = "When both zones are set, SameZone requires matching primary and standby zones, and ZoneRedundant requires different zones."
  }
}

resource "azurerm_mysql_flexible_server" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = var.version_number
  delegated_subnet_id          = var.delegated_subnet_id
  private_dns_zone_id          = var.private_dns_zone_id
  administrator_login          = var.administrator_login
  administrator_password       = var.administrator_password
  sku_name                     = var.sku_name
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  zone                         = var.zone
  tags                         = var.tags

  dynamic "high_availability" {
    for_each = var.high_availability.enabled ? [var.high_availability] : []
    content {
      mode                      = high_availability.value.mode
      standby_availability_zone = high_availability.value.standby_availability_zone
    }
  }

  lifecycle {
    # Azure swaps primary and standby zones on failover; do not move them back.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_mysql_flexible_database" "this" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

output "id" {
  description = "MySQL Flexible Server ID."
  value       = azurerm_mysql_flexible_server.this.id
}

output "database_id" {
  description = "MySQL database ID."
  value       = azurerm_mysql_flexible_database.this.id
}

output "fqdn" {
  description = "MySQL Flexible Server FQDN."
  value       = azurerm_mysql_flexible_server.this.fqdn
}
