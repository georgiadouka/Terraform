provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # This selects how Terraform authenticates to supported Storage Blob and Queue
  # data-plane APIs; it does not enable or disable account access keys. Entra
  # mode requires the Terraform identity to have pre-existing Storage data roles.
  # AzureRM 4.x still uses Shared Key for azurerm_storage_share.
  storage_use_azuread = var.storage_use_azuread

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
