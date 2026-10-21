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
