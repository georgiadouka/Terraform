output "id" {
  description = "Logic App ID."
  value       = azurerm_logic_app_standard.this.id
}

output "name" {
  description = "Logic App name."
  value       = azurerm_logic_app_standard.this.name
}

output "default_hostname" {
  description = "Logic App default hostname."
  value       = azurerm_logic_app_standard.this.default_hostname
}

output "principal_id" {
  description = "Logic App system-assigned managed identity principal ID."
  value       = azurerm_logic_app_standard.this.identity[0].principal_id
}

output "service_plan_id" {
  description = "ID of the App Service Plan the app runs on, created by this module or supplied through service_plan_id."
  value       = local.service_plan_id
}
