# VM backup: one shared M-AZU-RSV vault, every VM backed up by default with
# the "default" policy, per-VM opt-out and policy choice, the global switch,
# and validation of policy references.

# The azurerm.hub alias is configured even when hub_peering is unset.
mock_provider "azurerm" {
  alias = "hub"
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}

override_module {
  target = module.network
  outputs = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    subnet_ids = {
      virtual_machines = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vms"
    }
  }
}

override_module {
  target = module.virtual_machine["app"]
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-app"
    name               = "vm-app"
    private_ip_address = "10.42.1.4"
    data_disk_ids      = {}
  }
}

override_module {
  target = module.virtual_machine["db"]
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-db"
    name               = "vm-db"
    private_ip_address = "10.42.1.5"
    data_disk_ids      = {}
  }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  location                = "swedencentral"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
      subnets = {
        virtual_machines = { cidr = "10.42.1.0/24", number = 2 }
      }
    }
  }
  virtual_machines = {
    app = {}
    db  = { os_type = "Windows" }
  }
  vm_backup                   = {}
  virtual_machine_scale_sets  = {}
  application_insights        = {}
  log_analytics_workspace     = {}
  storage_accounts            = {}
  premium_file_accounts       = {}
  storage_use_azuread         = true
  container_apps_environments = {}
  load_balancers              = {}
  key_vaults                  = {}
  container_registries        = {}
  azure_sql_servers           = {}
  cosmos_db_accounts          = {}
  sql_managed_instances       = {}
  postgresql_servers          = {}
  mysql_servers               = {}
  databricks_workspaces       = {}
  app_service_plans           = {}
  function_apps               = {}
  logic_apps                  = {}
  web_apps                    = {}
  hub_peering                 = null
  tags                        = {}
}

run "every_vm_backed_up_by_default" {
  command = plan

  assert {
    condition = (
      length(module.vm_backup) == 1 &&
      output.generated_resource_names.recovery_services_vault == "M-AZU-RSV-IT-PPA-ECM-DEV-SWE-00" &&
      output.generated_resource_names.vm_backup_policies == { default = "default" } &&
      output.vm_backup.name == "M-AZU-RSV-IT-PPA-ECM-DEV-SWE-00" &&
      output.vm_backup.virtual_machines == tolist(["app", "db"]) &&
      toset(keys(output.vm_backup.policy_ids)) == toset(["default"]) &&
      toset(keys(module.vm_backup[0].protected_item_ids)) == toset(["app", "db"]) &&
      output.virtual_machines["app"].backup_policy == "default" &&
      output.virtual_machines["db"].backup_policy == "default"
    )
    error_message = "Every VM must be backed up with the default policy to one shared M-AZU-RSV vault."
  }
}

run "sequence_sets_nn" {
  command = plan

  variables {
    vm_backup = { sequence = "04" }
  }

  assert {
    condition     = output.vm_backup.name == "M-AZU-RSV-IT-PPA-ECM-DEV-SWE-04"
    error_message = "vm_backup.sequence must set the NN."
  }
}

run "opt_out_per_vm" {
  command = plan

  variables {
    virtual_machines = {
      app = {}
      db  = { os_type = "Windows", backup = false }
    }
  }

  assert {
    condition = (
      output.vm_backup.virtual_machines == tolist(["app"]) &&
      toset(keys(module.vm_backup[0].protected_item_ids)) == toset(["app"]) &&
      output.virtual_machines["app"].backup_policy == "default" &&
      output.virtual_machines["db"].backup_policy == null
    )
    error_message = "A VM with backup = false must not be protected."
  }
}

run "no_vault_when_every_vm_opts_out" {
  command = plan

  variables {
    virtual_machines = {
      app = { backup = false }
      db  = { os_type = "Windows", backup = false }
    }
  }

  assert {
    condition     = length(module.vm_backup) == 0 && output.vm_backup == null
    error_message = "Without a backed-up VM no vault may be created."
  }
}

run "global_switch_turns_backup_off" {
  command = plan

  variables {
    vm_backup = { enabled = false }
  }

  assert {
    condition = (
      length(module.vm_backup) == 0 &&
      output.vm_backup == null &&
      output.virtual_machines["app"].backup_policy == null &&
      output.virtual_machines["db"].backup_policy == null
    )
    error_message = "vm_backup.enabled = false must turn backup off for every VM."
  }
}

run "vms_select_their_policy" {
  command = plan

  variables {
    vm_backup = {
      storage_mode_type = "GeoRedundant"
      policies = {
        default = {}
        critical = {
          frequency                      = "Hourly"
          hour_interval                  = 4
          hour_duration                  = 24
          instant_restore_retention_days = 14
          retention_daily                = 90
          retention_monthly              = { count = 12, days = [1] }
        }
      }
    }
    virtual_machines = {
      app = {}
      db  = { os_type = "Windows", backup_policy = "critical" }
    }
  }

  assert {
    condition = (
      toset(keys(output.vm_backup.policy_ids)) == toset(["critical", "default"]) &&
      output.generated_resource_names.vm_backup_policies == { critical = "critical", default = "default" } &&
      output.virtual_machines["app"].backup_policy == "default" &&
      output.virtual_machines["db"].backup_policy == "critical"
    )
    error_message = "Each VM must use the policy it selects, and every policy must be created in the vault with its key as name."
  }
}

run "reject_unknown_policy" {
  command = plan

  variables {
    virtual_machines = {
      app = { backup_policy = "missing" }
      db  = { os_type = "Windows" }
    }
  }

  expect_failures = [var.virtual_machines]
}

run "reject_policies_without_default_used_by_a_vm" {
  command = plan

  variables {
    vm_backup = {
      policies = { daily = {} }
    }
  }

  expect_failures = [var.virtual_machines]
}

run "opted_out_vm_needs_no_valid_policy" {
  command = plan

  variables {
    vm_backup = {
      policies = { daily = {} }
    }
    virtual_machines = {
      app = { backup_policy = "daily" }
      db  = { os_type = "Windows", backup = false }
    }
  }

  assert {
    condition     = output.vm_backup.virtual_machines == tolist(["app"])
    error_message = "Only backed-up VMs need a valid backup_policy."
  }
}

run "reject_invalid_sequence" {
  command = plan

  variables {
    vm_backup = { sequence = "4" }
  }

  expect_failures = [var.vm_backup]
}

run "reject_invalid_policy_key" {
  command = plan

  variables {
    vm_backup = {
      policies = { Default = {} }
    }
    virtual_machines = {
      app = { backup_policy = "Default" }
      db  = { os_type = "Windows", backup_policy = "Default" }
    }
  }

  expect_failures = [var.vm_backup]
}

run "reject_empty_policies" {
  command = plan

  variables {
    vm_backup = { policies = {} }
    virtual_machines = {
      app = { backup = false }
      db  = { os_type = "Windows", backup = false }
    }
  }

  expect_failures = [var.vm_backup]
}
