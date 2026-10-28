# Acceptance tests for the METLEN Azure Naming Standard v0.2 (§9).

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
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  tenant_id             = "22222222-2222-2222-2222-222222222222"
  naming                = { unique_suffix = "test1" }
  virtual_machines      = {}
  storage_accounts      = {}
  premium_file_accounts = {}
  storage_use_azuread   = true
  location              = "swedencentral"
  project_name          = "metlen"
  environment           = "lab"
  naming_tokens = {
    business_unit = "IT"
    department    = "PPA"
    application   = "ECM"
    environment   = "DEV"
  }
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
  virtual_machine_scale_sets  = {}
  nat_gateway                 = {}
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

# AT-01
run "resource_group_uses_rgp_code" {
  command = plan
  assert {
    condition     = output.generated_resource_names.resource_group == "M-AZU-RGP-IT-PPA-ECM-DEV-SWE"
    error_message = "The Resource Group name must follow M-AZU-RGP-<BU>-<DPT>-<APP>-<ENV>-<REG>."
  }
}

# AT-02
run "names_are_deterministic" {
  command = plan
  assert {
    condition     = output.generated_resource_names.resource_group == run.resource_group_uses_rgp_code.generated_resource_names.resource_group
    error_message = "The same inputs must always produce the same names."
  }
}

# AT-03
run "environment_changes_the_name" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "IT"
      department    = "PPA"
      application   = "ECM"
      environment   = "PRD"
    }
  }
  assert {
    condition     = output.generated_resource_names.resource_group == "M-AZU-RGP-IT-PPA-ECM-PRD-SWE"
    error_message = "DEV, UAT and PRD must produce distinct names."
  }
}

run "region_code_is_derived_from_location" {
  command = plan
  variables {
    location = "West Europe"
  }
  assert {
    condition     = output.generated_resource_names.resource_group == "M-AZU-RGP-IT-PPA-ECM-DEV-WEU"
    error_message = "The region code must come from the Azure location through the naming dictionary."
  }
}

# AT-11
run "subscription_display_name" {
  command = plan
  assert {
    condition     = output.generated_resource_names.subscription_display_name == "M-AZU-SBS-IT-PPA"
    error_message = "The subscription display name must follow M-AZU-SBS-<BU>-<DPT>."
  }
}

# AT-07
run "reject_unknown_department" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "IT"
      department    = "XYZ"
      application   = "ECM"
      environment   = "DEV"
    }
  }
  expect_failures = [var.naming_tokens]
}

run "reject_unknown_application" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "IT"
      department    = "PPA"
      application   = "XYZ"
      environment   = "DEV"
    }
  }
  expect_failures = [var.naming_tokens]
}

run "reject_unknown_business_unit" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "XX"
      department    = "PPA"
      application   = "ECM"
      environment   = "DEV"
    }
  }
  expect_failures = [var.naming_tokens]
}

run "reject_environment_outside_dev_uat_prd" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "IT"
      department    = "PPA"
      application   = "ECM"
      environment   = "TST"
    }
  }
  expect_failures = [var.naming_tokens]
}

run "reject_lowercase_token" {
  command = plan
  variables {
    naming_tokens = {
      business_unit = "IT"
      department    = "PPA"
      application   = "ECM"
      environment   = "dev"
    }
  }
  expect_failures = [var.naming_tokens]
}

run "reject_location_without_region_code" {
  command = plan
  variables {
    location = "eastus"
  }
  expect_failures = [var.location]
}

# Network family (step 2)
run "virtual_network_uses_network_family" {
  command = plan
  assert {
    condition     = output.generated_resource_names.virtual_network == "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE"
    error_message = "The VNet name must follow M-AZU-VNT-<BU>-<DPT>-<APP>-PRV-<ENV>-<REG>."
  }
}

