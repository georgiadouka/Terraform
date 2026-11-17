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
