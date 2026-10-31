# VM backup module: vault defaults, Enhanced policy schedules and retention,
# protected VM wiring and input validation.

mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_recovery_services_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.RecoveryServices/vaults/rsv-test"
    }
  }
  mock_resource "azurerm_backup_policy_vm" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/default"
    }
  }
  mock_resource "azurerm_backup_protected_vm" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;rg-backup-test;vm-app/protectedItems/vm;iaasvmcontainerv2;rg-backup-test;vm-app"
    }
  }
}

variables {
  name                = "rsv-test"
  resource_group_name = "rg-backup-test"
  location            = "swedencentral"
  policies = {
    default = { name = "default" }
  }
  protected_virtual_machines = {
    app = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.Compute/virtualMachines/vm-app"
      policy = "default"
    }
  }
}

run "defaults" {
  command = plan

  assert {
    condition = (
      azurerm_recovery_services_vault.this.sku == "Standard" &&
      azurerm_recovery_services_vault.this.storage_mode_type == "ZoneRedundant" &&
      !azurerm_recovery_services_vault.this.cross_region_restore_enabled &&
      !azurerm_recovery_services_vault.this.public_network_access_enabled
    )
    error_message = "The vault must default to Standard, zone-redundant storage, no cross-region restore and no public network access."
  }
  assert {
    condition = (
      azurerm_backup_policy_vm.this["default"].policy_type == "V2" &&
      azurerm_backup_policy_vm.this["default"].timezone == "UTC" &&
      azurerm_backup_policy_vm.this["default"].instant_restore_retention_days == 7 &&
      one(azurerm_backup_policy_vm.this["default"].backup).frequency == "Daily" &&
      one(azurerm_backup_policy_vm.this["default"].backup).time == "23:00" &&
      one(azurerm_backup_policy_vm.this["default"].retention_daily).count == 30 &&
      length(azurerm_backup_policy_vm.this["default"].retention_weekly) == 0
    )
    error_message = "The default policy must be an Enhanced daily 23:00 UTC backup with 7 days of snapshots and 30 daily recovery points."
  }
  assert {
    condition = (
      azurerm_backup_protected_vm.this["app"].source_vm_id == var.protected_virtual_machines.app.id &&
      azurerm_backup_protected_vm.this["app"].backup_policy_id == azurerm_backup_policy_vm.this["default"].id &&
      azurerm_backup_protected_vm.this["app"].recovery_vault_name == "rsv-test" &&
      output.protected_item_ids["app"] == azurerm_backup_protected_vm.this["app"].id &&
      output.policy_ids["default"] == azurerm_backup_policy_vm.this["default"].id
    )
    error_message = "Protected VMs must use the vault and the selected policy, and the outputs must expose their IDs."
  }
}

run "no_protected_vms" {
  command = plan

  variables {
    protected_virtual_machines = {}
  }

  assert {
    condition     = length(azurerm_backup_protected_vm.this) == 0 && length(azurerm_backup_policy_vm.this) == 1
    error_message = "Without protected VMs the vault and its policies must still be created, with no protected items."
  }
}

run "geo_redundant_with_cross_region_restore" {
  command = plan

  variables {
    storage_mode_type             = "GeoRedundant"
    cross_region_restore_enabled  = true
    public_network_access_enabled = true
    immutability                  = "Unlocked"
  }

  assert {
    condition = (
      azurerm_recovery_services_vault.this.storage_mode_type == "GeoRedundant" &&
      azurerm_recovery_services_vault.this.cross_region_restore_enabled &&
      azurerm_recovery_services_vault.this.public_network_access_enabled &&
      azurerm_recovery_services_vault.this.immutability == "Unlocked"
    )
    error_message = "Vault settings must be passed through."
  }
}

