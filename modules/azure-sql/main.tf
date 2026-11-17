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

    precondition {
      condition = (
        (var.elastic_pool.enabled ? lower(var.elastic_pool.sku.tier) : lower(var.database_sku_name)) != "basic" ||
        var.max_size_gb <= 2
      )
      error_message = "Basic tier databases, standalone or in a Basic elastic pool, support at most 2 GB; set max_size_gb to 2 or less or choose a higher tier."
    }
  }
}
