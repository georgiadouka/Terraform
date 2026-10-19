variable "name" {
  description = "Globally unique Cosmos DB account name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,42}[a-z0-9]$", var.name))
    error_message = "name must be 3-44 lowercase alphanumeric or hyphen characters and start and end with an alphanumeric character."
  }
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "api_type" {
  description = "Cosmos DB classic API created by this account."
  type        = string
  default     = "NoSQL"

  validation {
    condition     = contains(["NoSQL", "MongoDB", "Cassandra", "Gremlin", "Table"], var.api_type)
    error_message = "api_type must be NoSQL, MongoDB, Cassandra, Gremlin, or Table."
  }
}

variable "database_name" {
  description = "Database, keyspace, or graph database name. Unused by the Table API."
  type        = string

  validation {
    condition     = trimspace(var.database_name) != ""
    error_message = "database_name cannot be empty."
  }
}

variable "container_name" {
  description = "Container, collection, table, or graph name."
  type        = string

  validation {
    condition     = trimspace(var.container_name) != ""
    error_message = "container_name cannot be empty."
  }
}

variable "throughput" {
  description = "Serverless, manual RU/s, or autoscale throughput configuration."
  type = object({
    mode             = optional(string, "serverless")
    scope            = optional(string, "container")
    manual_ru        = optional(number, 400)
    autoscale_max_ru = optional(number, 1000)
  })
  default = {}

  validation {
    condition = (
      contains(["serverless", "manual", "autoscale"], var.throughput.mode) &&
      contains(["database", "container"], var.throughput.scope)
    )
    error_message = "throughput.mode must be serverless, manual, or autoscale and throughput.scope must be database or container."
  }

  validation {
    condition = (
      var.throughput.mode != "manual" ||
      (
        var.throughput.manual_ru >= 400 &&
        var.throughput.manual_ru <= 1000000 &&
        var.throughput.manual_ru % 100 == 0
      )
    )
    error_message = "Manual throughput must be 400-1,000,000 RU/s in increments of 100."
  }

  validation {
    condition = (
      var.throughput.mode != "autoscale" ||
      (
        var.throughput.autoscale_max_ru >= 1000 &&
        var.throughput.autoscale_max_ru <= 1000000 &&
        var.throughput.autoscale_max_ru % 1000 == 0
      )
    )
    error_message = "Autoscale maximum throughput must be 1,000-1,000,000 RU/s in increments of 1,000."
  }

  validation {
    condition     = var.api_type != "Table" || var.throughput.scope == "container"
    error_message = "The Table API supports throughput only at table scope; set throughput.scope to container."
  }
}

variable "consistency_level" {
  description = "Default Cosmos DB consistency level."
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Eventual", "ConsistentPrefix", "Session", "BoundedStaleness", "Strong"], var.consistency_level)
    error_message = "consistency_level must be Eventual, ConsistentPrefix, Session, BoundedStaleness, or Strong."
  }
}

variable "local_authentication_disabled" {
  description = "Disable key-based local authentication. Confirm API client support before enabling."
  type        = bool
  default     = false
}

variable "nosql_partition_key_paths" {
  description = "NoSQL partition key paths. Multiple paths create a hierarchical partition key."
  type        = list(string)
  default     = ["/partitionKey"]

  validation {
    condition = (
      length(var.nosql_partition_key_paths) >= 1 &&
      length(var.nosql_partition_key_paths) <= 3 &&
      alltrue([for path in var.nosql_partition_key_paths : startswith(path, "/")])
    )
    error_message = "nosql_partition_key_paths must contain one to three paths that start with /."
  }
}

variable "mongodb" {
  description = "MongoDB API-specific settings."
  type = object({
    server_version = optional(string, "4.2")
    shard_key      = optional(string, "partitionKey")
  })
  default = {}

  validation {
    condition     = contains(["7.0", "6.0", "5.0", "4.2", "4.0", "3.6", "3.2"], var.mongodb.server_version)
    error_message = "mongodb.server_version must be a version supported by AzureRM."
  }

  validation {
    condition     = trimspace(var.mongodb.shard_key) != ""
    error_message = "mongodb.shard_key cannot be empty."
  }
}

