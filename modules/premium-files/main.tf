variable "name" {
  description = "Premium FileStorage account name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "replication_type" {
  description = "Premium storage replication type."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS"], upper(var.replication_type))
    error_message = "replication_type must be LRS or ZRS."
  }
}

variable "file_shares" {
  description = "Premium SMB file shares keyed by stable logical identifiers."
  type = map(object({
    quota_gb = number
  }))

  validation {
    condition = (
      alltrue([
        for label in keys(var.file_shares) :
        length(label) <= 20 &&
        can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", label)) &&
        !strcontains(label, "--")
      ]) &&
      alltrue([
        for share in values(var.file_shares) :
        share.quota_gb >= 100 &&
        share.quota_gb == floor(share.quota_gb)
      ])
    )
    error_message = "file_shares must use stable lowercase labels and whole-number quotas of at least 100 GiB."
  }
}

variable "file_share_names" {
  description = "Azure file share names keyed by the same logical identifiers as file_shares."
  type        = map(string)

  validation {
    condition = (
      toset(keys(var.file_share_names)) == toset(keys(var.file_shares)) &&
      alltrue([for name in values(var.file_share_names) : trimspace(name) != ""]) &&
      length(distinct([
        for name in values(var.file_share_names) : lower(trimspace(name))
      ])) == length(var.file_share_names)
    )
    error_message = "file_share_names must contain exactly the same logical keys as file_shares and use nonempty, unique names."
  }
}

variable "tags" {
  description = "Tags applied to premium file resources."
  type        = map(string)
  default     = {}
}

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
}

resource "azurerm_storage_share" "this" {
  for_each = var.file_shares

  name               = var.file_share_names[each.key]
  storage_account_id = azurerm_storage_account.this.id
  quota              = each.value.quota_gb
  access_tier        = "Premium"
  enabled_protocol   = "SMB"
}

output "id" {
  description = "Premium FileStorage account ID."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Premium FileStorage account name."
  value       = azurerm_storage_account.this.name
}

output "file_share_ids" {
  description = "Premium file share IDs keyed by logical identifier."
  value       = { for key, share in azurerm_storage_share.this : key => share.id }
}
