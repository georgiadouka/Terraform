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
  # virtual_network is the VNet whose private_endpoints subnet hosts it: the
  # VNet of the parent resource.
  # Entries hold only plan-time values (no module or resource-name references)
  # so for_each keys are always known and the subnet validations that depend on
  # this catalog cannot form a cycle with the naming locals.
  # deployed_by names the module call that creates the endpoint. A storage
  # account rejects concurrent Private Endpoint connections, so storage
  # endpoints use calls that create them one at a time. Function App and
  # Logic App host storage has its own call per app because each app waits
  # for its storage endpoints, and the Function App and Logic App endpoints
  # have their own calls so other endpoints never wait for the apps.
  private_endpoint_catalog = merge(
    {
      for app_key in keys(var.web_apps) :
      "web_app/${app_key}" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "web_app/${app_key}"
        virtual_network = local.virtual_network_placement.web_apps[app_key]
        subresource     = "sites"
        dns_zone        = "privatelink.azurewebsites.net"
      }
    },
    {
      for app_key in keys(var.function_apps) :
      "function_app/${app_key}" => {
        enabled         = true
        deployed_by     = "function_app_private_endpoint"
        target          = "function_app/${app_key}"
        virtual_network = local.virtual_network_placement.function_apps[app_key]
        subresource     = "sites"
        dns_zone        = "privatelink.azurewebsites.net"
      }
    },
    {
      for app_key in keys(var.logic_apps) :
      "logic_app/${app_key}" => {
        enabled         = true
        deployed_by     = "logic_app_private_endpoint"
        target          = "logic_app/${app_key}"
        virtual_network = local.virtual_network_placement.logic_apps[app_key]
        subresource     = "sites"
        dns_zone        = "privatelink.azurewebsites.net"
      }
    },
    {
      for registry_key in keys(var.container_registries) :
      "container_registry/${registry_key}" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "container_registry/${registry_key}"
        virtual_network = local.virtual_network_placement.container_registries[registry_key]
        subresource     = "registry"
        dns_zone        = "privatelink.azurecr.io"
      }
    },
    {
      for server_key in keys(var.azure_sql_servers) :
      "azure_sql/${server_key}" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "azure_sql/${server_key}"
        virtual_network = local.virtual_network_placement.azure_sql_servers[server_key]
        subresource     = "sqlServer"
        dns_zone        = "privatelink.database.windows.net"
      }
    },
    {
      for account_key, account in var.cosmos_db_accounts :
      "cosmos_db/${account_key}" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "cosmos_db/${account_key}"
        virtual_network = local.virtual_network_placement.cosmos_db_accounts[account_key]
        subresource     = local.cosmos_private_endpoint_subresource_by_api[account.api_type]
        dns_zone        = local.cosmos_private_dns_zone_by_api[account.api_type]
      }
    },
    {
      for vault_key in keys(var.key_vaults) :
      "key_vault/${vault_key}" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "key_vault/${vault_key}"
        virtual_network = local.virtual_network_placement.key_vaults[vault_key]
        subresource     = "vault"
        dns_zone        = "privatelink.vaultcore.azure.net"
      }
    },
    {
      for pair in setproduct(keys(var.storage_accounts), ["blob", "file"]) :
      "storage/${pair[0]}/${pair[1]}" => {
        enabled         = true
        deployed_by     = "storage_private_endpoints"
        target          = "storage/${pair[0]}"
        virtual_network = local.virtual_network_placement.storage_accounts[pair[0]]
        subresource     = pair[1]
        dns_zone        = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    {
      for account_key in keys(var.premium_file_accounts) :
      "premium_files/${account_key}/file" => {
        enabled         = true
        deployed_by     = "private_endpoints"
        target          = "premium_files/${account_key}"
        virtual_network = local.virtual_network_placement.premium_file_accounts[account_key]
        subresource     = "file"
        dns_zone        = "privatelink.file.core.windows.net"
      }
    },
    {
      for pair in setproduct(keys(var.function_apps), ["blob", "file", "queue", "table"]) :
      "function_storage/${pair[0]}/${pair[1]}" => {
        enabled         = true
        deployed_by     = "function_storage_private_endpoints"
        target          = "function_storage/${pair[0]}"
        virtual_network = local.virtual_network_placement.function_apps[pair[0]]
        subresource     = pair[1]
        dns_zone        = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    {
      for pair in setproduct(keys(var.logic_apps), ["blob", "file", "queue", "table"]) :
      "logic_app_storage/${pair[0]}/${pair[1]}" => {
        enabled         = true
        deployed_by     = "logic_app_storage_private_endpoints"
        target          = "logic_app_storage/${pair[0]}"
        virtual_network = local.virtual_network_placement.logic_apps[pair[0]]
        subresource     = pair[1]
        dns_zone        = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    # One databricks_ui_api endpoint per private or backend_private workload
    # workspace serves both users (front-end) and clusters (back-end) because
    # it sits in the workspace VNet. The browser authentication workspace
    # must not have one.
    {
      for workspace_key, workspace in var.databricks_workspaces :
      "databricks/${workspace_key}/databricks_ui_api" => {
        enabled         = workspace.network_access != "public" && !workspace.browser_authentication_workspace
        deployed_by     = "private_endpoints"
        target          = "databricks/${workspace_key}"
        virtual_network = local.databricks_workspace_networks[workspace_key]
        subresource     = "databricks_ui_api"
        dns_zone        = "privatelink.azuredatabricks.net"
      }
    },
    # Browser sign-in to every private workspace in the region goes through the
    # one browser_authentication endpoint on the dedicated browser
    # authentication workspace. It has its own call, after the other
    # endpoints, and the workspace's delete lock waits for it.
    {
      for workspace_key in local.databricks_browser_authentication_keys :
      "databricks/${workspace_key}/browser_authentication" => {
        enabled         = true
        deployed_by     = "databricks_browser_authentication_private_endpoint"
        target          = "databricks/${workspace_key}"
        virtual_network = local.databricks_workspace_networks[workspace_key]
        subresource     = "browser_authentication"
        dns_zone        = "privatelink.azuredatabricks.net"
      }
    }
  )

  databricks_browser_authentication_keys = sort([
    for key, workspace in var.databricks_workspaces : key
    if workspace.browser_authentication_workspace
  ])

  databricks_browser_authentication_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && endpoint.deployed_by == "databricks_browser_authentication_private_endpoint"
  }

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

  # Function host storage endpoints grouped by Function App key.
  function_storage_private_endpoints = {
    for app_key in keys(var.function_apps) : app_key => {
      for key, endpoint in local.private_endpoint_catalog : key => endpoint
      if endpoint.enabled && endpoint.deployed_by == "function_storage_private_endpoints" && endpoint.target == "function_storage/${app_key}"
    }
  }

  # Logic App host storage endpoints grouped by Logic App key.
  logic_app_storage_private_endpoints = {
    for app_key in keys(var.logic_apps) : app_key => {
      for key, endpoint in local.private_endpoint_catalog : key => endpoint
      if endpoint.enabled && endpoint.deployed_by == "logic_app_storage_private_endpoints" && endpoint.target == "logic_app_storage/${app_key}"
    }
  }

  # Parent resource name per catalog target.
  private_endpoint_parent_names = merge(
    { for key, app in local.resource_names.web_apps : "web_app/${key}" => app.name },
    { for key, app in local.resource_names.function_apps : "function_app/${key}" => app.name },
    { for key, app in local.resource_names.function_apps : "function_storage/${key}" => app.storage_account_name },
    { for key, app in local.resource_names.logic_apps : "logic_app/${key}" => app.name },
    { for key, app in local.resource_names.logic_apps : "logic_app_storage/${key}" => app.storage_account_name },
    { for key, name in local.resource_names.container_registries : "container_registry/${key}" => name },
    { for key, server in local.resource_names.azure_sql_servers : "azure_sql/${key}" => server.server_name },
    { for key, name in local.resource_names.cosmos_db_accounts : "cosmos_db/${key}" => name },
    { for key, name in local.resource_names.key_vaults : "key_vault/${key}" => name },
    { for key, name in local.resource_names.storage_accounts : "storage/${key}" => name },
    { for key, name in local.resource_names.premium_file_accounts : "premium_files/${key}" => name },
    { for key, workspace in local.resource_names.databricks_workspaces : "databricks/${key}" => workspace.name }
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
  # target. Storage accounts, Function Apps and Logic Apps are referenced by
  # their own module calls so these endpoints never wait for them.
  private_endpoint_target_ids = merge(
    { for key, app in module.web_app : "web_app/${key}" => app.id },
    { for key, registry in module.container_registry : "container_registry/${key}" => registry.id },
    { for key, server in module.azure_sql : "azure_sql/${key}" => server.server_id },
    { for key, account in module.cosmos_db : "cosmos_db/${key}" => account.id },
    { for key, vault in module.key_vault : "key_vault/${key}" => vault.id },
    { for key, account in module.premium_files : "premium_files/${key}" => account.id },
    { for key, workspace in module.databricks : "databricks/${key}" => workspace.id }
  )

  private_dns_zones = setunion(
    toset([
      for endpoint in values(local.private_endpoint_catalog) : endpoint.dns_zone
      if endpoint.enabled
    ]),
    length(var.postgresql_servers) > 0 ? toset(["privatelink.postgres.database.azure.com"]) : toset([]),
    length(var.mysql_servers) > 0 ? toset(["privatelink.mysql.database.azure.com"]) : toset([])
  )
}
