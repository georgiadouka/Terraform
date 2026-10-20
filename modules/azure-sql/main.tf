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

resource "azurerm_mssql_server" "this" {
  name                                 = var.server_name
  resource_group_name                  = var.resource_group_name
  location                             = var.location
  version                              = "12.0"
  minimum_tls_version                  = "1.2"
  public_network_access_enabled        = false
  outbound_network_restriction_enabled = true
  tags                                 = var.tags

  azuread_administrator {
    login_username              = var.azuread_administrator.login_username
    object_id                   = var.azuread_administrator.object_id
    tenant_id                   = var.azuread_administrator.tenant_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_elasticpool" "this" {
  count = var.elastic_pool.enabled ? 1 : 0

  name                = var.elastic_pool.name
  resource_group_name = var.resource_group_name
  location            = var.location
  server_name         = azurerm_mssql_server.this.name
  max_size_gb         = var.elastic_pool.max_size_gb
  license_type        = var.elastic_pool.license_type
  zone_redundant      = var.elastic_pool.zone_redundant
  tags                = var.tags

  sku {
    name     = var.elastic_pool.sku.name
    tier     = var.elastic_pool.sku.tier
    capacity = var.elastic_pool.sku.capacity
    family   = var.elastic_pool.sku.family
  }

  per_database_settings {
    min_capacity = var.elastic_pool.per_database_settings.min_capacity
    max_capacity = var.elastic_pool.per_database_settings.max_capacity
  }
}

resource "azurerm_mssql_database" "this" {
  name                                = var.database_name
  server_id                           = azurerm_mssql_server.this.id
  elastic_pool_id                     = var.elastic_pool.enabled ? azurerm_mssql_elasticpool.this[0].id : null
  sku_name                            = var.elastic_pool.enabled ? null : var.database_sku_name
  max_size_gb                         = var.max_size_gb
  zone_redundant                      = false
  storage_account_type                = "Local"
  transparent_data_encryption_enabled = true
  tags                                = var.tags

  lifecycle {
    precondition {
      condition     = !var.elastic_pool.enabled || var.max_size_gb <= var.elastic_pool.max_size_gb
      error_message = "The database max_size_gb cannot exceed the elastic pool max_size_gb."
    }
  }
}

output "server_id" {
  description = "Azure SQL logical server ID."
  value       = azurerm_mssql_server.this.id
}

output "server_name" {
  description = "Azure SQL logical server name."
  value       = azurerm_mssql_server.this.name
}

output "database_name" {
  description = "Azure SQL database name."
  value       = azurerm_mssql_database.this.name
}

output "database_id" {
  description = "Azure SQL database ID."
  value       = azurerm_mssql_database.this.id
}

output "elastic_pool_id" {
  description = "Elastic pool ID, or null when the database is standalone."
  value       = var.elastic_pool.enabled ? azurerm_mssql_elasticpool.this[0].id : null
}

output "elastic_pool_name" {
  description = "Elastic pool name, or null when the database is standalone."
  value       = var.elastic_pool.enabled ? azurerm_mssql_elasticpool.this[0].name : null
}

output "fully_qualified_domain_name" {
  description = "Azure SQL logical server FQDN."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}
