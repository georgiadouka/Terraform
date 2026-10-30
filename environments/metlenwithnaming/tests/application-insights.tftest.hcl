# Shared Application Insights: naming, creation and opt-out, Log Analytics
# reuse, Monitoring Metrics Publisher assignments and the egress warning.

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
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-test"
    }
  }
  mock_resource "azurerm_linux_function_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-test"
      default_hostname = "func-linux.azurewebsites.net"
    }
  }
  mock_resource "azurerm_linux_web_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-linux"
      default_hostname = "app-linux.azurewebsites.net"
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
    }
  }
  mock_resource "azurerm_application_insights" {
    override_during = plan
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/components/appi-test"
      app_id            = "77777777-7777-7777-7777-777777777777"
      connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "azurerm_private_endpoint" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateEndpoints/pe-test"
    }
  }
}

override_module {
  target = module.network
  outputs = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    subnet_ids = {
      private_endpoints    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/endpoints"
      web_app_integration  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web-app"
      function_integration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
    }
  }
}

override_module {
  target  = module.nat_gateway["main"]
  outputs = { id = "mock-nat", public_ip_address = "203.0.113.10" }
}

override_module {
  target = module.private_dns
  outputs = {
    zone_ids = {
      for service in ["blob.core.windows.net", "file.core.windows.net", "queue.core.windows.net", "table.core.windows.net", "azurewebsites.net"] :
      "privatelink.${service}" => "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.${service}"
    }
  }
}

override_module {
  target = module.function_storage["primary"]
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfunctiontest"
    name               = "stfunctiontest"
    primary_access_key = "test-only-storage-key"
  }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  location                = "swedencentral"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
      subnet_cidrs = {
        private_endpoints    = "10.42.0.0/24"
        virtual_machines     = "10.42.1.0/24"
        web_app_integration  = "10.42.8.0/26"
        function_integration = "10.42.4.0/24"
        postgresql           = "10.42.5.0/24"
        mysql                = "10.42.6.0/24"
        sql_managed_instance = "10.42.7.0/27"
      }
    }
  }
  app_service_plans = {
    web       = { sequence = "00" }
    functions = { sequence = "01", sku_name = "EP1" }
  }
  function_apps = {
    primary = { service_plan = "functions", storage_sequence = "09" }
  }
  web_apps = {
    primary = { service_plan = "web" }
  }
  nat_gateways                = { main = { subnets = ["function_integration", "web_app_integration"] } }
  application_insights        = {}
  log_analytics_workspace     = {}
  virtual_machines            = {}
  virtual_machine_scale_sets  = {}
  storage_accounts            = {}
  premium_file_accounts       = {}
  storage_use_azuread         = true
  container_apps_environments = {}
  load_balancers              = {}
  key_vaults                  = {}
  container_registries        = {}
  azure_sql_servers           = {}
  cosmos_db_accounts          = {}
  sql_managed_instances       = {}
  postgresql_servers          = {}
  mysql_servers               = {}
  databricks_workspaces       = {}
  hub_peering                 = null
  tags                        = {}
}

run "shared_by_default" {
  command = plan

  assert {
    condition = (
      length(module.application_insights) == 1 &&
      length(module.log_analytics) == 1 &&
      output.generated_resource_names.application_insights == "M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00" &&
      output.application_insights.name == "M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00" &&
      toset(output.application_insights.apps) == toset(["function_app/primary", "web_app/primary"]) &&
      toset(keys(module.application_insights[0].role_assignment_ids)) == toset(["function_app/primary", "web_app/primary"]) &&
      output.function_apps["primary"].application_insights &&
      output.web_apps["primary"].application_insights
    )
    error_message = "Every app must send telemetry to one shared M-AZU-AIN resource stored in the shared Log Analytics workspace, with a Monitoring Metrics Publisher assignment per app."
  }
}

run "sequence_sets_nn" {
  command = plan

  variables {
    application_insights = { sequence = "03" }
  }

  assert {
    condition     = output.application_insights.name == "M-AZU-AIN-IT-PPA-ECM-DEV-SWE-03"
    error_message = "application_insights.sequence must set the NN."
  }
}

run "opt_out_per_app" {
  command = plan

  variables {
    web_apps = {
      primary = { service_plan = "web", application_insights = false }
    }
  }

  assert {
    condition = (
      toset(output.application_insights.apps) == toset(["function_app/primary"]) &&
      toset(keys(module.application_insights[0].role_assignment_ids)) == toset(["function_app/primary"]) &&
      output.function_apps["primary"].application_insights &&
      !output.web_apps["primary"].application_insights
    )
    error_message = "An app with application_insights = false must get neither telemetry settings nor a role assignment."
  }
}

run "no_resource_when_every_app_opts_out" {
  command = plan

  variables {
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09", application_insights = false }
    }
    web_apps = {
      primary = { service_plan = "web", application_insights = false }
    }
  }

  assert {
    condition = (
      length(module.application_insights) == 0 &&
      length(module.log_analytics) == 0 &&
      output.application_insights == null
    )
    error_message = "Without any app using it, neither Application Insights nor Log Analytics may be created."
  }
}

run "global_switch_turns_telemetry_off" {
  command = plan

  variables {
    application_insights = { enabled = false }
  }

  assert {
    condition = (
      length(module.application_insights) == 0 &&
      output.application_insights == null &&
      !output.function_apps["primary"].application_insights &&
      !output.web_apps["primary"].application_insights
    )
    error_message = "application_insights.enabled = false must turn telemetry off for every app."
  }
}

run "warn_without_egress" {
  command = plan

  variables {
    nat_gateways = { main = { subnets = ["function_integration"] } }
  }

  expect_failures = [check.application_insights_egress]
}

run "reject_invalid_sequence" {
  command = plan

  variables {
    application_insights = { sequence = "3" }
  }

  expect_failures = [var.application_insights]
}

run "log_analytics_quota_and_retention_are_configurable" {
  command = plan

  variables {
    log_analytics_workspace = { daily_quota_gb = -1, retention_in_days = 90 }
  }

  assert {
    condition     = length(module.log_analytics) == 1
    error_message = "A Log Analytics workspace without a cap and with 90 days retention must be accepted."
  }
}

run "reject_zero_log_analytics_quota" {
  command = plan

  variables {
    log_analytics_workspace = { daily_quota_gb = 0 }
  }

  expect_failures = [var.log_analytics_workspace]
}

run "reject_log_analytics_retention_out_of_range" {
  command = plan

  variables {
    log_analytics_workspace = { retention_in_days = 20 }
  }

  expect_failures = [var.log_analytics_workspace]
}
