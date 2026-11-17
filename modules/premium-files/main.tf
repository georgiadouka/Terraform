resource "azurerm_storage_account" "this" {
  name                             = var.name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  account_tier                     = "Premium"
  account_replication_type         = var.replication_type
  account_kind                     = "FileStorage"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  public_network_access_enabled    = false
  shared_access_key_enabled        = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  tags                             = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  share_properties {
    smb {
      multichannel_enabled = true
    }

    retention_policy {
      days = 7
    }
  }

  lifecycle {
    # Microsoft Defender for Storage adds a resource instance rule for its data
    # scanner; this module manages no such rules, so leave them to Azure.
    ignore_changes = [network_rules[0].private_link_access]
  }
}

resource "azurerm_storage_share" "this" {
  for_each = var.file_shares

  name               = var.file_share_names[each.key]
  storage_account_id = azurerm_storage_account.this.id
  quota              = each.value.quota_gb
  access_tier        = "Premium"
  enabled_protocol   = "SMB"
}
