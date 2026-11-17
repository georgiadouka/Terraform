output "id" {
  description = "Premium FileStorage account ID."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Premium FileStorage account name."
  value       = azurerm_storage_account.this.name
}

output "file_share_ids" {
  description = "Premium file share IDs keyed by logical identifier."
  value       = { for key, share in azurerm_storage_share.this : key => share.id }
}
