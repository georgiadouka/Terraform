locals {
  cosmos_private_dns_zone_by_api = {
    NoSQL     = "privatelink.documents.azure.com"
    MongoDB   = "privatelink.mongo.cosmos.azure.com"
    Cassandra = "privatelink.cassandra.cosmos.azure.com"
    Gremlin   = "privatelink.gremlin.cosmos.azure.com"
    Table     = "privatelink.table.cosmos.azure.com"
  }

  cosmos_private_endpoint_subresource_by_api = {
    NoSQL     = "Sql"
    MongoDB   = "MongoDB"
    Cassandra = "Cassandra"
    Gremlin   = "Gremlin"
    Table     = "Table"
  }

  # Every Private Endpoint the lab can create, keyed by a stable endpoint key.
  # Entries hold only plan-time values (no module or resource-name references)
  # so for_each keys are always known and the subnet validations that depend on
  # this catalog cannot form a cycle with the naming locals.
  # deployed_by names the module call that creates the endpoint. A storage
  # account rejects concurrent Private Endpoint connections, so storage
  # endpoints use calls that create them one at a time. Function host storage
  # has its own call because the Function App waits for it, and the Function
  # App endpoint has its own call so other endpoints never wait for the app.
  private_endpoint_catalog = merge(
    {
      web_app = {
        enabled     = var.services.web_app
        deployed_by = "private_endpoints"
        target      = "web_app"
        subresource = "sites"
        dns_zone    = "privatelink.azurewebsites.net"
      }
      function_app = {
        enabled     = var.services.function_app
        deployed_by = "function_app_private_endpoint"
        target      = "function_app"
        subresource = "sites"
        dns_zone    = "privatelink.azurewebsites.net"
      }
    },
    {
      for registry_key in keys(var.container_registries) :
      "container_registry/${registry_key}" => {
        enabled     = true
        deployed_by = "private_endpoints"
        target      = "container_registry/${registry_key}"
        subresource = "registry"
        dns_zone    = "privatelink.azurecr.io"
      }
    },
    {
      for server_key in keys(var.azure_sql_servers) :
      "azure_sql/${server_key}" => {
        enabled     = true
        deployed_by = "private_endpoints"
        target      = "azure_sql/${server_key}"
        subresource = "sqlServer"
        dns_zone    = "privatelink.database.windows.net"
      }
    },
    {
      for account_key, account in var.cosmos_db_accounts :
      "cosmos_db/${account_key}" => {
        enabled     = true
        deployed_by = "private_endpoints"
        target      = "cosmos_db/${account_key}"
        subresource = local.cosmos_private_endpoint_subresource_by_api[account.api_type]
        dns_zone    = local.cosmos_private_dns_zone_by_api[account.api_type]
      }
    },
    {
      for vault_key in keys(var.key_vaults) :
      "key_vault/${vault_key}" => {
        enabled     = true
        deployed_by = "private_endpoints"
        target      = "key_vault/${vault_key}"
        subresource = "vault"
        dns_zone    = "privatelink.vaultcore.azure.net"
      }
    },
    {
      for pair in setproduct(keys(var.storage_accounts), ["blob", "file"]) :
      "storage/${pair[0]}/${pair[1]}" => {
        enabled     = true
        deployed_by = "storage_private_endpoints"
        target      = "storage/${pair[0]}"
        subresource = pair[1]
        dns_zone    = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    {
      for account_key in keys(var.premium_file_accounts) :
      "premium_files/${account_key}/file" => {
        enabled     = true
        deployed_by = "private_endpoints"
        target      = "premium_files/${account_key}"
        subresource = "file"
        dns_zone    = "privatelink.file.core.windows.net"
      }
    },
    {
      for subresource in ["blob", "file", "queue", "table"] :
      "function_storage/${subresource}" => {
        enabled     = var.services.function_app
        deployed_by = "function_storage_private_endpoints"
        target      = "function_storage"
        subresource = subresource
        dns_zone    = "privatelink.${subresource}.core.windows.net"
      }
    }
  )

  service_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && endpoint.deployed_by == "private_endpoints"
  }

  # Endpoints grouped by storage account key.
  storage_private_endpoints = {
    for account_key in keys(var.storage_accounts) : account_key => {
      for key, endpoint in local.private_endpoint_catalog : key => endpoint
      if endpoint.enabled && endpoint.deployed_by == "storage_private_endpoints" && endpoint.target == "storage/${account_key}"
    }
  }

  function_storage_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && endpoint.deployed_by == "function_storage_private_endpoints"
  }

  # Parent resource name per catalog target.
  private_endpoint_parent_names = merge(
    {
      web_app          = local.resource_names.web_app
      function_app     = local.resource_names.function_app
      function_storage = local.resource_names.function_storage_account
    },
    { for key, name in local.resource_names.container_registries : "container_registry/${key}" => name },
    { for key, server in local.resource_names.azure_sql_servers : "azure_sql/${key}" => server.server_name },
    { for key, name in local.resource_names.cosmos_db_accounts : "cosmos_db/${key}" => name },
    { for key, name in local.resource_names.key_vaults : "key_vault/${key}" => name },
    { for key, name in local.resource_names.storage_accounts : "storage/${key}" => name },
    { for key, name in local.resource_names.premium_file_accounts : "premium_files/${key}" => name }
  )

  # <PARENTNAME>-<SERVICE> (§4), where SERVICE is the lowercase Private Link
  # subresource, for example mazusoaitppaecmdevswe00-blob. The connection and
  # DNS zone group are scoped to the endpoint and not covered by the standard,
  # so they reuse the endpoint name and the Azure default "default".
  private_endpoint_names = {
    for key, endpoint in local.private_endpoint_catalog : key => {
      name                            = "${local.private_endpoint_parent_names[endpoint.target]}-${lower(endpoint.subresource)}"
      private_service_connection_name = "${local.private_endpoint_parent_names[endpoint.target]}-${lower(endpoint.subresource)}"
      private_dns_zone_group_name     = "default"
    }
  }

  # Private Link resource IDs for module.private_endpoints, keyed by catalog
  # target. Storage accounts and the Function App are referenced by their own
  # module calls so these endpoints never wait for them.
  private_endpoint_target_ids = merge(
    var.services.web_app ? { web_app = module.web_app[0].id } : {},
    { for key, registry in module.container_registry : "container_registry/${key}" => registry.id },
    { for key, server in module.azure_sql : "azure_sql/${key}" => server.server_id },
    { for key, account in module.cosmos_db : "cosmos_db/${key}" => account.id },
    { for key, vault in module.key_vault : "key_vault/${key}" => vault.id },
    { for key, account in module.premium_files : "premium_files/${key}" => account.id }
  )

  private_dns_zones = setunion(
    toset([
      for endpoint in values(local.private_endpoint_catalog) : endpoint.dns_zone
      if endpoint.enabled
    ]),
    length(var.postgresql_servers) > 0 ? toset(["privatelink.postgres.database.azure.com"]) : toset([]),
    length(var.mysql_servers) > 0 ? toset(["privatelink.mysql.database.azure.com"]) : toset([])
  )

  private_dns_link_names = {
    for zone_name in local.private_dns_zones :
    zone_name => "${local.naming_prefixes.private_dns_link}-${substr(md5(zone_name), 0, 8)}-${local.name_stem}"
  }
}
