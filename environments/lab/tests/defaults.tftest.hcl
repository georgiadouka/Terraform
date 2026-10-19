mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}

# terraform test also loads a local terraform.tfvars, so every input that file
# may set is pinned here. services = {} still exercises each attribute default.
variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  tenant_id             = "22222222-2222-2222-2222-222222222222"
  naming                = { unique_suffix = "test1" }
  services              = {}
  virtual_machines      = {}
  storage_accounts      = {}
  premium_file_accounts = {}
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
      length(module.cosmos_db) == 0 &&
      length(module.web_app) == 0 &&
      length(module.function_app) == 0 &&
      length(local.subnets) == 0 &&
      length(local.private_dns_zones) == 0
    )
    error_message = "Every service must be opt-in: with no services enabled the lab deploys only the resource group and virtual network."
  }
}
