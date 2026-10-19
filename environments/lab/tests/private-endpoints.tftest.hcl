# Locks in Private Endpoint wiring: which endpoints exist, what each targets,
# its subresource and DNS zone, and the generated names. Targets use distinct
# realistic IDs so miswiring is detectable.
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
      private_endpoints    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/pe"
      virtual_machines     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vm"
      container_apps       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/aca"
      web_app_integration  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web"
      function_integration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/func"
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
  target  = module.key_vault[0]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv", name = "kv", vault_uri = "https://kv.vault.azure.net/" }
}
override_module {
  target  = module.container_registry[0]
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
  target  = module.azure_sql[0]
  outputs = { server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Sql/servers/sql", database_id = "db", elastic_pool_id = null, elastic_pool_name = null, fully_qualified_domain_name = "sql.database.windows.net" }
}
override_module {
  target  = module.cosmos_db[0]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DocumentDB/databaseAccounts/cosmos", name = "cosmos", endpoint = "https://cosmos", hostname = "cosmos.documents.azure.com", api_type = "NoSQL", database_id = "db", container_id = "ct", principal_id = null }
}
override_module {
  target  = module.web_app[0]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/web", default_hostname = "web.azurewebsites.net", principal_id = "p", mode = "linux", service_plan_id = "sp" }
}
override_module {
  target  = module.function_app[0]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func", default_hostname = "func.azurewebsites.net", principal_id = "p", os_type = "Linux" }
}
override_module {
  target  = module.function_storage[0]
  outputs = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfn", name = "stfn", shared_access_key_enabled = true, primary_access_key = "k", primary_connection_string = "c", data_plane_role_assignment_ids = {}, container_ids = {}, file_share_ids = {} }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  subscription_id  = "00000000-0000-0000-0000-000000000000"
  tenant_id        = "22222222-2222-2222-2222-222222222222"
  project_name     = "metlen"
  environment      = "lab"
  naming           = { unique_suffix = "test1" }
  virtual_machines = {}
  storage_accounts = {
    primary = {}
    archive = {}
  }
  premium_file_accounts = {
    primary = {}
    media   = {}
  }
  container_apps = {}
  web_app        = {}
  function_app   = {}
  cosmos_db      = {}
  services = {
    key_vault          = true
    container_registry = true
    azure_sql          = true
    cosmos_db          = true
    web_app            = true
    function_app       = true
  }
  storage_use_azuread = true
  location            = "swedencentral"
  address_space       = ["10.42.0.0/20"]
  subnet_cidrs = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    container_apps       = "10.42.2.0/23"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }
  virtual_machine_scale_set = {}
  nat_gateway               = {}
  key_vault                 = {}
  azure_sql                 = {}
  sql_managed_instance      = {}
  postgresql                = {}
  mysql                     = {}
  tags                      = {}
}

run "all_endpoints" {
  command = plan

  assert {
    condition = keys(local.service_private_endpoints) == [
      "azure_sql", "container_registry", "cosmos_db", "function_app", "key_vault",
      "premium_files/media/file", "premium_files/primary/file",
      "storage/archive/blob", "storage/archive/file", "storage/primary/blob", "storage/primary/file",
      "web_app"
    ]
    error_message = "Every enabled service and map entry must produce exactly its Private Endpoints."
  }

  assert {
    condition = keys(local.function_storage_private_endpoints) == [
      "function_storage/blob", "function_storage/file", "function_storage/queue", "function_storage/table"
    ]
    error_message = "Function host storage endpoints must stay in their own group so the Function App can depend on them."
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
      local.private_endpoint_target_ids["storage/archive"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/starchive" &&
      local.private_endpoint_target_ids["premium_files/media"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/pfmedia" &&
      local.private_endpoint_target_ids["azure_sql"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Sql/servers/sql" &&
      local.function_storage_target_ids["function_storage"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfn" &&
      local.service_private_endpoints["storage/archive/file"].target == "storage/archive" &&
      local.service_private_endpoints["storage/archive/file"].subresource == "file" &&
      local.service_private_endpoints["storage/archive/file"].dns_zone == "privatelink.file.core.windows.net" &&
      local.service_private_endpoints["azure_sql"].subresource == "sqlServer" &&
      local.service_private_endpoints["cosmos_db"].subresource == "Sql" &&
      local.service_private_endpoints["cosmos_db"].dns_zone == "privatelink.documents.azure.com" &&
      local.function_storage_private_endpoints["function_storage/queue"].dns_zone == "privatelink.queue.core.windows.net"
    )
    error_message = "Private Endpoints must target the right resource, subresource, and DNS zone."
  }

  assert {
    condition = (
      local.resource_names.private_endpoints["key_vault"] == {
        name                            = "pe-kv-metlen-lab-test1"
        private_service_connection_name = "psc-kv-metlen-lab-test1"
        private_dns_zone_group_name     = "pdnszg-kv-metlen-lab-test1"
      } &&
      local.resource_names.private_endpoints["storage/primary/blob"].name == "pe-st-primary-blob-metlen-lab-test1" &&
      local.resource_names.private_endpoints["premium_files/media/file"].name == "pe-stpf-media-file-metlen-lab-test1" &&
      local.resource_names.private_endpoints["function_storage/table"].name == "pe-stfn-table-metlen-lab-test1" &&
      local.resource_names.private_endpoints["function_app"].private_dns_zone_group_name == "pdnszg-func-metlen-lab-test1"
    )
    error_message = "Private Endpoint names must follow <prefix>-<token>-<project>-<environment>-<suffix>."
  }

  assert {
    condition = length(distinct([
      for names in values(local.resource_names.private_endpoints) : names.name
    ])) == length(local.resource_names.private_endpoints)
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
      keys(output.private_endpoint_ids.function_storage) == ["blob", "file", "queue", "table"] &&
      output.private_endpoint_ids.key_vault != null &&
      output.private_endpoint_ids.function_app != null
    )
    error_message = "private_endpoint_ids must keep its service-grouped shape."
  }
}

run "cosmos_api_selects_endpoint" {
  command = plan

  variables {
    cosmos_db = { api_type = "MongoDB" }
  }

  assert {
    condition = (
      local.service_private_endpoints["cosmos_db"].subresource == "MongoDB" &&
      local.service_private_endpoints["cosmos_db"].dns_zone == "privatelink.mongo.cosmos.azure.com" &&
      contains(local.private_dns_zones, "privatelink.mongo.cosmos.azure.com") &&
      !contains(local.private_dns_zones, "privatelink.documents.azure.com")
    )
    error_message = "The Cosmos DB API must select its Private Endpoint subresource and DNS zone."
  }
}

run "no_endpoints" {
  command = plan

  variables {
    services              = {}
    storage_accounts      = {}
    premium_file_accounts = {}
  }

  assert {
    condition = (
      length(module.private_endpoints) == 0 &&
      length(module.function_storage_private_endpoints) == 0 &&
      length(local.private_dns_zones) == 0 &&
      !local.subnet_enabled.private_endpoints
    )
    error_message = "With nothing enabled there must be no endpoints, DNS zones, or endpoint subnet."
  }
}
