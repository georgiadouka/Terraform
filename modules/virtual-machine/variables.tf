variable "name" {
  description = "Virtual machine name."
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

variable "subnet_id" {
  description = "Subnet ID for the VM network interface."
  type        = string
}

variable "network_interface_name" {
  description = "Network interface name."
  type        = string
}

variable "os_disk_name" {
  description = "Operating system disk name."
  type        = string
}

variable "data_disk_names" {
  description = "Managed disk names keyed by the same logical labels as data_disks."
  type        = map(string)

  validation {
    condition = (
      toset(keys(var.data_disk_names)) == toset(keys(var.data_disks)) &&
      alltrue([for name in values(var.data_disk_names) : trimspace(name) != ""]) &&
      length(distinct([
        for name in values(var.data_disk_names) : lower(trimspace(name))
      ])) == length(var.data_disk_names)
    )
    error_message = "data_disk_names must contain exactly the same logical keys as data_disks and use nonempty, unique names."
  }
}

variable "size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s_v2"

  validation {
    condition     = trimspace(var.size) != ""
    error_message = "size must be nonempty."
  }
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "azureadmin"

  validation {
    condition     = trimspace(var.admin_username) != ""
    error_message = "admin_username must be nonempty."
  }
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key required for Linux administrator access."
  type        = string
  default     = null

  validation {
    condition     = var.os_type != "Linux" || try(trimspace(var.admin_ssh_public_key) != "", false)
    error_message = "admin_ssh_public_key must be nonempty for Linux virtual machines."
  }
}

variable "os_type" {
  description = "Virtual machine operating system: Linux or Windows."
  type        = string
  default     = "Linux"
  nullable    = false

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "admin_password" {
  description = "Administrator password required for Windows; generated and supplied by the caller."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.os_type != "Windows" || try(trimspace(var.admin_password) != "", false)
    error_message = "admin_password must be nonempty for Windows virtual machines."
  }
}

variable "computer_name" {
  description = "Optional Windows computer name, defaulting to name. Must contain 1-15 alphanumeric or hyphen characters and cannot be all numeric."
  type        = string
  default     = null

  validation {
    condition = var.os_type != "Windows" || try(
      can(regex("^[A-Za-z0-9-]{1,15}$", coalesce(var.computer_name, var.name))) &&
      !can(regex("^[0-9]+$", coalesce(var.computer_name, var.name))),
      false
    )
    error_message = "Windows computer_name (or name when omitted) must be 1-15 alphanumeric or hyphen characters and cannot be all numeric."
  }

  validation {
    condition     = var.computer_name == null ? true : trimspace(var.computer_name) != ""
    error_message = "computer_name must be nonempty when supplied."
  }
}

variable "os_disk" {
  description = "Operating system disk settings."
  type = object({
    caching              = optional(string, "ReadWrite")
    storage_account_type = optional(string, "StandardSSD_LRS")
    disk_size_gb         = optional(number)
  })
  default = {}

  validation {
    condition = (
      contains(["None", "ReadOnly", "ReadWrite"], var.os_disk.caching) &&
      trimspace(var.os_disk.storage_account_type) != "" &&
      (var.os_disk.disk_size_gb == null ? true : (
        var.os_disk.disk_size_gb >= 1 &&
        var.os_disk.disk_size_gb == floor(var.os_disk.disk_size_gb)
      ))
    )
    error_message = "os_disk requires valid caching, a storage account type, and a positive whole-number disk_size_gb."
  }

  validation {
    condition = (
      var.os_type != "Windows" || !local.uses_default_windows_image ||
      (var.os_disk.disk_size_gb == null ? true : var.os_disk.disk_size_gb >= 127)
    )
    error_message = "The default Windows Server 2022 Azure Edition image requires os_disk.disk_size_gb of at least 127 GB."
  }
}

variable "data_disks" {
  description = "Managed data disks keyed by a stable logical name."
  type = map(object({
    lun                  = number
    disk_size_gb         = number
    storage_account_type = optional(string, "StandardSSD_LRS")
    caching              = optional(string, "ReadWrite")
  }))
  default = {}

  validation {
    condition = (
      length(distinct([for disk in values(var.data_disks) : disk.lun])) == length(var.data_disks) &&
      alltrue([
        for label in keys(var.data_disks) :
        length(label) <= 20 &&
        can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", label)) &&
        !strcontains(label, "--")
      ]) &&
      alltrue([
        for disk in values(var.data_disks) :
        disk.lun >= 0 &&
        disk.lun == floor(disk.lun) &&
        disk.disk_size_gb >= 1 &&
        disk.disk_size_gb == floor(disk.disk_size_gb) &&
        trimspace(disk.storage_account_type) != "" &&
        contains(["None", "ReadOnly", "ReadWrite"], disk.caching)
      ])
    )
    error_message = "data_disks must use stable lowercase labels, unique non-negative whole-number LUNs, positive whole-number sizes, storage account types, and valid caching modes."
  }
}

variable "source_image_reference" {
  description = "Optional Marketplace image reference; defaults to Ubuntu 22.04 Gen2 for Linux or Windows Server 2022 Azure Edition for Windows."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = null

  validation {
    condition = var.source_image_reference == null ? true : alltrue([
      for field in values(var.source_image_reference) : try(trimspace(field) != "", false)
    ])
    error_message = "source_image_reference publisher, offer, sku, and version must all be nonempty."
  }
}

variable "tags" {
  description = "Tags applied to VM resources."
  type        = map(string)
  default     = {}
}

variable "load_balancer_backend_address_pool_ids" {
  description = "Load balancer backend pools the NIC's primary IP configuration joins, keyed by a stable logical name so the set of pools is known at plan time."
  type        = map(string)
  default     = {}
  nullable    = false
}