run "single_nsg_matches_standard_example" {
  command = plan
  variables {
    network_security_groups = { compute = {} }
    route_tables            = { compute = {} }
  }
  assert {
    condition = (
      output.generated_resource_names.network_security_groups["compute"] == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE" &&
      output.generated_resource_names.route_tables["compute"] == "M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE"
    )
    error_message = "A single NSG or route table without a sequence must match the standard's example exactly."
  }
}

run "multiple_nsgs_and_route_tables_use_sequence_and_classification" {
  command = plan
  variables {
    network_security_groups = {
      compute   = { sequence = "01" }
      endpoints = { sequence = "02" }
      edge      = { classification = "PUB" }
    }
    route_tables = {
      compute = { sequence = "01" }
      edge    = { classification = "PUB", sequence = "01" }
    }
  }
  assert {
    condition = (
      output.generated_resource_names.network_security_groups == {
        compute   = "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE-01"
        endpoints = "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE-02"
        edge      = "M-AZU-NSG-IT-PPA-ECM-PUB-DEV-SWE"
      } &&
      output.generated_resource_names.route_tables == {
        compute = "M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE-01"
        edge    = "M-AZU-UDR-IT-PPA-ECM-PUB-DEV-SWE-01"
      }
    )
    error_message = "NSG and route table names must carry their classification and optional NN."
  }
}

run "sql_managed_instance_network_names_use_sequence" {
  command = plan
  variables {
    sql_managed_instances = { primary = { network_sequence = "03" } }
  }
  assert {
    condition = (
      keys(module.sql_managed_instance) == ["primary"] &&
      local.subnet_enabled.sql_managed_instance &&
      contains(keys(local.subnets), "sql_managed_instance") &&
      local.resource_names.sql_managed_instances["primary"].name == "m-azu-smi-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.sql_managed_instances["primary"].network_security_group_name == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE-03" &&
      local.resource_names.sql_managed_instances["primary"].route_table_name == "M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE-03"
    )
    error_message = "A sql_managed_instances entry must create the instance and its subnet, and its NSG and route table must use the network family with its network_sequence."
  }
}

run "sql_managed_instances_default_to_none" {
  command = plan
  assert {
    condition = (
      length(module.sql_managed_instance) == 0 &&
      !local.subnet_enabled.sql_managed_instance &&
      length(local.resource_names.sql_managed_instances) == 0 &&
      length(output.sql_managed_instances) == 0
    )
    error_message = "sql_managed_instances = {} must create no instance and no subnet, like every other map."
  }
}

run "sql_managed_instance_with_defaults" {
  command = plan
  variables {
    sql_managed_instances = { primary = {} }
  }
  assert {
    condition = (
      length(module.sql_managed_instance) == 1 &&
      local.resource_names.sql_managed_instances["primary"].network_security_group_name == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE" &&
      local.resource_names.sql_managed_instances["primary"].route_table_name == "M-AZU-UDR-IT-PPA-ECM-PRV-DEV-SWE"
    )
    error_message = "An empty sql_managed_instances entry must create the instance with every default."
  }
}

run "reject_more_than_one_sql_managed_instance" {
  command = plan
  variables {
    sql_managed_instances = {
      primary   = {}
      reporting = { network_sequence = "02" }
    }
  }
  expect_failures = [var.sql_managed_instances]
}

run "reject_invalid_sql_managed_instance_key" {
  command = plan
  variables {
    sql_managed_instances = { "Bad_Key" = {} }
  }
  expect_failures = [var.sql_managed_instances]
}

run "reject_invalid_sql_managed_instance_network_sequence" {
  command = plan
  variables {
    sql_managed_instances = { primary = { network_sequence = "3" } }
  }
  expect_failures = [var.sql_managed_instances]
}

run "sql_managed_instance_uses_smi_family" {
  command = plan
  variables {
    sql_managed_instances = { primary = { sequence = "01" } }
  }
  assert {
    condition = (
      local.resource_names.sql_managed_instances["primary"].name == "m-azu-smi-it-ppa-ecm-dev-swe-01" &&
      can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", local.resource_names.sql_managed_instances["primary"].name))
    )
    error_message = "The SQL Managed Instance name must follow the lowercase m-azu-smi family with its NN and meet Azure's 1-63 lowercase character rule."
  }
}

