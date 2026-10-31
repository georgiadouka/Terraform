locals {
  api_capabilities = {
    NoSQL     = []
    MongoDB   = ["EnableMongo"]
    Cassandra = ["EnableCassandra"]
    Gremlin   = ["EnableGremlin"]
    Table     = ["EnableTable"]
  }

  capabilities = toset(concat(
    local.api_capabilities[var.api_type],
    var.throughput.mode == "serverless" ? ["EnableServerless"] : []
  ))

  database_manual_ru = (
    var.throughput.mode == "manual" && var.throughput.scope == "database"
    ? var.throughput.manual_ru
    : null
  )
  container_manual_ru = (
    var.throughput.mode == "manual" && var.throughput.scope == "container"
    ? var.throughput.manual_ru
    : null
  )
  database_autoscale  = var.throughput.mode == "autoscale" && var.throughput.scope == "database"
  container_autoscale = var.throughput.mode == "autoscale" && var.throughput.scope == "container"

  endpoint_hostname_suffixes = {
    NoSQL     = "documents.azure.com"
    MongoDB   = "mongo.cosmos.azure.com"
    Cassandra = "cassandra.cosmos.azure.com"
    Gremlin   = "gremlin.cosmos.azure.com"
    Table     = "table.cosmos.azure.com"
  }
}

resource "azurerm_cosmosdb_account" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  offer_type                    = "Standard"
  kind                          = var.api_type == "MongoDB" ? "MongoDB" : "GlobalDocumentDB"
  mongo_server_version          = var.api_type == "MongoDB" ? var.mongodb.server_version : null
  minimal_tls_version           = "Tls12"
  public_network_access_enabled = false
  local_authentication_enabled  = !var.local_authentication_disabled

  access_key_metadata_writes_enabled    = false
  network_acl_bypass_for_azure_services = false
  automatic_failover_enabled            = false
  multiple_write_locations_enabled      = false
  analytical_storage_enabled            = false
  free_tier_enabled                     = false
  is_virtual_network_filter_enabled     = false
  tags                                  = var.tags

  dynamic "capabilities" {
    for_each = local.capabilities

    content {
      name = capabilities.value
    }
  }

  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.consistency_level == "BoundedStaleness" ? 300 : null
    max_staleness_prefix    = var.consistency_level == "BoundedStaleness" ? 100000 : null
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cosmosdb_sql_database" "this" {
  count = var.api_type == "NoSQL" ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = local.database_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.database_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }
}

resource "azurerm_cosmosdb_sql_container" "this" {
  count = var.api_type == "NoSQL" ? 1 : 0

  name                  = var.container_name
  resource_group_name   = var.resource_group_name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_sql_database.this[0].name
  partition_key_paths   = var.nosql_partition_key_paths
  partition_key_kind    = length(var.nosql_partition_key_paths) > 1 ? "MultiHash" : "Hash"
  partition_key_version = 2
  throughput            = local.container_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.container_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }

  # Cosmos DB excludes the system "/\"_etag\"/?" path by default. AzureRM omits
  # it when reading the policy, so declaring it causes a perpetual diff.
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

resource "azurerm_cosmosdb_mongo_database" "this" {
  count = var.api_type == "MongoDB" ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = local.database_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.database_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }
}

resource "azurerm_cosmosdb_mongo_collection" "this" {
  count = var.api_type == "MongoDB" ? 1 : 0

  name                = var.container_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_mongo_database.this[0].name
  shard_key           = var.mongodb.shard_key
  throughput          = local.container_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.container_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys   = [var.mongodb.shard_key]
    unique = false
  }
}

resource "azurerm_cosmosdb_cassandra_keyspace" "this" {
  count = var.api_type == "Cassandra" ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = local.database_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.database_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }
}

resource "azurerm_cosmosdb_cassandra_table" "this" {
  count = var.api_type == "Cassandra" ? 1 : 0

  name                  = var.container_name
  cassandra_keyspace_id = azurerm_cosmosdb_cassandra_keyspace.this[0].id
  throughput            = local.container_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.container_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }

  schema {
    dynamic "column" {
      for_each = var.cassandra_schema.columns

      content {
        name = column.value.name
        type = column.value.type
      }
    }

    dynamic "partition_key" {
      for_each = var.cassandra_schema.partition_keys

      content {
        name = partition_key.value
      }
    }

    dynamic "cluster_key" {
      for_each = var.cassandra_schema.cluster_keys

      content {
        name     = cluster_key.value.name
        order_by = cluster_key.value.order_by
      }
    }
  }
}

resource "azurerm_cosmosdb_gremlin_database" "this" {
  count = var.api_type == "Gremlin" ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = local.database_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.database_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }
}

resource "azurerm_cosmosdb_gremlin_graph" "this" {
  count = var.api_type == "Gremlin" ? 1 : 0

  name                  = var.container_name
  resource_group_name   = var.resource_group_name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_gremlin_database.this[0].name
  partition_key_path    = var.gremlin_partition_key_path
  partition_key_version = 2
  throughput            = local.container_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.container_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }

  index_policy {
    automatic      = true
    indexing_mode  = "consistent"
    included_paths = ["/*"]
    excluded_paths = ["/\"_etag\"/?"]
  }
}

resource "azurerm_cosmosdb_table" "this" {
  count = var.api_type == "Table" ? 1 : 0

  name                = var.container_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = local.container_manual_ru

  dynamic "autoscale_settings" {
    for_each = local.container_autoscale ? [1] : []

    content {
      max_throughput = var.throughput.autoscale_max_ru
    }
  }
}
