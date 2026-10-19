mock_provider "azurerm" {}

variables {
  name                   = "mysql-ha-test"
  database_name          = "appdb"
  resource_group_name    = "rg-ha-test"
  location               = "swedencentral"
  administrator_password = "Mock-Only-Password-123!"
  delegated_subnet_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ha-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/mysql"
  private_dns_zone_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ha-test/providers/Microsoft.Network/privateDnsZones/test.mysql.database.azure.com"
}

run "defaults_disable_ha" {
  command = plan
  assert {
    condition = (
      length(azurerm_mysql_flexible_server.this.high_availability) == 0 &&
      azurerm_mysql_flexible_server.this.sku_name == "B_Standard_B1ms" &&
      var.zone == null &&
      !azurerm_mysql_flexible_server.this.geo_redundant_backup_enabled &&
      azurerm_mysql_flexible_server.this.backup_retention_days == 7
    )
    error_message = "Defaults must preserve the non-HA Burstable server and backup settings."
  }
}

run "enabled_defaults_to_zone_redundant" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    high_availability = { enabled = true }
  }
  assert {
    condition     = azurerm_mysql_flexible_server.this.high_availability[0].mode == "ZoneRedundant"
    error_message = "Enabled HA must default to ZoneRedundant and allow Azure-selected zones."
  }
}

run "zone_redundant_explicit_zones" {
  command = plan
  variables {
    sku_name = "GP_Standard_D2ds_v4"
    zone     = "1"
    high_availability = {
      enabled                   = true
      standby_availability_zone = "2"
    }
  }
  assert {
    condition = (
      azurerm_mysql_flexible_server.this.zone == "1" &&
      azurerm_mysql_flexible_server.this.high_availability[0].mode == "ZoneRedundant" &&
      azurerm_mysql_flexible_server.this.high_availability[0].standby_availability_zone == "2"
    )
    error_message = "ZoneRedundant must pass distinct primary and standby zones through."
  }
}

run "same_zone_explicit_zones" {
  command = plan
  variables {
    sku_name = "GP_Standard_D2ds_v4"
    zone     = "1"
    high_availability = {
      enabled                   = true
      mode                      = "SameZone"
      standby_availability_zone = "1"
    }
  }
  assert {
    condition = (
      azurerm_mysql_flexible_server.this.zone == "1" &&
      azurerm_mysql_flexible_server.this.high_availability[0].mode == "SameZone" &&
      azurerm_mysql_flexible_server.this.high_availability[0].standby_availability_zone == "1"
    )
    error_message = "SameZone must pass matching primary and standby zones through."
  }
}

run "same_zone_azure_selected" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    high_availability = { enabled = true, mode = "SameZone" }
  }
}

run "only_primary_zone" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    zone              = "1"
    high_availability = { enabled = true }
  }
}

run "only_standby_zone" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    high_availability = { enabled = true, standby_availability_zone = "2" }
  }
}

run "disabled_ha_ignores_ha_only_constraints" {
  command = plan
  variables {
    zone = "1"
    high_availability = {
      mode                      = "SameZone"
      standby_availability_zone = "2"
    }
  }
  assert {
    condition     = length(azurerm_mysql_flexible_server.this.high_availability) == 0 && azurerm_mysql_flexible_server.this.zone == "1"
    error_message = "Disabled HA must omit its block and permit Burstable SKUs regardless of standby settings."
  }
}

run "reject_invalid_mode" {
  command = plan
  variables {
    high_availability = { mode = "Invalid" }
  }
  expect_failures = [var.high_availability]
}

run "reject_burstable_ha" {
  command = plan
  variables {
    high_availability = { enabled = true }
  }
  expect_failures = [var.high_availability]
}

run "reject_same_zone_mismatch" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    zone              = "1"
    high_availability = { enabled = true, mode = "SameZone", standby_availability_zone = "2" }
  }
  expect_failures = [var.high_availability]
}

run "reject_zone_redundant_matching_zones" {
  command = plan
  variables {
    sku_name          = "GP_Standard_D2ds_v4"
    zone              = "1"
    high_availability = { enabled = true, standby_availability_zone = "1" }
  }
  expect_failures = [var.high_availability]
}

run "reject_empty_administrator_login" {
  command = plan
  variables {
    administrator_login = " "
  }
  expect_failures = [var.administrator_login]
}

run "reject_empty_sku_name" {
  command = plan
  variables {
    sku_name = " "
  }
  expect_failures = [var.sku_name]
}

run "reject_empty_version_number" {
  command = plan
  variables {
    version_number = " "
  }
  expect_failures = [var.version_number]
}
