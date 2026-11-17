locals {
  policies = {
    for key, policy in var.policies : key => merge(policy, {
      instant_restore_retention_days = coalesce(policy.instant_restore_retention_days, policy.frequency == "Weekly" ? 5 : 7)
      retention_daily                = policy.frequency == "Weekly" ? null : coalesce(policy.retention_daily, 30)
    })
  }
}

# Soft delete is always on for Recovery Services vaults (Azure secure by
# default), so deleted backup items stay recoverable for 14 days.
resource "azurerm_recovery_services_vault" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Standard"
  storage_mode_type             = var.storage_mode_type
  cross_region_restore_enabled  = var.cross_region_restore_enabled
  public_network_access_enabled = var.public_network_access_enabled
  immutability                  = var.immutability
  tags                          = var.tags
}

resource "azurerm_backup_policy_vm" "this" {
  for_each = local.policies

  name                = each.value.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  # Enhanced policy: the only policy type that can protect Trusted Launch VMs,
  # which the virtual-machine module always creates.
  policy_type                    = "V2"
  timezone                       = each.value.timezone
  instant_restore_retention_days = each.value.instant_restore_retention_days

  backup {
    frequency     = each.value.frequency
    time          = each.value.time
    hour_interval = each.value.frequency == "Hourly" ? each.value.hour_interval : null
    hour_duration = each.value.frequency == "Hourly" ? each.value.hour_duration : null
    weekdays      = each.value.frequency == "Weekly" ? each.value.weekdays : null
  }

  dynamic "retention_daily" {
    for_each = each.value.retention_daily == null ? [] : [each.value.retention_daily]

    content {
      count = retention_daily.value
    }
  }

  dynamic "retention_weekly" {
    for_each = each.value.retention_weekly == null ? [] : [each.value.retention_weekly]

    content {
      count    = retention_weekly.value.count
      weekdays = retention_weekly.value.weekdays
    }
  }

  dynamic "retention_monthly" {
    for_each = each.value.retention_monthly == null ? [] : [each.value.retention_monthly]

    content {
      count    = retention_monthly.value.count
      weekdays = length(retention_monthly.value.weekdays) > 0 ? retention_monthly.value.weekdays : null
      weeks    = length(retention_monthly.value.weeks) > 0 ? retention_monthly.value.weeks : null
      days     = length(retention_monthly.value.days) > 0 ? retention_monthly.value.days : null
      # Conflicts with weeks/weekdays even when false, so it is sent only when true.
      include_last_days = retention_monthly.value.include_last_days ? true : null
    }
  }

  dynamic "retention_yearly" {
    for_each = each.value.retention_yearly == null ? [] : [each.value.retention_yearly]

    content {
      count             = retention_yearly.value.count
      months            = retention_yearly.value.months
      weekdays          = length(retention_yearly.value.weekdays) > 0 ? retention_yearly.value.weekdays : null
      weeks             = length(retention_yearly.value.weeks) > 0 ? retention_yearly.value.weeks : null
      days              = length(retention_yearly.value.days) > 0 ? retention_yearly.value.days : null
      include_last_days = retention_yearly.value.include_last_days ? true : null
    }
  }
}

resource "azurerm_backup_protected_vm" "this" {
  for_each = var.protected_virtual_machines

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = each.value.id
  backup_policy_id    = azurerm_backup_policy_vm.this[each.value.policy].id
}
