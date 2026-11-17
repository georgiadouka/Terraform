output "id" {
  description = "Application Insights resource ID."
  value       = azurerm_application_insights.this.id
}

output "name" {
  description = "Application Insights resource name."
  value       = azurerm_application_insights.this.name
}

output "app_id" {
  description = "Application Insights application ID, used by the query API."
  value       = azurerm_application_insights.this.app_id
}

output "connection_string" {
  description = "Connection string for APPLICATIONINSIGHTS_CONNECTION_STRING."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "role_assignment_ids" {
  description = "Monitoring Metrics Publisher role assignment IDs, keyed like metrics_publisher_principal_ids."
  value       = { for key, assignment in azurerm_role_assignment.metrics_publisher : key => assignment.id }
}
