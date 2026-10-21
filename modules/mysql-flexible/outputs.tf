output "id" {
  description = "MySQL Flexible Server ID."
  value       = azurerm_mysql_flexible_server.this.id
}

output "name" {
  description = "MySQL Flexible Server name."
  value       = azurerm_mysql_flexible_server.this.name
}

output "database_id" {
  description = "MySQL database ID."
  value       = azurerm_mysql_flexible_database.this.id
}

output "database_name" {
  description = "MySQL database name."
  value       = azurerm_mysql_flexible_database.this.name
}

output "fqdn" {
  description = "MySQL Flexible Server FQDN."
  value       = azurerm_mysql_flexible_server.this.fqdn
}
