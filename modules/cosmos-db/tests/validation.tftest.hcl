mock_provider "azurerm" {}

variables {
  name                = "cosmosvalidationtest"
  resource_group_name = "rg-validation-test"
  location            = "swedencentral"
  database_name       = "db-validation-test"
  container_name      = "container-validation-test"
}

run "accept_defaults" {
  command = plan

  assert {
    condition     = azurerm_cosmosdb_account.this.local_authentication_enabled == true
    error_message = "Key-based local authentication must stay enabled by default."
  }
}

run "disable_local_authentication" {
  command = plan
  variables {
    local_authentication_disabled = true
  }

  assert {
    condition     = azurerm_cosmosdb_account.this.local_authentication_enabled == false
    error_message = "local_authentication_disabled = true must turn key-based local authentication off."
  }
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_unknown_api_type" {
#   command = plan
#   variables {
#     api_type = "Unsupported"
#   }
#   expect_failures = [var.api_type]
# }

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_unknown_consistency_level" {
#   command = plan
#   variables {
#     consistency_level = "Unsupported"
#   }
#   expect_failures = [var.consistency_level]
# }

run "reject_unknown_throughput_mode" {
  command = plan
  variables {
    throughput = { mode = "unsupported" }
  }
  expect_failures = [var.throughput]
}

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_manual_throughput_increment" {
#   command = plan
#   variables {
#     throughput = {
#       mode      = "manual"
#       manual_ru = 450
#     }
#   }
#   expect_failures = [var.throughput]
# }

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_autoscale_throughput_increment" {
#   command = plan
#   variables {
#     throughput = {
#       mode             = "autoscale"
#       autoscale_max_ru = 1500
#     }
#   }
#   expect_failures = [var.throughput]
# }

run "reject_table_database_throughput_scope" {
  command = plan
  variables {
    api_type = "Table"
    throughput = {
      mode  = "manual"
      scope = "database"
    }
  }
  expect_failures = [var.throughput]
}

run "reject_empty_nosql_partition_paths" {
  command = plan
  variables {
    nosql_partition_key_paths = []
  }
  expect_failures = [var.nosql_partition_key_paths]
}

run "reject_invalid_nosql_partition_path" {
  command = plan
  variables {
    nosql_partition_key_paths = ["partitionKey"]
  }
  expect_failures = [var.nosql_partition_key_paths]
}

# Disabled: the validation it tests is disabled (azurerm rejects empty values at plan time).
# run "reject_empty_mongodb_shard_key" {
#   command = plan
#   variables {
#     mongodb = { shard_key = " " }
#   }
#   expect_failures = [var.mongodb]
# }

run "reject_invalid_gremlin_partition_path" {
  command = plan
  variables {
    gremlin_partition_key_path = "partitionKey"
  }
  expect_failures = [var.gremlin_partition_key_path]
}

run "reject_duplicate_cassandra_columns" {
  command = plan
  variables {
    cassandra_schema = {
      columns = [
        { name = "id", type = "text" },
        { name = "id", type = "text" }
      ]
      partition_keys = ["id"]
      cluster_keys   = []
    }
  }
  expect_failures = [var.cassandra_schema]
}

run "reject_unknown_cassandra_key" {
  command = plan
  variables {
    cassandra_schema = {
      columns        = [{ name = "id", type = "text" }]
      partition_keys = ["missing"]
      cluster_keys   = []
    }
  }
  expect_failures = [var.cassandra_schema]
}

run "reject_invalid_cassandra_cluster_order" {
  command = plan
  variables {
    cassandra_schema = {
      columns = [
        { name = "partition_key", type = "text" },
        { name = "id", type = "text" }
      ]
      partition_keys = ["partition_key"]
      cluster_keys   = [{ name = "id", order_by = "Descending" }]
    }
  }
  expect_failures = [var.cassandra_schema]
}
