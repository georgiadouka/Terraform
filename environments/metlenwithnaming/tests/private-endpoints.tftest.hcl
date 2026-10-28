# Locks in Private Endpoint wiring: which endpoints exist, what each targets,
# its subresource and DNS zone, and the generated names. Targets use distinct
# realistic IDs so miswiring is detectable.

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
      private_endpoints        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/pe"
      virtual_machines         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vm"
      "container_apps/primary" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/aca"
      web_app_integration      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web"
      function_integration     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/func"
    }
  }
}

override_module {
  target = module.private_dns
  outputs = {
    zone_ids = {
      for zone in [
        "privatelink.vaultcore.azure.net", "privatelink.azurecr.io", "privatelink.blob.core.windows.net",
        "privatelink.file.core.windows.net", "privatelink.queue.core.windows.net", "privatelink.table.core.windows.net",
        "privatelink.database.windows.net", "privatelink.azurewebsites.net", "privatelink.documents.azure.com",
        "privatelink.mongo.cosmos.azure.com"
      ] : zone => "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/${zone}"
    }
  }
}

override_module {
  target  = module.key_vault["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kvprimary", name = "kvprimary", vault_uri = "https://kvprimary.vault.azure.net/" }
}
override_module {
  target  = module.key_vault["secrets"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kvsecrets", name = "kvsecrets", vault_uri = "https://kvsecrets.vault.azure.net/" }
}
override_module {
  target  = module.container_registry["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/acr", name = "acr", login_server = "acr.azurecr.io", sku = "Premium" }
}
override_module {
  target  = module.storage["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stprimary", name = "stprimary", shared_access_key_enabled = false, primary_access_key = null, primary_connection_string = null, data_plane_role_assignment_ids = {}, container_ids = {}, file_share_ids = {} }
}
override_module {
  target  = module.storage["archive"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/starchive", name = "starchive", shared_access_key_enabled = false, primary_access_key = null, primary_connection_string = null, data_plane_role_assignment_ids = {}, container_ids = {}, file_share_ids = {} }
}
override_module {
  target  = module.premium_files["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/pfprimary", name = "pfprimary", file_share_ids = {} }
}
override_module {
  target  = module.premium_files["media"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/pfmedia", name = "pfmedia", file_share_ids = {} }
}
override_module {
  target  = module.azure_sql["primary"]
  outputs = { server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Sql/servers/sql", database_id = "db", elastic_pool_id = null, elastic_pool_name = null, fully_qualified_domain_name = "sql.database.windows.net" }
}
override_module {
  target  = module.cosmos_db["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DocumentDB/databaseAccounts/cosmos", name = "cosmos", endpoint = "https://cosmos", hostname = "cosmos.documents.azure.com", api_type = "NoSQL", database_id = "db", container_id = "ct", principal_id = null }
}
override_module {
  target  = module.web_app["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/web", default_hostname = "web.azurewebsites.net", principal_id = "p", mode = "linux", service_plan_id = "sp" }
}
override_module {
  target  = module.function_app["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func", default_hostname = "func.azurewebsites.net", principal_id = "p", os_type = "Linux" }
}
override_module {
  target  = module.function_storage["primary"]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfn", name = "stfn", shared_access_key_enabled = true, primary_access_key = "k", primary_connection_string = "c", data_plane_role_assignment_ids = {}, container_ids = {}, file_share_ids = {} }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  naming                  = { unique_suffix = "test1" }
  virtual_machines        = {}
  storage_accounts = {
    primary = {}
    archive = { sequence = "01" }
  }
  premium_file_accounts = {
    primary = { sequence = "02" }
    media   = { sequence = "03" }
  }
  key_vaults = {
    primary = {}
    secrets = { sequence = "01" }
  }
  container_registries = {
    primary = {}
  }
  container_apps_environments = {}
  load_balancers              = {}
  web_apps = {
    primary = { service_plan = "web" }
  }
  app_service_plans = {
    web       = { sequence = "00" }
    functions = { sequence = "01", sku_name = "EP1" }
  }
  function_apps = {
    primary = { service_plan = "functions", storage_sequence = "04" }
  }
  cosmos_db_accounts = {
    primary = {}
  }
  azure_sql_servers = {
    primary = {}
  }
  storage_use_azuread = true
  location            = "swedencentral"
  address_space       = ["10.42.0.0/20"]
  subnet_cidrs = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }
  virtual_machine_scale_sets = {}
  nat_gateway                = {}
  log_analytics_workspace    = {}
  sql_managed_instances      = {}
  postgresql_servers         = {}
  mysql_servers              = {}
  tags                       = {}
}

run "all_endpoints" {
  command = plan

  assert {
    condition = keys(local.service_private_endpoints) == [
      "azure_sql/primary", "container_registry/primary", "cosmos_db/primary", "key_vault/primary", "key_vault/secrets",
      "premium_files/media/file", "premium_files/primary/file",
      "web_app/primary"
    ]
    error_message = "Every enabled single-endpoint service and map entry must produce exactly its Private Endpoints."
  }

  assert {
    condition = (
      keys(local.storage_private_endpoints) == ["archive", "primary"] &&
      keys(local.storage_private_endpoints["archive"]) == ["storage/archive/blob", "storage/archive/file"] &&
      keys(module.storage_private_endpoints) == ["archive", "primary"]
    )
    error_message = "Storage account endpoints must be grouped per account so each account's endpoints are created in order."
  }

  assert {
    condition = (
      length(module.function_storage_private_endpoints) == 1 &&
      keys(local.function_storage_private_endpoints["primary"]) == [
        "function_storage/primary/blob", "function_storage/primary/file", "function_storage/primary/queue", "function_storage/primary/table"
      ]
    )
    error_message = "Function host storage endpoints must stay in their own group per Function App so each app can depend on them."
  }

  assert {
    condition = (
      length(module.function_app_private_endpoint) == 1 &&
      !contains(keys(local.private_endpoint_target_ids), "function_app/primary")
    )
    error_message = "The Function App endpoints must have their own call so other endpoints never wait for the Function Apps."
  }

  assert {
    condition = alltrue([
      for endpoint in values(local.service_private_endpoints) :
      contains(keys(local.private_endpoint_target_ids), endpoint.target)
    ])
    error_message = "Every enabled Private Endpoint must resolve to a target resource ID."
  }

  assert {
    condition = (
      local.private_endpoint_target_ids["premium_files/media"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/pfmedia" &&
      local.private_endpoint_target_ids["container_registry/primary"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/acr" &&
      local.service_private_endpoints["container_registry/primary"].subresource == "registry" &&
      local.private_endpoint_target_ids["key_vault/secrets"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kvsecrets" &&
      local.service_private_endpoints["key_vault/secrets"].subresource == "vault" &&
      local.service_private_endpoints["key_vault/secrets"].dns_zone == "privatelink.vaultcore.azure.net" &&
      local.private_endpoint_target_ids["cosmos_db/primary"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DocumentDB/databaseAccounts/cosmos" &&
      local.private_endpoint_target_ids["azure_sql/primary"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Sql/servers/sql" &&
      local.storage_private_endpoints["archive"]["storage/archive/file"].target == "storage/archive" &&
      local.storage_private_endpoints["archive"]["storage/archive/file"].subresource == "file" &&
      local.storage_private_endpoints["archive"]["storage/archive/file"].dns_zone == "privatelink.file.core.windows.net" &&
      local.service_private_endpoints["azure_sql/primary"].subresource == "sqlServer" &&
      local.service_private_endpoints["cosmos_db/primary"].subresource == "Sql" &&
      local.service_private_endpoints["cosmos_db/primary"].dns_zone == "privatelink.documents.azure.com" &&
      local.function_storage_private_endpoints["primary"]["function_storage/primary/queue"].dns_zone == "privatelink.queue.core.windows.net"
    )
    error_message = "Private Endpoints must target the right resource, subresource, and DNS zone."
  }

  assert {
    condition = (
      local.private_endpoint_names["key_vault/primary"] == {
        name                            = "mazukvaitppaecmdevswe00-vault"
        private_service_connection_name = "mazukvaitppaecmdevswe00-vault"
        private_dns_zone_group_name     = "default"
      } &&
      local.private_endpoint_names["storage/primary/blob"].name == "mazusoaitppaecmdevswe00-blob" &&
      local.private_endpoint_names["storage/archive/file"].name == "mazusoaitppaecmdevswe01-file" &&
      local.private_endpoint_names["premium_files/media/file"].name == "mazusoaitppaecmdevswe03-file" &&
      local.private_endpoint_names["function_storage/primary/table"].name == "mazusoaitppaecmdevswe04-table" &&
      local.private_endpoint_names["azure_sql/primary"].name == "m-azu-sql-it-ppa-ecm-dev-swe-00-sqlserver" &&
      local.private_endpoint_names["function_app/primary"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE-sites" &&
      local.private_endpoint_names["function_app/primary"].private_dns_zone_group_name == "default"
    )
    error_message = "Private Endpoint names must follow <PARENTNAME>-<SERVICE> with the lowercase Private Link subresource."
  }

  assert {
    condition = alltrue([
      for names in values(local.private_endpoint_names) :
      length(names.name) <= 64 && can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*[a-zA-Z0-9_]$", names.name))
    ])
    error_message = "Every Private Endpoint name must meet Azure's 2-64 character rules."
  }

  assert {
    condition = length(distinct([
      for names in values(local.private_endpoint_names) : names.name
    ])) == length(local.private_endpoint_names)
    error_message = "Private Endpoint names must be unique."
  }

  assert {
    condition = (
      local.private_dns_zones == toset([
        "privatelink.vaultcore.azure.net", "privatelink.azurecr.io", "privatelink.blob.core.windows.net",
        "privatelink.file.core.windows.net", "privatelink.queue.core.windows.net", "privatelink.table.core.windows.net",
        "privatelink.database.windows.net", "privatelink.azurewebsites.net", "privatelink.documents.azure.com"
      ]) &&
      local.subnet_enabled.private_endpoints
    )
    error_message = "Private DNS zones and the endpoint subnet must follow the enabled endpoints."
  }

  assert {
    condition = (
      length(output.private_endpoint_ids.storage) == 2 &&
      length(output.private_endpoint_ids.storage["primary"]) == 2 &&
      length(output.private_endpoint_ids.premium_files) == 2 &&
      keys(output.private_endpoint_ids.function_storage) == ["primary"] &&
      keys(output.private_endpoint_ids.function_storage["primary"]) == ["blob", "file", "queue", "table"] &&
      keys(output.private_endpoint_ids.key_vaults) == ["primary", "secrets"] &&
      keys(output.private_endpoint_ids.web_apps) == ["primary"] &&
      keys(output.private_endpoint_ids.function_apps) == ["primary"]
    )
    error_message = "private_endpoint_ids must keep its service-grouped shape."
  }
}

run "cosmos_api_selects_endpoint" {
  command = plan

  variables {
    cosmos_db_accounts = {
      primary = { api_type = "MongoDB" }
    }
  }

  assert {
    condition = (
      local.service_private_endpoints["cosmos_db/primary"].subresource == "MongoDB" &&
      local.service_private_endpoints["cosmos_db/primary"].dns_zone == "privatelink.mongo.cosmos.azure.com" &&
      contains(local.private_dns_zones, "privatelink.mongo.cosmos.azure.com") &&
      !contains(local.private_dns_zones, "privatelink.documents.azure.com")
    )
    error_message = "The Cosmos DB API must select its Private Endpoint subresource and DNS zone."
  }
}

run "no_endpoints" {
  command = plan

  variables {
    web_apps              = {}
    function_apps         = {}
    app_service_plans     = {}
    storage_accounts      = {}
    premium_file_accounts = {}
    key_vaults            = {}
    container_registries  = {}
    cosmos_db_accounts    = {}
    azure_sql_servers     = {}
  }

  assert {
    condition = (
      length(module.private_endpoints) == 0 &&
      length(module.storage_private_endpoints) == 0 &&
      length(module.function_storage_private_endpoints) == 0 &&
      length(module.function_app_private_endpoint) == 0 &&
      length(local.private_dns_zones) == 0 &&
      !local.subnet_enabled.private_endpoints
    )
    error_message = "With nothing enabled there must be no endpoints, DNS zones, or endpoint subnet."
  }
}
