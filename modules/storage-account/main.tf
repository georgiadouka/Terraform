resource "azurerm_storage_account" "this" {
  name                             = var.name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  account_tier                     = "Standard"
  account_replication_type         = var.replication_type
  account_kind                     = "StorageV2"
  access_tier                      = "Hot"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  public_network_access_enabled    = false
  shared_access_key_enabled        = var.shared_access_key_enabled
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  tags                             = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  share_properties {
    retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  lifecycle {
    # Microsoft Defender for Storage adds a resource instance rule for its data
    # scanner; this module manages no such rules, so leave them to Azure.
    ignore_changes = [network_rules[0].private_link_access]
  }
}

resource "azurerm_role_assignment" "data_plane" {
  for_each = var.data_plane_role_assignments

  scope                            = azurerm_storage_account.this.id
  role_definition_name             = each.value.role_definition_name
  principal_id                     = each.value.principal_id
  principal_type                   = each.value.principal_type
  description                      = each.value.description
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
}

resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_share" "this" {
  for_each = var.file_shares

  name               = var.file_share_names[each.key]
  storage_account_id = azurerm_storage_account.this.id
  quota              = each.value.quota_gb
  access_tier        = each.value.access_tier
  enabled_protocol   = "SMB"
}
