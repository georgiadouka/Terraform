variable "server_name" {
  description = "Azure SQL logical server name."
  type        = string
}

variable "database_name" {
  description = "Azure SQL database name."
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

variable "azuread_administrator" {
  description = "Microsoft Entra administrator configuration. Azure SQL authentication is Entra-only."
  type = object({
    login_username = string
    object_id      = string
    tenant_id      = string
  })
}

variable "database_sku_name" {
  description = "Azure SQL Database SKU."
  type        = string
  default     = "Basic"
}

variable "max_size_gb" {
  description = "Maximum database size in GiB."
  type        = number
  default     = 2

  validation {
    condition     = var.max_size_gb > 0
    error_message = "max_size_gb must be greater than zero."
  }
}

variable "elastic_pool" {
  description = "Optional elastic pool configuration for the database."
  type = object({
    enabled     = optional(bool, false)
    name        = optional(string)
    max_size_gb = optional(number, 4.8828125)
    sku = optional(object({
      name     = optional(string, "BasicPool")
      tier     = optional(string, "Basic")
      capacity = optional(number, 50)
      family   = optional(string)
    }), {})
    per_database_settings = optional(object({
      min_capacity = optional(number, 0)
      max_capacity = optional(number, 5)
    }), {})
    license_type   = optional(string)
    zone_redundant = optional(bool, false)
  })
  default = {}

  validation {
    condition = (
      !var.elastic_pool.enabled ||
      (
        try(trimspace(var.elastic_pool.name), "") != "" &&
        var.elastic_pool.max_size_gb > 0 &&
        var.elastic_pool.sku.capacity > 0 &&
        var.elastic_pool.per_database_settings.min_capacity >= 0 &&
        var.elastic_pool.per_database_settings.max_capacity >= var.elastic_pool.per_database_settings.min_capacity &&
        var.elastic_pool.per_database_settings.max_capacity <= var.elastic_pool.sku.capacity
      )
    )
    error_message = "An enabled elastic pool requires a name, positive pool size and capacity, and per-database capacities between zero and the pool capacity."
  }

  validation {
    condition     = var.elastic_pool.license_type == null || contains(["LicenseIncluded", "BasePrice"], var.elastic_pool.license_type)
    error_message = "elastic_pool.license_type must be LicenseIncluded, BasePrice, or null."
  }
}

variable "tags" {
  description = "Tags applied to Azure SQL resources."
  type        = map(string)
  default     = {}
}
