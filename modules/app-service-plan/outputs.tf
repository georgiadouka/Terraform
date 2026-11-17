output "id" {
  description = "App Service Plan ID."
  value       = azurerm_service_plan.this.id
}

output "name" {
  description = "App Service Plan name."
  value       = azurerm_service_plan.this.name
}

output "os_type" {
  description = "App Service Plan operating system."
  value       = azurerm_service_plan.this.os_type
}

output "sku_name" {
  description = "App Service Plan SKU."
  value       = azurerm_service_plan.this.sku_name
}
