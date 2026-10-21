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