run "hourly_weekly_and_long_term_retention" {
  command = plan

  # A distinct ID proves the protected VM uses the policy it selects.
  override_resource {
    target          = azurerm_backup_policy_vm.this["hourly"]
    override_during = plan
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/hourly"
    }
  }

  variables {
    policies = {
      default = { name = "default" }
      hourly = {
        name                           = "hourly"
        timezone                       = "W. Europe Standard Time"
        frequency                      = "Hourly"
        time                           = "08:00"
        hour_interval                  = 4
        hour_duration                  = 12
        instant_restore_retention_days = 14
        retention_daily                = 60
        retention_monthly = {
          count = 12
          days  = [1, 15]
        }
        retention_yearly = {
          count    = 7
          months   = ["January"]
          weekdays = ["Sunday"]
          weeks    = ["First"]
        }
      }
      weekly = {
        name      = "weekly"
        frequency = "Weekly"
        time      = "22:30"
        weekdays  = ["Saturday"]
        retention_weekly = {
          count    = 12
          weekdays = ["Saturday"]
        }
      }
    }
    protected_virtual_machines = {
      app = {
        id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.Compute/virtualMachines/vm-app"
        policy = "hourly"
      }
    }
  }

  assert {
    condition = (
      one(azurerm_backup_policy_vm.this["hourly"].backup).frequency == "Hourly" &&
      one(azurerm_backup_policy_vm.this["hourly"].backup).hour_interval == 4 &&
      one(azurerm_backup_policy_vm.this["hourly"].backup).hour_duration == 12 &&
      azurerm_backup_policy_vm.this["hourly"].instant_restore_retention_days == 14 &&
      one(azurerm_backup_policy_vm.this["hourly"].retention_daily).count == 60 &&
      one(azurerm_backup_policy_vm.this["hourly"].retention_monthly).count == 12 &&
      one(azurerm_backup_policy_vm.this["hourly"].retention_monthly).days == toset([1, 15]) &&
      one(azurerm_backup_policy_vm.this["hourly"].retention_yearly).months == toset(["January"]) &&
      one(azurerm_backup_policy_vm.this["hourly"].retention_yearly).weeks == toset(["First"])
    )
    error_message = "Hourly policies must keep their interval, window, snapshot and long-term retention."
  }
  assert {
    condition = (
      one(azurerm_backup_policy_vm.this["weekly"].backup).frequency == "Weekly" &&
      one(azurerm_backup_policy_vm.this["weekly"].backup).weekdays == toset(["Saturday"]) &&
      azurerm_backup_policy_vm.this["weekly"].instant_restore_retention_days == 5 &&
      length(azurerm_backup_policy_vm.this["weekly"].retention_daily) == 0 &&
      one(azurerm_backup_policy_vm.this["weekly"].retention_weekly).count == 12
    )
    error_message = "Weekly policies must use 5 days of snapshots, weekly retention and no daily retention."
  }
  assert {
    condition     = azurerm_backup_protected_vm.this["app"].backup_policy_id == azurerm_backup_policy_vm.this["hourly"].id
    error_message = "A protected VM must use the policy it selects."
  }
}

run "reject_unknown_policy" {
  command = plan

  variables {
    protected_virtual_machines = {
      app = {
        id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-backup-test/providers/Microsoft.Compute/virtualMachines/vm-app"
        policy = "missing"
      }
    }
  }

  expect_failures = [var.protected_virtual_machines]
}

run "reject_cross_region_restore_without_geo_redundancy" {
  command = plan

  variables {
    cross_region_restore_enabled = true
  }

  expect_failures = [var.cross_region_restore_enabled]
}

run "reject_invalid_storage_mode" {
  command = plan

  variables {
    storage_mode_type = "GRS"
  }

  expect_failures = [var.storage_mode_type]
}

run "reject_invalid_immutability" {
  command = plan

  variables {
    immutability = "On"
  }

  expect_failures = [var.immutability]
}

run "reject_off_schedule_time" {
  command = plan

  variables {
    policies = {
      default = { name = "default", time = "23:15" }
    }
  }

  expect_failures = [var.policies]
}

run "reject_hourly_without_interval" {
  command = plan

  variables {
    policies = {
      default = { name = "default", frequency = "Hourly" }
    }
  }

  expect_failures = [var.policies]
}

run "reject_hourly_duration_not_multiple_of_interval" {
  command = plan

  variables {
    policies = {
      default = { name = "default", frequency = "Hourly", hour_interval = 8, hour_duration = 12 }
    }
  }

  expect_failures = [var.policies]
}

run "reject_weekly_without_weekly_retention" {
  command = plan

  variables {
    policies = {
      default = { name = "default", frequency = "Weekly", weekdays = ["Sunday"] }
    }
  }

  expect_failures = [var.policies]
}

run "reject_weekly_snapshot_retention_other_than_five" {
  command = plan

  variables {
    policies = {
      default = {
        name                           = "default"
        frequency                      = "Weekly"
        weekdays                       = ["Sunday"]
        instant_restore_retention_days = 7
        retention_weekly               = { count = 4, weekdays = ["Sunday"] }
      }
    }
  }

  expect_failures = [var.policies]
}

run "reject_short_daily_retention" {
  command = plan

  variables {
    policies = {
      default = { name = "default", retention_daily = 3 }
    }
  }

  expect_failures = [var.policies]
}

run "reject_snapshot_retention_above_thirty_days" {
  command = plan

  variables {
    policies = {
      default = { name = "default", instant_restore_retention_days = 31 }
    }
  }

  expect_failures = [var.policies]
}

run "reject_invalid_weekday" {
  command = plan

  variables {
    policies = {
      default = {
        name             = "default"
        retention_weekly = { count = 4, weekdays = ["Sun"] }
      }
    }
  }

  expect_failures = [var.policies]
}

run "reject_monthly_retention_mixing_days_and_weeks" {
  command = plan

  variables {
    policies = {
      default = {
        name              = "default"
        retention_monthly = { count = 6, days = [1], weekdays = ["Sunday"], weeks = ["First"] }
      }
    }
  }

  expect_failures = [var.policies]
}

run "reject_yearly_retention_without_months" {
  command = plan

  variables {
    policies = {
      default = {
        name             = "default"
        retention_yearly = { count = 1, months = [], include_last_days = true }
      }
    }
  }

  expect_failures = [var.policies]
}
