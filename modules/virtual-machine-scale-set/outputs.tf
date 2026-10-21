output "id" {
  description = "Virtual Machine Scale Set ID."
  value       = local.virtual_machine_scale_set_id
}

output "name" {
  description = "Virtual Machine Scale Set name."
  value       = local.virtual_machine_scale_set_name
}

output "unique_id" {
  description = "Azure-generated Virtual Machine Scale Set unique ID."
  value       = local.virtual_machine_scale_set_unique_id
}

output "os_type" {
  description = "Selected operating system."
  value       = var.os_type
}

output "principal_id" {
  description = "System-assigned managed identity principal ID."
  value       = local.virtual_machine_scale_set_principal_id
}

output "autoscale_setting_id" {
  description = "Azure Monitor autoscale setting ID."
  value       = azurerm_monitor_autoscale_setting.this.id
}

output "scaling_mode" {
  description = "Selected capacity mode: fixed or autoscale."
  value       = var.scaling.mode
}
