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
  }
}
