variable "name" {
  description = "PostgreSQL Flexible Server name."
  type        = string
}

variable "database_name" {
  description = "PostgreSQL database name."
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
  description = "Delegated PostgreSQL subnet ID."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for PostgreSQL."
  type        = string
}

variable "administrator_login" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "pgadminuser"

  validation {
    condition     = trimspace(var.administrator_login) != ""
    error_message = "administrator_login must be nonempty."
  }
}

variable "administrator_password" {
  description = "PostgreSQL administrator password."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "PostgreSQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"

  validation {
    condition     = trimspace(var.sku_name) != ""
    error_message = "sku_name must be nonempty."
  }
}

variable "version_number" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"

  validation {
    condition     = trimspace(var.version_number) != ""
    error_message = "version_number must be nonempty."
  }
}

variable "storage_mb" {
  description = "Allocated storage in MiB."
  type        = number
  default     = 32768

  validation {
    condition     = var.storage_mb >= 32768 && var.storage_mb == floor(var.storage_mb)
    error_message = "storage_mb must be a whole number of at least 32768 MiB."
  }
}

variable "tags" {
  description = "Tags applied to PostgreSQL resources."
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
  description = "Optional high availability. Requires a non-Burstable SKU; standby zone changes after failover are ignored."
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

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.version_number
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  zone                          = var.zone
  tags                          = var.tags

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

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "id" {
  description = "PostgreSQL Flexible Server ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  description = "PostgreSQL Flexible Server name."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "database_id" {
  description = "PostgreSQL database ID."
  value       = azurerm_postgresql_flexible_server_database.this.id
}

output "database_name" {
  description = "PostgreSQL database name."
  value       = azurerm_postgresql_flexible_server_database.this.name
}

output "fqdn" {
  description = "PostgreSQL Flexible Server FQDN."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}
