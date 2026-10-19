mock_provider "azurerm" {}

variables {
  server_name         = "sql-validation-test"
  database_name       = "sqldb-validation-test"
  resource_group_name = "rg-validation-test"
  location            = "swedencentral"
  azuread_administrator = {
    login_username = "Terraform SQL Admin"
    object_id      = "11111111-1111-1111-1111-111111111111"
    tenant_id      = "22222222-2222-2222-2222-222222222222"
  }
}

run "accept_positive_database_size" {
  command = plan

  assert {
    condition     = azurerm_mssql_database.this.max_size_gb == 2
    error_message = "The database must retain the positive default maximum size."
  }
}

run "reject_nonpositive_database_size" {
  command = plan
  variables {
    max_size_gb = 0
  }

  expect_failures = [var.max_size_gb]
}

run "reject_database_larger_than_pool" {
  command = plan
  variables {
    max_size_gb = 8
    elastic_pool = {
      enabled     = true
      name        = "sqlep-validation-test"
      max_size_gb = 4
    }
  }

  expect_failures = [azurerm_mssql_database.this]
}
