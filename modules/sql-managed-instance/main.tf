module "network_security_group" {
  source = "../network-security-group"

  name                = var.network_security_group_name
  resource_group_name = var.resource_group_name
  location            = var.location
  security_rules      = var.security_rules
  subnet_ids          = { sql_managed_instance = var.subnet_id }
  tags                = var.tags
}

module "route_table" {
  source = "../route-table"

  name                = var.route_table_name
  resource_group_name = var.resource_group_name
  location            = var.location
  routes              = var.routes
  subnet_ids          = { sql_managed_instance = var.subnet_id }
  tags                = var.tags
}

resource "azurerm_mssql_managed_instance" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  license_type                 = var.license_type
  sku_name                     = var.sku_name
  storage_size_in_gb           = var.storage_size_in_gb
  subnet_id                    = var.subnet_id
  vcores                       = var.vcores
  minimum_tls_version          = "1.2"
  public_data_endpoint_enabled = false
  proxy_override               = "Redirect"
  storage_account_type         = "LRS"
  zone_redundant_enabled       = false
  tags                         = var.tags

  azure_active_directory_administrator {
    login_username                      = var.azuread_administrator.login_username
    object_id                           = var.azuread_administrator.object_id
    principal_type                      = var.azuread_administrator.principal_type
    tenant_id                           = var.azuread_administrator.tenant_id
    azuread_authentication_only_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  # The subnet must have its NSG and route table associated before the instance is created.
  depends_on = [
    module.network_security_group,
    module.route_table
  ]

  timeouts {
    create = "6h"
    update = "6h"
    delete = "6h"
  }
}
