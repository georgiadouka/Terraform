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

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  virtual_machines        = {}
  storage_accounts        = {}
  premium_file_accounts   = {}
  storage_use_azuread     = true
  location                = "swedencentral"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
    }
  }
  virtual_machine_scale_sets  = {}
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
  logic_apps                  = {}
  web_apps                    = {}
  app_service_plans           = {}
  hub_peering                 = null
  tags                        = {}
}

run "services_are_opt_in" {
  command = plan
  assert {
    condition = (
      length(module.virtual_machine) == 0 &&
      length(module.vm_backup) == 0 &&
      length(module.storage) == 0 &&
      length(module.premium_files) == 0 &&
      length(module.virtual_machine_scale_set) == 0 &&
      length(module.nat_gateway) == 0 &&
      length(module.key_vault) == 0 &&
      length(module.container_registry) == 0 &&
      length(module.azure_sql) == 0 &&
      length(module.sql_managed_instance) == 0 &&
      length(module.postgresql) == 0 &&
      length(module.mysql) == 0 &&
      length(module.container_apps) == 0 &&
      length(module.load_balancer) == 0 &&
      length(module.log_analytics) == 0 &&
      length(module.cosmos_db) == 0 &&
      length(module.web_app) == 0 &&
      length(module.app_service_plan) == 0 &&
      length(module.function_app) == 0 &&
      length(module.function_storage) == 0 &&
      length(module.spoke_to_hub_peering) == 0 &&
      length(module.hub_to_spoke_peering) == 0 &&
      length(local.subnets.main) == 0 &&
      length(local.private_dns_zones) == 0
    )
    error_message = "Every service must be opt-in: with no services and no subnets listed the lab deploys only the resource group and virtual network."
  }
}

run "tags_come_from_naming_tokens" {
  command = plan

  assert {
    condition = (
      { for name, value in local.common_tags : name => value if name != "Start Date" } == {
        Application = "ECM"
        BU          = "IT"
        Department  = "PPA"
        Environment = "DEV"
        Region      = "Sweden Central"
        ManagedBy   = "Terraform"
      } &&
      local.common_tags["Start Date"] == formatdate("DD/MM/YYYY", plantimestamp()) &&
      toset(keys(local.naming_dictionary.region_names)) == toset(keys(local.naming_dictionary.region_codes))
    )
    error_message = "The generated tags must carry the METLEN naming tokens, the region's display name and the date of the first apply, and every region code needs a display name."
  }
}

run "tags_replace_defaults_in_any_casing" {
  command = plan

  variables {
    tags = {
      environment         = "TEST"
      "start date"        = "01/01/2026"
      "Application Owner" = "platform-team"
    }
  }

  assert {
    condition = (
      local.common_tags == {
        Application         = "ECM"
        BU                  = "IT"
        Department          = "PPA"
        environment         = "TEST"
        Region              = "Sweden Central"
        ManagedBy           = "Terraform"
        "start date"        = "01/01/2026"
        "Application Owner" = "platform-team"
      }
    )
    error_message = "A tag in var.tags must replace the generated tag with the same name in any casing, so Azure never receives both environment and Environment."
  }
}

run "tags_reject_names_differing_only_in_casing" {
  command = plan

  variables {
    tags = {
      environment = "dev"
      Environment = "DEV"
    }
  }

  expect_failures = [var.tags]
}