run "reject_invalid_sql_managed_instance_sequence" {
  command = plan
  variables {
    sql_managed_instances = { primary = { sequence = "A1" } }
  }
  expect_failures = [var.sql_managed_instances]
}

run "reject_duplicate_nsg_names" {
  command = plan
  variables {
    network_security_groups = {
      compute   = {}
      endpoints = {}
    }
  }
  expect_failures = [var.network_security_groups]
}

run "reject_duplicate_route_table_names" {
  command = plan
  variables {
    route_tables = {
      compute   = { sequence = "01" }
      endpoints = { sequence = "01" }
    }
  }
  expect_failures = [var.route_tables]
}

run "reject_nsg_clashing_with_sql_managed_instance" {
  command = plan
  variables {
    sql_managed_instances   = { primary = {} }
    network_security_groups = { compute = {} }
  }
  expect_failures = [var.network_security_groups]
}

run "reject_invalid_classification" {
  command = plan
  variables {
    network_security_groups = { compute = { classification = "PUBLIC" } }
  }
  expect_failures = [var.network_security_groups]
}

run "reject_invalid_sequence" {
  command = plan
  variables {
    route_tables = { compute = { sequence = "1" } }
  }
  expect_failures = [var.route_tables]
}

run "reject_container_apps_subnet_number_in_use" {
  command = plan
  variables {
    virtual_machines            = { primary = {} }
    subnet_cidrs                = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = { primary = { subnet_number = 2 } }
  }
  expect_failures = [var.container_apps_environments]
}

# Naming register example: PPAECMDEVPRV01 (two-digit number).
run "subnet_names_match_register_example" {
  command = plan
  variables {
    subnet_cidrs                = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = { primary = { subnet_number = 42 } }
  }
  assert {
    condition = (
      output.generated_resource_names.subnets["private_endpoints"] == "PPAECMDEVPRV01" &&
      output.generated_resource_names.subnets["load_balancers"] == "PPAECMDEVPRV08" &&
      output.generated_resource_names.container_apps_environments["primary"].subnet_name == "PPAECMDEVPRV42"
    )
    error_message = "Subnet names must follow <DPT><APP><ENV>PRV<NN> with a two-digit number, as in the register example PPAECMDEVPRV01."
  }
}

run "reject_subnet_number_above_99" {
  command = plan
  variables {
    subnet_cidrs                = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = { primary = { subnet_number = 100 } }
  }
  expect_failures = [var.container_apps_environments]
}

# Compact and global names (step 3)
# AT-06
run "storage_account_matches_standard_example" {
  command = plan
  variables {
    storage_accounts = { primary = {} }
  }
  assert {
    condition = (
      output.generated_resource_names.storage_accounts["primary"] == "mazusoaitppaecmdevswe00" &&
      length(output.generated_resource_names.storage_accounts["primary"]) == 23
    )
    error_message = "The Storage Account name must match the standard's example mazusoaitppaecmdevswe00 (23 characters)."
  }
}

# AT-04: the full readable Key Vault pattern (31 characters) is never generated;
# the compact family keeps the KVA code and fits 24 characters.
run "key_vault_uses_compact_family" {
  command = plan
  variables {
    key_vaults = {
      primary = {}
      secrets = { sequence = "01" }
    }
  }
  assert {
    condition = (
      output.generated_resource_names.key_vaults == {
        primary = "mazukvaitppaecmdevswe00"
        secrets = "mazukvaitppaecmdevswe01"
      } &&
      alltrue([for name in values(output.generated_resource_names.key_vaults) : can(regex("^[a-z0-9]{3,24}$", name))])
    )
    error_message = "Key Vault names must use the compact mazukva family within Azure's 3-24 lowercase alphanumeric limit."
  }
}

