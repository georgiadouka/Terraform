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
