variable "name" {
  description = "Storage account name."
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
  description = "Storage replication type."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], upper(var.replication_type))
    error_message = "replication_type must be LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  }
}

variable "containers" {
  description = "Blob container names keyed by stable logical identifiers."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for label in keys(var.containers) :
      length(label) <= 20 &&
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", label)) &&
      !strcontains(label, "--")
    ])
    error_message = "containers must use stable lowercase logical labels of 1-20 letters, digits, or hyphens without consecutive hyphens."
  }
}

variable "file_shares" {
  description = "Standard SMB file shares keyed by stable logical identifiers."
  type = map(object({
    quota_gb    = optional(number, 100)
    access_tier = optional(string, "TransactionOptimized")
  }))
  default = {}

  validation {
    condition     = var.shared_access_key_enabled || length(var.file_shares) == 0
    error_message = "file_shares must be empty when shared_access_key_enabled is false because AzureRM 4.x manages Azure Files with Shared Key. Use Blob containers only, enable Shared Key where policy permits, or migrate file-share provisioning to the ARM control plane."
  }

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
        share.quota_gb > 0 &&
        share.quota_gb == floor(share.quota_gb) &&
        contains(["Cool", "Hot", "TransactionOptimized"], share.access_tier)
      ])
    )
    error_message = "file_shares must use stable lowercase logical labels, positive whole-number quotas, and Cool, Hot, or TransactionOptimized access tiers."
  }
}

variable "file_share_names" {
  description = "Azure file share names keyed by the same logical identifiers as file_shares."
  type        = map(string)
  default     = {}

  validation {
    condition     = toset(keys(var.file_share_names)) == toset(keys(var.file_shares))
    error_message = "file_share_names must contain exactly the same logical keys as file_shares."
  }
}

variable "shared_access_key_enabled" {
  description = "Whether clients may authorize Storage requests with account access keys. This does not select how the AzureRM provider authenticates."
  type        = bool
  default     = false
}

variable "data_plane_role_assignments" {
  description = "Account-scoped Storage data-plane roles for workload identities. The identity running Terraform must be granted its own data-plane roles before this module runs."
  type = map(object({
    principal_id                     = string
    role_definition_name             = string
    principal_type                   = optional(string)
    description                      = optional(string)
    skip_service_principal_aad_check = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for assignment in values(var.data_plane_role_assignments) :
      trimspace(assignment.principal_id) != "" &&
      trimspace(assignment.role_definition_name) != "" &&
      (
        assignment.principal_type == null ||
        contains(["User", "Group", "ServicePrincipal"], assignment.principal_type)
      )
    ])
    error_message = "Each data-plane role assignment requires non-empty principal_id and role_definition_name values; principal_type, when set, must be User, Group, or ServicePrincipal."
  }
}

variable "tags" {
  description = "Tags applied to storage resources."
  type        = map(string)
  default     = {}
}
