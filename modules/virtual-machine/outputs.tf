output "id" {
  description = "Virtual machine ID."
  value       = local.virtual_machine_id
}

output "name" {
  description = "Virtual machine name."
  value       = local.virtual_machine_name
}

output "private_ip_address" {
  description = "Virtual machine private IP address."
  value       = azurerm_network_interface.this.private_ip_address
}

output "data_disk_ids" {
  description = "Managed disk IDs keyed by logical name."
  value       = { for key, disk in azurerm_managed_disk.data : key => disk.id }
}
