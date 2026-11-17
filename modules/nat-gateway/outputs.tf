output "id" {
  description = "NAT Gateway ID."
  value       = azurerm_nat_gateway.this.id
}

output "public_ip_id" {
  description = "NAT Gateway public IP resource ID."
  value       = azurerm_public_ip.this.id
}

output "public_ip_address" {
  description = "NAT Gateway public IPv4 address."
  value       = azurerm_public_ip.this.ip_address
}
