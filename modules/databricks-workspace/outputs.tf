output "id" {
  description = "Azure Databricks workspace ID."
  value       = azurerm_databricks_workspace.this.id
}

output "name" {
  description = "Azure Databricks workspace name."
  value       = azurerm_databricks_workspace.this.name
}

output "workspace_url" {
  description = "Workspace URL (adb-<workspace_id>.<n>.azuredatabricks.net), used as the host of the databricks provider."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "workspace_id" {
  description = "Azure Databricks workspace ID used by Databricks APIs (the number in the workspace URL)."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "network_access" {
  description = "Network access mode: private, backend_private, or public."
  value       = var.network_access
}

output "managed_resource_group_id" {
  description = "ID of the resource group that Azure Databricks manages for the workspace."
  value       = azurerm_databricks_workspace.this.managed_resource_group_id
}

output "managed_resource_group_name" {
  description = "Name of the resource group that Azure Databricks manages for the workspace."
  value       = azurerm_databricks_workspace.this.managed_resource_group_name
}

output "root_storage_account_name" {
  description = "Workspace root (DBFS) storage account name."
  value       = azurerm_databricks_workspace.this.custom_parameters[0].storage_account_name
}

output "network_security_group_id" {
  description = "ID of the network security group attached to both workspace subnets."
  value       = module.network_security_group.id
}

output "network_security_group_name" {
  description = "Name of the network security group attached to both workspace subnets."
  value       = module.network_security_group.name
}

output "access_connector_id" {
  description = "Access Connector ID, or null when none is created."
  value       = try(azurerm_databricks_access_connector.this[0].id, null)
}

output "access_connector_principal_id" {
  description = "Principal ID of the Access Connector's system-assigned identity, or null when none is created."
  value       = try(azurerm_databricks_access_connector.this[0].identity[0].principal_id, null)
}

output "access_connector_role_assignment_ids" {
  description = "Storage Blob Data Contributor role assignment IDs of the Access Connector, keyed like access_connector_storage_account_ids."
  value       = { for key, assignment in azurerm_role_assignment.access_connector_storage : key => assignment.id }
}

output "diagnostic_setting_id" {
  description = "Diagnostic setting ID, or null when diagnostics are disabled."
  value       = try(azurerm_monitor_diagnostic_setting.this[0].id, null)
}
