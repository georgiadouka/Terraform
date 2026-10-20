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
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  tenant_id             = "22222222-2222-2222-2222-222222222222"
  naming                = { unique_suffix = "test1" }
  services              = {}
  virtual_machines      = {}
  storage_accounts      = {}
  premium_file_accounts = {}
  storage_use_azuread   = true
  location              = "swedencentral"
  project_name          = "metlen"
  environment           = "lab"
  address_space         = ["10.42.0.0/20"]
  subnet_cidrs = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }
  virtual_machine_scale_sets  = {}
  nat_gateway                 = {}
  key_vaults                  = {}
  container_registries        = {}
  azure_sql_servers           = {}
  container_apps_environments = {}
  cosmos_db_accounts          = {}
  sql_managed_instance        = {}
  postgresql                  = {}
  mysql                       = {}
  function_app                = {}
  web_app                     = {}
  tags                        = {}
}

run "services_are_opt_in" {
  command = plan
  assert {
    condition = (
      length(module.virtual_machine) == 0 &&
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
      length(module.log_analytics) == 0 &&
      length(module.cosmos_db) == 0 &&
      length(module.web_app) == 0 &&
      length(module.function_app) == 0 &&
      length(local.subnets) == 0 &&
      length(local.private_dns_zones) == 0
    )
    error_message = "Every service must be opt-in: with no services enabled the lab deploys only the resource group and virtual network."
  }
}
