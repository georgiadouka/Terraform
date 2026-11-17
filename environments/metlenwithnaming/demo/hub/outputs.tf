output "hub_virtual_network_id" {
  description = "Resource ID of the hub VNet."
  value       = azurerm_virtual_network.hub.id
}

output "hub_peering" {
  description = "Line to paste into demo/environment.tfvars."
  value       = "hub_peering = { hub_virtual_network_id = \"${azurerm_virtual_network.hub.id}\" }"
}
