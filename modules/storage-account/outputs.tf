output "id" {
  description = "Storage account ID."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "shared_access_key_enabled" {
  description = "Whether the account accepts Shared Key authorization."
  value       = azurerm_storage_account.this.shared_access_key_enabled
}

output "primary_access_key" {
  description = "Primary storage account access key when Shared Key is enabled, otherwise null."
  value       = var.shared_access_key_enabled ? azurerm_storage_account.this.primary_access_key : null
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary key-based connection string when Shared Key is enabled, otherwise null."
  value       = var.shared_access_key_enabled ? azurerm_storage_account.this.primary_connection_string : null
  sensitive   = true
}

output "data_plane_role_assignment_ids" {
  description = "Storage data-plane role assignment IDs keyed by logical identifier."
  value       = { for key, assignment in azurerm_role_assignment.data_plane : key => assignment.id }
}

output "container_ids" {
  description = "Blob container IDs keyed by logical identifier."
  value       = { for key, container in azurerm_storage_container.this : key => container.id }
}

output "file_share_ids" {
  description = "File share IDs keyed by logical identifier."
  value       = { for key, share in azurerm_storage_share.this : key => share.id }
}
