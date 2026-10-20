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
  # Entries hold only plan-time values (no module references) so names and
  # for_each keys are always known. Names follow <prefix>-<name_token>-<stem>.
  # function_host_storage entries are deployed by a separate module call because
  # the Function App must wait for them before it is created.
  private_endpoint_catalog = merge(
    {
      web_app = {
        enabled               = var.services.web_app
        function_host_storage = false
        target                = "web_app"
        name_token            = local.naming_prefixes.web_app
        subresource           = "sites"
        dns_zone              = "privatelink.azurewebsites.net"
      }
      function_app = {
        enabled               = var.services.function_app
        function_host_storage = false
        target                = "function_app"
        name_token            = local.naming_prefixes.function_app
        subresource           = "sites"
        dns_zone              = "privatelink.azurewebsites.net"
      }
    },
    {
      for registry_key in keys(var.container_registries) :
      "container_registry/${registry_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "container_registry/${registry_key}"
        name_token            = "${local.naming_prefixes.container_registry}-${registry_key}"
        subresource           = "registry"
        dns_zone              = "privatelink.azurecr.io"
      }
    },
    {
      for server_key in keys(var.azure_sql_servers) :
      "azure_sql/${server_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "azure_sql/${server_key}"
        name_token            = "${local.naming_prefixes.azure_sql_server}-${server_key}"
        subresource           = "sqlServer"
        dns_zone              = "privatelink.database.windows.net"
      }
    },
    {
      for account_key, account in var.cosmos_db_accounts :
      "cosmos_db/${account_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "cosmos_db/${account_key}"
        name_token            = "${local.naming_prefixes.cosmos_db_account}-${account_key}"
        subresource           = local.cosmos_private_endpoint_subresource_by_api[account.api_type]
        dns_zone              = local.cosmos_private_dns_zone_by_api[account.api_type]
      }
    },
    {
      for vault_key in keys(var.key_vaults) :
      "key_vault/${vault_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "key_vault/${vault_key}"
        name_token            = "${local.naming_prefixes.key_vault}-${vault_key}"
        subresource           = "vault"
        dns_zone              = "privatelink.vaultcore.azure.net"
      }
    },
    {
      for pair in setproduct(keys(var.storage_accounts), ["blob", "file"]) :
      "storage/${pair[0]}/${pair[1]}" => {
        enabled               = true
        function_host_storage = false
        target                = "storage/${pair[0]}"
        name_token            = "${local.naming_prefixes.storage_account}-${pair[0]}-${pair[1]}"
        subresource           = pair[1]
        dns_zone              = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    {
      for account_key in keys(var.premium_file_accounts) :
      "premium_files/${account_key}/file" => {
        enabled               = true
        function_host_storage = false
        target                = "premium_files/${account_key}"
        name_token            = "${local.naming_prefixes.premium_files_account}-${account_key}-file"
        subresource           = "file"
        dns_zone              = "privatelink.file.core.windows.net"
      }
    },
    {
      for subresource in ["blob", "file", "queue", "table"] :
      "function_storage/${subresource}" => {
        enabled               = var.services.function_app
        function_host_storage = true
        target                = "function_storage"
        name_token            = "${local.naming_prefixes.function_storage_account}-${subresource}"
        subresource           = subresource
        dns_zone              = "privatelink.${subresource}.core.windows.net"
      }
    }
  )

  service_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && !endpoint.function_host_storage
  }

  function_storage_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && endpoint.function_host_storage
  }

  # Private Link resource IDs keyed by catalog target. Function host storage is
  # resolved separately so its endpoints do not wait for the Function App.
  private_endpoint_target_ids = merge(
    var.services.web_app ? { web_app = module.web_app[0].id } : {},
    var.services.function_app ? { function_app = module.function_app[0].id } : {},
    { for key, registry in module.container_registry : "container_registry/${key}" => registry.id },
    { for key, server in module.azure_sql : "azure_sql/${key}" => server.server_id },
    { for key, account in module.cosmos_db : "cosmos_db/${key}" => account.id },
    { for key, vault in module.key_vault : "key_vault/${key}" => vault.id },
    { for key, account in module.storage : "storage/${key}" => account.id },
    { for key, account in module.premium_files : "premium_files/${key}" => account.id }
  )

  function_storage_target_ids = var.services.function_app ? {
    function_storage = module.function_storage[0].id
  } : {}

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
