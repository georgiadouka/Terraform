provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # This selects how Terraform authenticates to supported Storage Blob and Queue
  # data-plane APIs; it does not enable or disable account access keys. Entra
  # mode requires the Terraform identity to have pre-existing Storage data roles.
  # AzureRM 4.x still uses Shared Key for azurerm_storage_share.
  storage_use_azuread = var.storage_use_azuread

  # The AzureRM 4.x default ("legacy") registers about 70 resource providers on
  # every run, most of them unused here; on a new subscription this can fail
  # with 409 ConflictingConcurrentWriteNotAllowed while other registrations
  # are in progress. Only the core set and the providers of these modules are
  # registered instead.
  resource_provider_registrations = var.resource_provider_registrations
  resource_providers_to_register  = var.resource_providers_to_register

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true #for production turn into false
      recover_soft_deleted_key_vaults = true
    }

    # Azure adds a "Failure Anomalies - <name>" smart detector alert rule to
    # every new Application Insights resource. Terraform does not manage it; if
    # it outlives the resource it blocks deleting the resource group (seen in
    # the 2026-10-29 live test). With this setting the provider disables the
    # rule on create and deletes it on destroy.
    application_insights {
      disable_generated_rule = true
    }

    # Soft delete cannot be turned off on Recovery Services vaults, so deleted
    # VM backups stay in the vault for 14 days. Destroying a protected VM
    # deletes its backup data (instead of stopping protection and retaining
    # it), and destroying the vault first deletes the backup items still in
    # it, so lab environments can be torn down. Production should keep its
    # backups.
    recovery_service {
      vm_backup_stop_protection_and_retain_data_on_destroy = false #for production turn into true
      purge_protected_items_from_vault_on_destroy          = true  #for production turn into false
    }

    # Re-enabling backup of a VM whose backup was deleted within the soft
    # delete period resumes the soft-deleted item instead of failing.
    recovery_services_vaults {
      recover_soft_deleted_backup_protected_vm = true
    }
  }
}

# Manages only the hub-to-spoke peering on the hub VNet, which usually lives in
# a separate connectivity subscription. Resource provider registration is
# skipped because the identity may hold only network rights there.
provider "azurerm" {
  alias           = "hub"
  subscription_id = try(local.hub_virtual_network.subscription_id, var.subscription_id)
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"

  features {}
}
