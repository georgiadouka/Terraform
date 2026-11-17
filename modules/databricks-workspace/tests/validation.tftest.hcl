mock_provider "azurerm" {}

variables {
  name                        = "M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00"
  resource_group_name         = "rg-validation-test"
  location                    = "swedencentral"
  managed_resource_group_name = "M-AZU-RGP-IT-PPA-GEO-DEV-SWE-00"
  virtual_network_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  network_security_group_name = "M-AZU-NSG-IT-PPA-GEO-PRV-DEV-SWE-00"
  host_subnet = {
    name = "PPAGEODEVPRV10"
    id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/PPAGEODEVPRV10"
  }
  container_subnet = {
    name = "PPAGEODEVPRV11"
    id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/PPAGEODEVPRV11"
  }
}

run "private_by_default" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.public_network_access_enabled == false
    error_message = "The default network_access must disable public network access."
  }

  assert {
    condition     = azurerm_databricks_workspace.this.network_security_group_rules_required == "NoAzureDatabricksRules"
    error_message = "A private workspace must use back-end Private Link (NoAzureDatabricksRules)."
  }

  assert {
    condition     = azurerm_databricks_workspace.this.custom_parameters[0].no_public_ip == true
    error_message = "Clusters must never get public IP addresses."
  }

  assert {
    condition     = azurerm_databricks_workspace.this.sku == "premium"
    error_message = "The default SKU must be premium."
  }

  assert {
    condition     = length(azurerm_databricks_access_connector.this) == 0 && length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "No Access Connector or diagnostic setting is created unless requested."
  }
}

run "backend_private_keeps_public_front_end" {
  command = plan
  variables {
    network_access = "backend_private"
  }

  assert {
    condition = (
      azurerm_databricks_workspace.this.public_network_access_enabled == true &&
      azurerm_databricks_workspace.this.network_security_group_rules_required == "NoAzureDatabricksRules"
    )
    error_message = "backend_private must keep public front-end access and use back-end Private Link."
  }
}

run "public_uses_all_rules" {
  command = plan
  variables {
    network_access = "public"
  }

  assert {
    condition = (
      azurerm_databricks_workspace.this.public_network_access_enabled == true &&
      azurerm_databricks_workspace.this.network_security_group_rules_required == "AllRules"
    )
    error_message = "public must enable public access and require all Azure Databricks NSG rules."
  }
}

run "access_connector_diagnostics_and_root_storage" {
  command = plan
  variables {
    access_connector_name     = "M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00"
    root_storage_account_name = "mazusoaitppageodevswe09"
    access_connector_storage_account_ids = {
      lake = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Storage/storageAccounts/lake"
    }
    diagnostics = {
      name                       = "M-AZU-LAW-IT-PPA-GEO-DEV-SWE-00"
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.OperationalInsights/workspaces/law"
    }
  }

  assert {
    condition     = azurerm_databricks_access_connector.this[0].identity[0].type == "SystemAssigned"
    error_message = "The Access Connector must use a system-assigned identity."
  }

  assert {
    condition     = azurerm_role_assignment.access_connector_storage["lake"].role_definition_name == "Storage Blob Data Contributor"
    error_message = "The Access Connector must get Storage Blob Data Contributor on each listed storage account."
  }

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.this[0].enabled_log).category_group == "allLogs"
    error_message = "Diagnostics without categories must use the allLogs category group, the only one Azure Databricks supports."
  }

  assert {
    condition     = azurerm_databricks_workspace.this.custom_parameters[0].storage_account_name == "mazusoaitppageodevswe09"
    error_message = "root_storage_account_name must name the workspace root storage account."
  }
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_standard_sku" {
#   command = plan
#   variables {
#     sku = "standard"
#   }
#   expect_failures = [var.sku]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_unknown_network_access" {
#   command = plan
#   variables {
#     network_access = "internal"
#   }
#   expect_failures = [var.network_access]
# }

run "reject_role_assignments_without_access_connector" {
  command = plan
  variables {
    access_connector_storage_account_ids = {
      lake = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Storage/storageAccounts/lake"
    }
  }
  expect_failures = [var.access_connector_storage_account_ids]
}

run "diagnostics_with_selected_categories" {
  command = plan
  variables {
    diagnostics = {
      name                       = "diag"
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.OperationalInsights/workspaces/law"
      categories                 = ["clusters", "unityCatalog"]
    }
  }

  assert {
    condition = (
      length(azurerm_monitor_diagnostic_setting.this[0].enabled_log) == 2 &&
      toset([for log in azurerm_monitor_diagnostic_setting.this[0].enabled_log : log.category]) == toset(["clusters", "unityCatalog"])
    )
    error_message = "Selected categories must replace the allLogs category group."
  }
}

run "reject_invalid_category" {
  command = plan
  variables {
    diagnostics = {
      name                       = "diag"
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.OperationalInsights/workspaces/law"
      categories                 = ["all logs"]
    }
  }
  expect_failures = [var.diagnostics]
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_invalid_root_storage_name" {
#   command = plan
#   variables {
#     root_storage_account_name = "Not-Valid"
#   }
#   expect_failures = [var.root_storage_account_name]
# }
