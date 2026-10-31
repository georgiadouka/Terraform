# Logic Apps (Standard): names, Workflow Standard plans, host storage, Private
# Endpoints, the integration subnet, shared Application Insights and the
# input validations.

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
  mock_resource "azurerm_logic_app_standard" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/logic-test"
      default_hostname = "logic-test.azurewebsites.net"
    }
  }
  mock_resource "azurerm_linux_function_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-test"
      default_hostname = "func-test.azurewebsites.net"
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
      private_endpoints     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/endpoints"
      logic_app_integration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/logic"
      function_integration  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
      web_app_integration   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web"
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
  target = module.logic_app_storage
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stlogictest"
    name               = "stlogictest"
    primary_access_key = "test-only-storage-key"
  }
}

override_module {
  target = module.function_storage
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
      subnets = {
        private_endpoints     = { cidr = "10.42.0.0/24", number = 1 }
        web_app_integration   = { cidr = "10.42.8.0/26", number = 3, nat_gateway = true }
        function_integration  = { cidr = "10.42.4.0/24", number = 4, nat_gateway = true }
        logic_app_integration = { cidr = "10.42.9.0/26", number = 12, nat_gateway = true }
      }
    }
  }
  app_service_plans = {
    workflows = { sequence = "02", os_type = "Windows", sku_name = "WS1" }
  }
  logic_apps = {
    primary = { service_plan = "workflows", storage_sequence = "10" }
  }
  function_apps               = {}
  web_apps                    = {}
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

run "names_plan_and_storage" {
  command = plan

  assert {
    condition = (
      output.generated_resource_names.logic_apps["primary"].name == "M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00" &&
      output.generated_resource_names.logic_apps["primary"].storage_account_name == "mazusoaitppaecmdevswe10" &&
      output.generated_resource_names.logic_apps["primary"].content_share_name == "logic-app-content" &&
      output.generated_resource_names.app_service_plans["workflows"] == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-02"
    )
    error_message = "Logic Apps must be named M-AZU-LAP-...-<sequence>, with host storage in the mazusoa...<storage_sequence> family and the fixed logic-app-content share."
  }

  assert {
    condition = (
      output.app_service_plans["workflows"].sku_name == "WS1" &&
      output.app_service_plans["workflows"].os_type == "Windows" &&
      toset(output.app_service_plans["workflows"].logic_apps) == toset(["primary"]) &&
      length(output.app_service_plans["workflows"].function_apps) == 0 &&
      length(output.app_service_plans["workflows"].web_apps) == 0 &&
      output.logic_apps["primary"].name == "M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00" &&
      output.logic_apps["primary"].service_plan == "workflows" &&
      output.logic_apps["primary"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-02" &&
      output.logic_apps["primary"].storage_account_name == "stlogictest"
    )
    error_message = "The Logic App must run on the shared Windows WS1 plan from app_service_plans and report its plan and storage."
  }

  assert {
    condition = (
      local.subnets.main["logic_app_integration"].delegation.service == "Microsoft.Web/serverFarms" &&
      toset(local.subnets.main["logic_app_integration"].delegation.actions) == toset(["Microsoft.Network/virtualNetworks/subnets/action"]) &&
      local.subnets.main["logic_app_integration"].delegation.name == "dlg-logic-app-integration-metlen-lab-test1" &&
      output.generated_resource_names.virtual_networks["main"].subnets["logic_app_integration"] == "PPAECMDEVPRV12"
    )
    error_message = "The logic_app_integration subnet must be delegated to Microsoft.Web/serverFarms and named with its number."
  }
}

run "private_endpoints" {
  command = plan

  assert {
    condition = (
      local.private_endpoint_catalog["logic_app/primary"].deployed_by == "logic_app_private_endpoint" &&
      local.private_endpoint_catalog["logic_app/primary"].subresource == "sites" &&
      local.private_endpoint_catalog["logic_app/primary"].dns_zone == "privatelink.azurewebsites.net" &&
      local.private_endpoint_names["logic_app/primary"].name == "M-AZU-LAP-IT-PPA-ECM-DEV-SWE-00-sites" &&
      length(module.logic_app_private_endpoint) == 1 &&
      !contains(keys(local.service_private_endpoints), "logic_app/primary")
    )
    error_message = "Each Logic App needs one sites Private Endpoint in privatelink.azurewebsites.net, created by its own call."
  }

  assert {
    condition = (
      toset(keys(local.logic_app_storage_private_endpoints["primary"])) == toset([
        "logic_app_storage/primary/blob", "logic_app_storage/primary/file",
        "logic_app_storage/primary/queue", "logic_app_storage/primary/table"
      ]) &&
      local.private_endpoint_names["logic_app_storage/primary/queue"].name == "mazusoaitppaecmdevswe10-queue" &&
      local.private_endpoint_catalog["logic_app_storage/primary/table"].dns_zone == "privatelink.table.core.windows.net" &&
      toset(keys(output.private_endpoint_ids.logic_app_storage["primary"])) == toset(["blob", "file", "queue", "table"])
    )
    error_message = "Logic App host storage needs blob, file, queue and table Private Endpoints named <storage name>-<subresource>."
  }

  assert {
    condition = alltrue([
      for zone in ["privatelink.azurewebsites.net", "privatelink.blob.core.windows.net", "privatelink.file.core.windows.net", "privatelink.queue.core.windows.net", "privatelink.table.core.windows.net"] :
      contains(local.private_dns_zones, zone)
    ])
    error_message = "Logic Apps must add the sites and storage Private DNS zones."
  }
}

run "application_insights" {
  command = plan

  assert {
    condition = (
      length(module.application_insights) == 1 &&
      toset(output.application_insights.apps) == toset(["logic_app/primary"]) &&
      toset(keys(module.application_insights[0].role_assignment_ids)) == toset(["logic_app/primary"]) &&
      output.logic_apps["primary"].application_insights
    )
    error_message = "A Logic App must send telemetry to the shared Application Insights resource with its own Monitoring Metrics Publisher assignment."
  }
}

run "application_insights_opt_out" {
  command = plan

  variables {
    logic_apps = {
      primary = { service_plan = "workflows", storage_sequence = "10", application_insights = false }
    }
  }

  assert {
    condition = (
      length(module.application_insights) == 0 &&
      !output.logic_apps["primary"].application_insights
    )
    error_message = "application_insights = false must leave the Logic App without telemetry."
  }
}

run "warn_without_egress" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          logic_app_integration = { cidr = "10.42.9.0/26", number = 12 }
        })
      })
    }
  }

  expect_failures = [check.application_insights_egress]
}

