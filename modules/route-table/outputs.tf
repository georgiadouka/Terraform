output "id" {
  description = "Route table ID."
  value       = azurerm_route_table.this.id
}

output "name" {
  description = "Route table name."
  value       = azurerm_route_table.this.name
}

output "route_ids" {
  description = "Route IDs keyed by route name."
  value       = { for key, route in azurerm_route.this : key => route.id }
}
