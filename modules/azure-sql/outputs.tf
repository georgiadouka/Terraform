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