variable "cassandra_schema" {
  description = "Cassandra table columns and primary-key definition."
  type = object({
    columns = optional(list(object({
      name = string
      type = string
      })), [
      {
        name = "partition_key"
        type = "text"
      },
      {
        name = "id"
        type = "text"
      },
      {
        name = "value"
        type = "text"
      }
    ])
    partition_keys = optional(list(string), ["partition_key"])
    cluster_keys = optional(list(object({
      name     = string
      order_by = optional(string, "Asc")
      })), [
      {
        name     = "id"
        order_by = "Asc"
      }
    ])
  })
  default = {}

  validation {
    condition = (
      length(var.cassandra_schema.columns) > 0 &&
      length(var.cassandra_schema.partition_keys) > 0 &&
      length(distinct([for column in var.cassandra_schema.columns : column.name])) == length(var.cassandra_schema.columns) &&
      alltrue([
        for key in concat(
          var.cassandra_schema.partition_keys,
          [for key in var.cassandra_schema.cluster_keys : key.name]
        ) : contains([for column in var.cassandra_schema.columns : column.name], key)
      ]) &&
      alltrue([for key in var.cassandra_schema.cluster_keys : contains(["Asc", "Desc"], key.order_by)])
    )
    error_message = "Cassandra columns must have unique names; partition and cluster keys must reference columns; cluster order must be Asc or Desc."
  }
}

variable "gremlin_partition_key_path" {
  description = "Gremlin graph partition key path."
  type        = string
  default     = "/partitionKey"

  validation {
    condition     = startswith(var.gremlin_partition_key_path, "/")
    error_message = "gremlin_partition_key_path must start with /."
  }
}

variable "tags" {
  description = "Tags applied to Cosmos DB resources."
  type        = map(string)
  default     = {}
}

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
  local_authentication_disabled = var.local_authentication_disabled

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

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
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

output "id" {
  description = "Cosmos DB account ID."
  value       = azurerm_cosmosdb_account.this.id
}

output "name" {
  description = "Cosmos DB account name."
  value       = azurerm_cosmosdb_account.this.name
}

output "endpoint" {
  description = "Cosmos DB account endpoint."
  value       = azurerm_cosmosdb_account.this.endpoint
}

output "hostname" {
  description = "API-specific Cosmos DB account hostname."
  value       = "${azurerm_cosmosdb_account.this.name}.${local.endpoint_hostname_suffixes[var.api_type]}"
}

output "api_type" {
  description = "Cosmos DB API type."
  value       = var.api_type
}

output "database_id" {
  description = "Database or keyspace ID, or null for the Table API."
  value = try(compact([
    try(azurerm_cosmosdb_sql_database.this[0].id, null),
    try(azurerm_cosmosdb_mongo_database.this[0].id, null),
    try(azurerm_cosmosdb_cassandra_keyspace.this[0].id, null),
    try(azurerm_cosmosdb_gremlin_database.this[0].id, null)
  ])[0], null)
}

output "container_id" {
  description = "Container, collection, table, or graph ID."
  value = try(compact([
    try(azurerm_cosmosdb_sql_container.this[0].id, null),
    try(azurerm_cosmosdb_mongo_collection.this[0].id, null),
    try(azurerm_cosmosdb_cassandra_table.this[0].id, null),
    try(azurerm_cosmosdb_gremlin_graph.this[0].id, null),
    try(azurerm_cosmosdb_table.this[0].id, null)
  ])[0], null)
}

output "principal_id" {
  description = "System-assigned identity principal ID."
  value       = azurerm_cosmosdb_account.this.identity[0].principal_id
}
