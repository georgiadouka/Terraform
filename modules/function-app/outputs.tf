output "id" {
  description = "Function App ID."
  value       = one(concat(azurerm_linux_function_app.this[*].id, azurerm_windows_function_app.this[*].id))
}

output "default_hostname" {
  description = "Function App default hostname."
  value       = one(concat(azurerm_linux_function_app.this[*].default_hostname, azurerm_windows_function_app.this[*].default_hostname))
}

output "principal_id" {
  description = "Function App system-assigned managed identity principal ID."
  value       = one(concat(azurerm_linux_function_app.this[*].identity[0].principal_id, azurerm_windows_function_app.this[*].identity[0].principal_id))
}

output "os_type" {
  description = "Selected Function App hosting OS."
  value       = var.os_type
}
