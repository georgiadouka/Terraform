output "id" {
  description = "Web App ID."
  value       = one(concat(azurerm_linux_web_app.this[*].id, azurerm_windows_web_app.this[*].id))
}

output "default_hostname" {
  description = "Web App default hostname."
  value       = one(concat(azurerm_linux_web_app.this[*].default_hostname, azurerm_windows_web_app.this[*].default_hostname))
}

output "principal_id" {
  description = "Web App system-assigned managed identity principal ID."
  value       = one(concat(azurerm_linux_web_app.this[*].identity[0].principal_id, azurerm_windows_web_app.this[*].identity[0].principal_id))
}

output "mode" {
  description = "Selected Web App hosting mode."
  value       = var.mode
}

output "service_plan_id" {
  description = "ID of the App Service Plan the app runs on, created by this module or supplied through service_plan_id."
  value       = local.service_plan_id
}
