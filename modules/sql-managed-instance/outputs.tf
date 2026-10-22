output "id" {
  description = "SQL Managed Instance ID."
  value       = azurerm_mssql_managed_instance.this.id
}

output "fqdn" {
  description = "SQL Managed Instance fully qualified domain name."
  value       = azurerm_mssql_managed_instance.this.fqdn
}

output "principal_id" {
  description = "SQL Managed Instance system-assigned identity principal ID."
  value       = azurerm_mssql_managed_instance.this.identity[0].principal_id
}

output "network_security_group_id" {
  description = "SQL Managed Instance subnet network security group ID."
  value       = module.network_security_group.id
}

output "route_table_id" {
  description = "SQL Managed Instance subnet route table ID."
  value       = module.route_table.id
}
