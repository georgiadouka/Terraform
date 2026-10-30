# Locks in the Azure Databricks wiring: subnets, Private Endpoints per network
# access mode, the dedicated browser authentication workspace and its delete
# lock, and the plan-time warnings.

# The azurerm.hub alias is configured even when hub_peering is unset.
mock_provider "azurerm" {
  alias = "hub"
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}

override_module {
  target = module.network
  outputs = {
    id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    name = "vnet-test"
    subnet_ids = {
      "private_endpoints"              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/pe"
      "databricks/analytics/host"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/analytics-host"
      "databricks/analytics/container" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/analytics-container"
      "databricks/sandbox/host"        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/sandbox-host"
      "databricks/sandbox/container"   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/sandbox-container"
      "databricks/webauth/host"        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/webauth-host"
      "databricks/webauth/container"   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/webauth-container"
    }
  }
}

override_module {
  target = module.private_dns
  outputs = {
    zone_ids = {
      "privatelink.azuredatabricks.net"   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net"
      "privatelink.blob.core.windows.net" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
      "privatelink.file.core.windows.net" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
    }
  }
}

override_module {
  target = module.databricks
  outputs = {
    id                            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Databricks/workspaces/dbw"
    name                          = "dbw"
    workspace_url                 = "adb-1.1.azuredatabricks.net"
    workspace_id                  = "1"
    network_access                = "private"
    managed_resource_group_name   = "mrg"
    root_storage_account_name     = null
    network_security_group_name   = "nsg"
    access_connector_id           = null
    access_connector_principal_id = null
  }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  storage_use_azuread     = true
  location                = "swedencentral"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "GEO", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
      subnets = {
        private_endpoints    = { cidr = "10.42.0.0/24", number = 1 }
        virtual_machines     = { cidr = "10.42.1.0/24", number = 2 }
        web_app_integration  = { cidr = "10.42.8.0/26", number = 3 }
        function_integration = { cidr = "10.42.4.0/24", number = 4 }
        postgresql           = { cidr = "10.42.5.0/24", number = 5 }
        mysql                = { cidr = "10.42.6.0/24", number = 6 }
        sql_managed_instance = { cidr = "10.42.7.0/27", number = 7 }
        # Workload workspaces need egress; the browser authentication
        # workspace runs no clusters.
        "databricks/analytics/host"      = { cidr = "10.42.9.0/26", number = 10, nat_gateway = true }
        "databricks/analytics/container" = { cidr = "10.42.9.64/26", number = 11, nat_gateway = true }
        "databricks/sandbox/host"        = { cidr = "10.42.10.0/26", number = 14, nat_gateway = true }
        "databricks/sandbox/container"   = { cidr = "10.42.10.64/26", number = 15, nat_gateway = true }
        "databricks/webauth/host"        = { cidr = "10.42.11.0/28", number = 12 }
        "databricks/webauth/container"   = { cidr = "10.42.11.16/28", number = 13 }
      }
    }
  }
  databricks_workspaces = {
    analytics = {}
    webauth = {
      sequence                         = "01"
      browser_authentication_workspace = true
    }
  }
  virtual_machines            = {}
  virtual_machine_scale_sets  = {}
  storage_accounts            = {}
  premium_file_accounts       = {}
  log_analytics_workspace     = {}
  key_vaults                  = {}
  container_registries        = {}
  azure_sql_servers           = {}
  container_apps_environments = {}
  load_balancers              = {}
  cosmos_db_accounts          = {}
  sql_managed_instances       = {}
  postgresql_servers          = {}
  mysql_servers               = {}
  function_apps               = {}
  web_apps                    = {}
  app_service_plans           = {}
  hub_peering                 = null
  tags                        = {}
}

