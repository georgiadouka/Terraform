locals {
  public_network_access_enabled = var.network_access != "private"

  # Back-end Private Link (private and backend_private) replaces the inbound
  # control-plane rules Azure Databricks would otherwise add to the NSG.
  network_security_group_rules_required = var.network_access == "public" ? "AllRules" : "NoAzureDatabricksRules"
}

# Azure Databricks adds its required rules to this group through the subnet
# delegation; the module defines none, so Terraform leaves them alone.
module "network_security_group" {
  source = "../network-security-group"

  name                = var.network_security_group_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_ids = {
    host      = var.host_subnet.id
    container = var.container_subnet.id
  }
  tags = var.tags
}

resource "azurerm_databricks_workspace" "this" {
  name                                  = var.name
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  sku                                   = var.sku
  managed_resource_group_name           = var.managed_resource_group_name
  public_network_access_enabled         = local.public_network_access_enabled
  network_security_group_rules_required = local.network_security_group_rules_required
  tags                                  = var.tags

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = var.virtual_network_id
    public_subnet_name                                   = var.host_subnet.name
    private_subnet_name                                  = var.container_subnet.name
    public_subnet_network_security_group_association_id  = module.network_security_group.subnet_association_ids["host"]
    private_subnet_network_security_group_association_id = module.network_security_group.subnet_association_ids["container"]
    storage_account_name                                 = var.root_storage_account_name
  }
}

resource "azurerm_databricks_access_connector" "this" {
  count = var.access_connector_name == null ? 0 : 1

  name                = var.access_connector_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "access_connector_storage" {
  for_each = var.access_connector_storage_account_ids

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics == null ? 0 : 1

  name                       = var.diagnostics.name
  target_resource_id         = azurerm_databricks_workspace.this.id
  log_analytics_workspace_id = var.diagnostics.log_analytics_workspace_id

  # Azure Databricks supports only the allLogs category group.
  dynamic "enabled_log" {
    for_each = length(var.diagnostics.categories) == 0 ? ["allLogs"] : []

    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = toset(var.diagnostics.categories)

    content {
      category = enabled_log.value
    }
  }
}