run "sql_server_is_lowercase_and_database_uses_full_family" {
  command = plan
  variables {
    azure_sql_servers = { primary = {} }
  }
  assert {
    condition = (
      output.generated_resource_names.azure_sql_servers["primary"].server_name == "m-azu-sql-it-ppa-ecm-dev-swe-00" &&
      output.generated_resource_names.azure_sql_servers["primary"].database_name == "M-AZU-SQL-IT-PPA-ECM-DEV-SWE-00" &&
      can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", output.generated_resource_names.azure_sql_servers["primary"].server_name))
    )
    error_message = "The SQL logical server must use the lowercase variant and the database the full family."
  }
}

run "premium_files_and_function_storage_share_the_storage_family" {
  command = plan
  variables {
    storage_accounts      = { primary = {} }
    premium_file_accounts = { media = { sequence = "01" } }
    app_service_plans     = { functions = { sequence = "01", sku_name = "EP1" } }
    function_apps         = { primary = { service_plan = "functions", storage_sequence = "02" } }
  }
  assert {
    condition = (
      output.generated_resource_names.premium_file_accounts["media"] == "mazusoaitppaecmdevswe01" &&
      output.generated_resource_names.function_apps["primary"].storage_account_name == "mazusoaitppaecmdevswe02"
    )
    error_message = "Premium Files and Function host storage must use the Storage Account family with their own NN."
  }
}

run "private_endpoint_uses_parent_name_and_service" {
  command = plan
  variables {
    storage_accounts = { primary = {} }
    key_vaults       = { primary = {} }
  }
  assert {
    condition = (
      output.generated_resource_names.private_endpoints["storage/primary/blob"].name == "mazusoaitppaecmdevswe00-blob" &&
      output.generated_resource_names.private_endpoints["key_vault/primary"].name == "mazukvaitppaecmdevswe00-vault"
    )
    error_message = "Private Endpoint names must follow <PARENTNAME>-<SERVICE>, as in the standard's example mazusoaitppaecmdevswe00-blob."
  }
}

run "reject_duplicate_storage_sequence" {
  command = plan
  variables {
    storage_accounts      = { primary = {} }
    premium_file_accounts = { media = {} }
  }
  expect_failures = [var.storage_accounts]
}

run "reject_storage_sequence_clashing_with_function_storage" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", sku_name = "EP1" } }
    function_apps     = { primary = { service_plan = "functions" } }
    storage_accounts  = { primary = {} }
  }
  expect_failures = [var.storage_accounts]
}

run "reject_duplicate_key_vault_sequence" {
  command = plan
  variables {
    key_vaults = {
      primary = {}
      secrets = {}
    }
  }
  expect_failures = [var.key_vaults]
}

run "reject_invalid_storage_sequence" {
  command = plan
  variables {
    storage_accounts = { primary = { sequence = "A1" } }
  }
  expect_failures = [var.storage_accounts]
}

# App platform (step 4)
run "app_service_family_names" {
  command = plan
  variables {
    app_service_plans = {
      web       = { sequence = "00" }
      functions = { sequence = "01", sku_name = "EP1" }
    }
    web_apps      = { primary = { service_plan = "web", sequence = "00" } }
    function_apps = { primary = { service_plan = "functions", storage_sequence = "01" } }
  }
  assert {
    condition = (
      output.generated_resource_names.app_service_plans == {
        web       = "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00"
        functions = "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-01"
      } &&
      output.generated_resource_names.web_apps["primary"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-00" &&
      output.generated_resource_names.function_apps["primary"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE" &&
      output.generated_resource_names.function_apps["primary"].storage_account_name == "mazusoaitppaecmdevswe01" &&
      output.generated_resource_names.private_endpoints["web_app/primary"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-00-sites" &&
      output.generated_resource_names.private_endpoints["function_app/primary"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE-sites"
    )
    error_message = "App Service, App Service Plan and Function App names must follow the APP, ASP and FUN families."
  }
}

# The Functions host ID is the first 32 characters of the lowercase app name.
run "function_app_name_fits_host_id" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", sku_name = "EP1" } }
    function_apps     = { primary = { service_plan = "functions" } }
  }
  assert {
    condition = (
      length(output.generated_resource_names.function_apps["primary"].name) <= 32 &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,58}[A-Za-z0-9]$", output.generated_resource_names.function_apps["primary"].name))
    )
    error_message = "The Function App name must stay within 32 characters so its host ID is not truncated."
  }
}

run "function_app_optional_sequence_fits_host_id" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", sku_name = "EP1" } }
    function_apps     = { primary = { service_plan = "functions", sequence = "01" } }
  }
  assert {
    condition = (
      output.generated_resource_names.function_apps["primary"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE-01" &&
      length(output.generated_resource_names.function_apps["primary"].name) <= 32
    )
    error_message = "The optional Function App sequence must append -NN and keep the name within the 32-character host ID."
  }
}

