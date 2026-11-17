output "id" {
  description = "Cosmos DB account ID."
  value       = azurerm_cosmosdb_account.this.id
}

output "name" {
  description = "Cosmos DB account name."
  value       = azurerm_cosmosdb_account.this.name
}

output "endpoint" {
  description = "Cosmos DB account endpoint."
  value       = azurerm_cosmosdb_account.this.endpoint
}

output "hostname" {
  description = "API-specific Cosmos DB account hostname."
  value       = "${azurerm_cosmosdb_account.this.name}.${local.endpoint_hostname_suffixes[var.api_type]}"
}

output "api_type" {
  description = "Cosmos DB API type."
  value       = var.api_type
}

output "database_id" {
  description = "Database or keyspace ID, or null for the Table API."
  value = try(compact([
    try(azurerm_cosmosdb_sql_database.this[0].id, null),
    try(azurerm_cosmosdb_mongo_database.this[0].id, null),
    try(azurerm_cosmosdb_cassandra_keyspace.this[0].id, null),
    try(azurerm_cosmosdb_gremlin_database.this[0].id, null)
  ])[0], null)
}

output "container_id" {
  description = "Container, collection, table, or graph ID."
  value = try(compact([
    try(azurerm_cosmosdb_sql_container.this[0].id, null),
    try(azurerm_cosmosdb_mongo_collection.this[0].id, null),
    try(azurerm_cosmosdb_cassandra_table.this[0].id, null),
    try(azurerm_cosmosdb_gremlin_graph.this[0].id, null),
    try(azurerm_cosmosdb_table.this[0].id, null)
  ])[0], null)
}

output "principal_id" {
  description = "System-assigned identity principal ID."
  value       = azurerm_cosmosdb_account.this.identity[0].principal_id
}
