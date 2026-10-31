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

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.administrator_login) != ""
  #   error_message = "administrator_login must be nonempty."
  # }
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

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.sku_name) != ""
  #   error_message = "sku_name must be nonempty."
  # }
}

variable "version_number" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.version_number) != ""
  #   error_message = "version_number must be nonempty."
  # }
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

  # Disabled: azurerm validates this at plan time.
  # validation {
  #   condition     = contains(["SameZone", "ZoneRedundant"], var.high_availability.mode)
  #   error_message = "High availability mode must be SameZone or ZoneRedundant."
  # }

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
