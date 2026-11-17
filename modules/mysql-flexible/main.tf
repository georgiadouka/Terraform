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
