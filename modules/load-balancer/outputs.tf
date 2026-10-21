output "id" {
  description = "Load balancer ID."
  value       = azurerm_lb.this.id
}

output "name" {
  description = "Load balancer name."
  value       = azurerm_lb.this.name
}

output "frontend_private_ip_address" {
  description = "Private IP address of the internal frontend."
  value       = azurerm_lb.this.frontend_ip_configuration[0].private_ip_address
}

output "backend_address_pool_id" {
  description = "Backend address pool ID that VM NICs and scale sets join."
  value       = azurerm_lb_backend_address_pool.this.id
}

output "probe_ids" {
  description = "Health probe IDs keyed by logical name."
  value       = { for key, probe in azurerm_lb_probe.this : key => probe.id }
}

output "rule_ids" {
  description = "Load-balancing rule IDs keyed by logical name."
  value       = { for key, rule in azurerm_lb_rule.this : key => rule.id }
}