run "private_workload_and_browser_authentication_workspace" {
  command = plan

  assert {
    condition = (
      contains(keys(local.service_private_endpoints), "databricks/analytics/databricks_ui_api") &&
      !contains(keys(local.service_private_endpoints), "databricks/webauth/databricks_ui_api")
    )
    error_message = "A private workload workspace gets a databricks_ui_api endpoint; the browser authentication workspace must not."
  }

  assert {
    condition     = keys(local.databricks_browser_authentication_private_endpoints) == ["databricks/webauth/browser_authentication"]
    error_message = "Only the dedicated browser authentication workspace gets the browser_authentication endpoint."
  }

  assert {
    condition = (
      local.private_endpoint_names["databricks/analytics/databricks_ui_api"].name == "M-AZU-DBR-IT-PPA-GEO-DEV-SWE-00-databricks_ui_api" &&
      local.private_endpoint_names["databricks/webauth/browser_authentication"].name == "M-AZU-DBR-IT-PPA-GEO-DEV-SWE-01-browser_authentication"
    )
    error_message = "Databricks endpoints must be named <workspace>-<subresource>."
  }

  assert {
    condition = (
      keys(azurerm_management_lock.databricks_browser_authentication) == ["webauth"] &&
      azurerm_management_lock.databricks_browser_authentication["webauth"].lock_level == "CanNotDelete"
    )
    error_message = "The browser authentication workspace gets a CanNotDelete lock by default."
  }

  assert {
    condition = alltrue([
      for key in ["databricks/analytics/host", "databricks/analytics/container", "databricks/webauth/host", "databricks/webauth/container"] :
      local.subnets.main[key].delegation.service == "Microsoft.Databricks/workspaces" &&
      local.subnets.main[key].default_outbound_access_enabled == false
    ])
    error_message = "Each workspace gets two private subnets delegated to Microsoft.Databricks/workspaces."
  }

  assert {
    condition = (
      local.resource_names.virtual_networks["main"].subnets["databricks/analytics/host"] == "PPAGEODEVPRV10" &&
      local.resource_names.virtual_networks["main"].subnets["databricks/webauth/container"] == "PPAGEODEVPRV13" &&
      local.resource_names.databricks_workspaces["webauth"].managed_resource_group_name == "M-AZU-RGP-IT-PPA-GEO-DEV-SWE-01" &&
      local.resource_names.databricks_workspaces["webauth"].network_security_group_name == "M-AZU-NSG-IT-PPA-GEO-PRV-DEV-SWE-01"
    )
    error_message = "Databricks subnets, managed resource group and NSG must follow the METLEN naming families."
  }

  assert {
    condition     = contains(local.private_dns_zones, "privatelink.azuredatabricks.net") && length(module.log_analytics) == 1
    error_message = "Databricks endpoints need the azuredatabricks.net zone, and diagnostics need the shared Log Analytics workspace."
  }
}

run "delete_lock_can_be_turned_off" {
  command = plan
  variables {
    databricks_workspaces = {
      webauth = {
        sequence                         = "01"
        browser_authentication_workspace = true
        delete_lock                      = false
      }
    }
  }

  assert {
    condition     = length(azurerm_management_lock.databricks_browser_authentication) == 0
    error_message = "delete_lock = false must create no lock."
  }
}

run "backend_private_and_public_workspaces" {
  command = plan
  variables {
    databricks_workspaces = {
      analytics = { network_access = "backend_private" }
      sandbox   = { sequence = "02", network_access = "public" }
    }
  }

  assert {
    condition = (
      contains(keys(local.service_private_endpoints), "databricks/analytics/databricks_ui_api") &&
      !contains(keys(local.service_private_endpoints), "databricks/sandbox/databricks_ui_api") &&
      length(local.databricks_browser_authentication_private_endpoints) == 0
    )
    error_message = "backend_private gets a databricks_ui_api endpoint, public none, and neither needs browser_authentication."
  }
}

run "warn_private_workspace_without_browser_authentication" {
  command = plan
  variables {
    databricks_workspaces = { analytics = {} }
  }
  expect_failures = [check.databricks_browser_authentication]
}

run "warn_workspace_without_egress" {
  command = plan
  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          "databricks/analytics/host" = { cidr = "10.42.9.0/26", number = 10 }
        })
      })
    }
  }
  expect_failures = [check.databricks_egress]
}

run "reject_two_browser_authentication_workspaces" {
  command = plan
  variables {
    databricks_workspaces = {
      analytics = { browser_authentication_workspace = true }
      webauth   = { sequence = "01", browser_authentication_workspace = true }
    }
  }
  expect_failures = [var.databricks_workspaces]
}

run "reject_browser_authentication_workspace_not_private" {
  command = plan
  variables {
    databricks_workspaces = {
      webauth = { browser_authentication_workspace = true, network_access = "backend_private" }
    }
  }
  expect_failures = [var.databricks_workspaces]
}

run "reject_storage_on_browser_authentication_workspace" {
  command = plan
  variables {
    storage_accounts = { lake = {} }
    databricks_workspaces = {
      webauth = {
        browser_authentication_workspace = true
        access_connector                 = { storage_accounts = ["lake"] }
      }
    }
  }
  expect_failures = [var.databricks_workspaces]
}
