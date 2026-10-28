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
        length(label) <= 63 &&
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
  description = "Azure file share names keyed by the same logical identifiers as file_shares. Names must be 3-63 lowercase letters, digits and hyphens, start and end with a letter or digit, and not contain consecutive hyphens."
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

  validation {
    condition = alltrue([
      for name in values(var.file_share_names) :
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", name)) && !strcontains(name, "--")
    ])
    error_message = "Every file share name must be 3-63 lowercase letters, digits and hyphens, start and end with a letter or digit, and not contain consecutive hyphens."
  }
}

variable "tags" {
  description = "Tags applied to premium file resources."
  type        = map(string)
  default     = {}
}
