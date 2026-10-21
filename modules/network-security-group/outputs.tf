output "id" {
  description = "Network security group ID."
  value       = azurerm_network_security_group.this.id
}

output "name" {
  description = "Network security group name."
  value       = azurerm_network_security_group.this.name
}

output "security_rule_ids" {
  description = "Security rule IDs keyed by rule name."
  value       = { for key, rule in azurerm_network_security_rule.this : key => rule.id }
}
