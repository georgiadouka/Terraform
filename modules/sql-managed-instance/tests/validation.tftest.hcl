mock_provider "azurerm" {}

variables {
  name                        = "sqlmi-validation-test"
  resource_group_name         = "rg-validation-test"
  location                    = "swedencentral"
  subnet_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/sql-managed-instance"
  subnet_address_prefix       = "10.42.7.0/27"
  network_security_group_name = "nsg-sqlmi-validation-test"
  route_table_name            = "rt-sqlmi-validation-test"
  azuread_administrator = {
    login_username = "Terraform SQL MI Admin"
    object_id      = "11111111-1111-1111-1111-111111111111"
  }
}

run "accept_minimum_storage_and_included_license" {
  command = plan
}

run "reject_storage_below_minimum" {
  command = plan
  variables {
    storage_size_in_gb = 0
  }
  expect_failures = [var.storage_size_in_gb]
}

run "reject_storage_outside_32_gib_increments" {
  command = plan
  variables {
    storage_size_in_gb = 48
  }
  expect_failures = [var.storage_size_in_gb]
}

run "reject_unsupported_license_type" {
  command = plan
  variables {
    license_type = "Unsupported"
  }
  expect_failures = [var.license_type]
}