run "reject_shared_app_service_plan_name" {
  command = plan
  variables {
    app_service_plans = {
      web       = { sequence = "00" }
      functions = { sequence = "00", sku_name = "EP1" }
    }
    web_apps      = { primary = { service_plan = "web" } }
    function_apps = { primary = { service_plan = "functions", storage_sequence = "01" } }
  }
  expect_failures = [var.app_service_plans]
}

run "container_apps_family_names" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      primary = { apps = { hello = {}, api = { sequence = "01" } } }
    }
  }
  assert {
    condition = (
      output.generated_resource_names.container_apps_environments["primary"].name == "M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00" &&
      output.generated_resource_names.container_apps_environments["primary"].apps == {
        hello = "m-azu-cap-it-ppa-ecm-dev-swe-00"
        api   = "m-azu-cap-it-ppa-ecm-dev-swe-01"
      }
    )
    error_message = "Container Apps environments must use the CEV family and apps the lowercase CAP variant from the standard."
  }
}

run "load_balancer_family_names" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/26" })
    load_balancers = {
      web  = {}
      data = { sequence = "01" }
    }
  }
  assert {
    condition = (
      output.generated_resource_names.load_balancers["web"].name == "M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00" &&
      output.generated_resource_names.load_balancers["data"].name == "M-AZU-LBL-IT-PPA-ECM-DEV-SWE-01"
    )
    error_message = "Load balancer names must follow M-AZU-LBL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>."
  }
}

run "reject_duplicate_load_balancer_sequence" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/26" })
    load_balancers = {
      web  = {}
      data = {}
    }
  }
  expect_failures = [var.load_balancers]
}

run "nat_gateway_and_public_ip_share_the_nn" {
  command = plan
  variables {
    virtual_machine_scale_sets = { app = {} }
  }
  assert {
    condition = (
      length(module.nat_gateway) == 1 &&
      local.resource_names.nat_gateway == "M-AZU-NGW-IT-PPA-ECM-DEV-SWE-00" &&
      local.resource_names.nat_public_ip == "M-AZU-PIP-IT-PPA-ECM-DEV-SWE-00"
    )
    error_message = "The NAT Gateway must follow M-AZU-NGW-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN> and its Public IP M-AZU-PIP-...-<NN> with the same NN, 00 by default."
  }
}

run "nat_gateway_sequence_sets_both_names" {
  command = plan
  variables {
    nat_gateway = { sequence = "01" }
  }
  assert {
    condition = (
      local.resource_names.nat_gateway == "M-AZU-NGW-IT-PPA-ECM-DEV-SWE-01" &&
      local.resource_names.nat_public_ip == "M-AZU-PIP-IT-PPA-ECM-DEV-SWE-01"
    )
    error_message = "nat_gateway.sequence must set the NN of both the NAT Gateway and its Public IP."
  }
}

run "reject_invalid_nat_gateway_sequence" {
  command = plan
  variables {
    nat_gateway = { sequence = "1" }
  }
  expect_failures = [var.nat_gateway]
}
