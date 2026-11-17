output "id" {
  description = "Recovery Services vault ID."
  value       = azurerm_recovery_services_vault.this.id
}

output "name" {
  description = "Recovery Services vault name."
  value       = azurerm_recovery_services_vault.this.name
}

output "policy_ids" {
  description = "VM backup policy IDs keyed by policy key."
  value       = { for key, policy in azurerm_backup_policy_vm.this : key => policy.id }
}

output "protected_item_ids" {
  description = "Backup protected item IDs keyed by the protected_virtual_machines key."
  value       = { for key, item in azurerm_backup_protected_vm.this : key => item.id }
}