run "apps_share_a_plan" {
  command = plan

  variables {
    logic_apps = {
      primary = { service_plan = "workflows", storage_sequence = "10" }
      orders  = { service_plan = "workflows", sequence = "01", storage_sequence = "11", node_version = "24", app_settings = { ORDERS_QUEUE = "orders" } }
    }
  }

  assert {
    condition = (
      toset(output.app_service_plans["workflows"].logic_apps) == toset(["orders", "primary"]) &&
      output.generated_resource_names.logic_apps["orders"].name == "M-AZU-LAP-IT-PPA-ECM-DEV-SWE-01" &&
      output.generated_resource_names.logic_apps["orders"].storage_account_name == "mazusoaitppaecmdevswe11" &&
      length(module.logic_app_storage) == 2 &&
      length(module.logic_app_storage_private_endpoints) == 2
    )
    error_message = "Several Logic Apps can share one Workflow Standard plan, each with its own name and host storage."
  }
}

run "no_unused_plan_warning" {
  command = plan

  assert {
    condition     = length(local.unused_app_service_plans) == 0
    error_message = "A Workflow Standard plan used by a Logic App must not count as unused."
  }
}

run "reject_elastic_premium_plan" {
  command = plan

  variables {
    app_service_plans = {
      workflows = { sequence = "02", os_type = "Windows", sku_name = "EP1" }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_linux_workflow_standard_plan" {
  command = plan

  variables {
    app_service_plans = {
      workflows = { sequence = "02", os_type = "Linux", sku_name = "WS1" }
    }
  }

  expect_failures = [var.app_service_plans]
}

run "reject_web_app_on_workflow_standard_plan" {
  command = plan

  variables {
    web_apps = {
      primary = { service_plan = "workflows", mode = "windows" }
    }
  }

  expect_failures = [var.web_apps]
}

run "reject_function_app_on_workflow_standard_plan" {
  command = plan

  variables {
    function_apps = {
      primary = { service_plan = "workflows", storage_sequence = "09" }
    }
  }

  expect_failures = [var.function_apps]
}

run "reject_unknown_plan" {
  command = plan

  variables {
    logic_apps = {
      primary = { service_plan = "missing", storage_sequence = "10" }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_missing_integration_subnet" {
  command = plan

  variables {
    virtual_networks = {
      main = {
        address_space = ["10.42.0.0/20"]
        subnets = {
          private_endpoints = { cidr = "10.42.0.0/24", number = 1 }
        }
      }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_duplicate_sequence" {
  command = plan

  variables {
    logic_apps = {
      primary = { service_plan = "workflows", storage_sequence = "10" }
      orders  = { service_plan = "workflows", storage_sequence = "11" }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_invalid_sequence" {
  command = plan

  variables {
    logic_apps = {
      primary = { service_plan = "workflows", sequence = "1", storage_sequence = "10" }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_invalid_key" {
  command = plan

  variables {
    logic_apps = {
      Primary = { service_plan = "workflows", storage_sequence = "10" }
    }
  }

  expect_failures = [var.logic_apps]
}

run "reject_storage_sequence_shared_with_storage_account" {
  command = plan

  variables {
    storage_accounts = {
      data = { sequence = "10" }
    }
  }

  expect_failures = [var.storage_accounts]
}

run "reject_storage_sequence_shared_with_function_app" {
  command = plan

  variables {
    app_service_plans = {
      workflows = { sequence = "02", os_type = "Windows", sku_name = "WS1" }
      functions = { sequence = "01", sku_name = "EP1" }
    }
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "10" }
    }
  }

  expect_failures = [var.storage_accounts]
}

run "reject_plan_split_across_networks" {
  command = plan

  variables {
    virtual_networks = {
      main = var.virtual_networks.main
      edge = {
        classification = "PUB"
        address_space  = ["10.43.0.0/20"]
        subnets = {
          private_endpoints     = { cidr = "10.43.0.0/24", number = 1 }
          logic_app_integration = { cidr = "10.43.9.0/26", number = 12, nat_gateway = true }
        }
      }
    }
    logic_apps = {
      primary = { service_plan = "workflows", storage_sequence = "10" }
      edge    = { service_plan = "workflows", sequence = "01", storage_sequence = "11", virtual_network = "edge" }
    }
  }

  expect_failures = [var.logic_apps]
}
