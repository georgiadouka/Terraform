variable "name" {
  description = "Virtual Machine Scale Set name."
  type        = string

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.name) != ""
  #   error_message = "name must be nonempty."
  # }
}

variable "autoscale_setting_name" {
  description = "Azure Monitor autoscale setting name."
  type        = string

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.autoscale_setting_name) != ""
  #   error_message = "autoscale_setting_name must be nonempty."
  # }
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
  description = "Subnet ID used by every VMSS instance."
  type        = string
}

variable "network_interface_name" {
  description = "Name of the VMSS network interface configuration."
  type        = string
}

variable "size" {
  description = "Azure VM SKU used by every VMSS instance."
  type        = string
  default     = "Standard_B2s_v2"

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.size) != ""
  #   error_message = "size must be nonempty."
  # }
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "azureadmin"

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition     = trimspace(var.admin_username) != ""
  #   error_message = "admin_username must be nonempty."
  # }
}

variable "admin_ssh_public_key" {
  description = "Optional OpenSSH public key for Linux administrator access. A Linux scale set needs admin_ssh_public_key, admin_password, or both."
  type        = string
  default     = null

  validation {
    condition = var.os_type != "Linux" || (
      try(trimspace(var.admin_ssh_public_key) != "", false) ||
      try(trimspace(var.admin_password) != "", false)
    )
    error_message = "A Linux scale set needs a nonempty admin_ssh_public_key, admin_password, or both."
  }
}

variable "os_type" {
  description = "Scale set operating system: Linux or Windows."
  type        = string
  default     = "Linux"
  nullable    = false

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "admin_password" {
  description = "Administrator password: required for Windows, optional for Linux (enables password sign-in). Supplied by the caller."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.os_type != "Windows" || try(trimspace(var.admin_password) != "", false)
    error_message = "admin_password must be nonempty for Windows scale sets."
  }
}

variable "computer_name_prefix" {
  description = "Hostname prefix for scale set instances: up to 9 characters for Windows or 58 for Linux. Null uses the scale set name, which Windows accepts only when the name is at most 9 characters."
  type        = string
  default     = null

  validation {
    condition = (
      var.computer_name_prefix == null
      ? var.os_type != "Windows" || length(var.name) <= 9
      : can(regex("^[A-Za-z][A-Za-z0-9-]*$", var.computer_name_prefix)) &&
      length(var.computer_name_prefix) <= (var.os_type == "Windows" ? 9 : 58)
    )
    error_message = "computer_name_prefix must start with a letter, contain only letters, digits, or hyphens, and be at most 9 characters for Windows or 58 for Linux. Windows scale sets whose name is longer than 9 characters require an explicit prefix."
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

  # Disabled: azurerm rejects empty values at plan time.
  # validation {
  #   condition = var.source_image_reference == null ? true : alltrue([
  #     for field in values(var.source_image_reference) : try(trimspace(field) != "", false)
  #   ])
  #   error_message = "source_image_reference publisher, offer, sku, and version must all be nonempty."
  # }
}

variable "os_disk" {
  description = "Operating system disk settings applied to every VMSS instance."
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
    error_message = "The default Windows Server 2022 Azure Edition image requires os_disk.disk_size_gb of at least 127 GiB."
  }
}

variable "data_disks" {
  description = "Per-instance data disk templates keyed by a stable logical label."
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

variable "scaling" {
  description = "Azure Monitor capacity mode. Fixed mode uses default_instances for every bound; autoscale mode applies bounded CPU rules."
  type = object({
    mode              = optional(string, "fixed")
    minimum_instances = optional(number, 1)
    default_instances = optional(number, 2)
    maximum_instances = optional(number, 5)
    cpu = optional(object({
      scale_out_threshold = optional(number, 75)
      scale_in_threshold  = optional(number, 25)
      scale_out_count     = optional(number, 1)
      scale_in_count      = optional(number, 1)
      time_window_minutes = optional(number, 5)
      cooldown_minutes    = optional(number, 5)
    }), {})
  })
  default = {}

  validation {
    condition = (
      contains(["fixed", "autoscale"], var.scaling.mode) &&
      var.scaling.default_instances >= 1 &&
      var.scaling.default_instances == floor(var.scaling.default_instances) &&
      (
        var.scaling.mode == "fixed" ||
        (
          var.scaling.minimum_instances >= 1 &&
          var.scaling.minimum_instances == floor(var.scaling.minimum_instances) &&
          var.scaling.maximum_instances >= 1 &&
          var.scaling.maximum_instances == floor(var.scaling.maximum_instances) &&
          var.scaling.minimum_instances <= var.scaling.default_instances &&
          var.scaling.default_instances <= var.scaling.maximum_instances
        )
      )
    )
    error_message = "scaling requires fixed or autoscale mode, a positive whole-number default, and autoscale bounds satisfying minimum <= default <= maximum."
  }

  validation {
    condition = (
      var.scaling.cpu.scale_in_threshold >= 0 &&
      var.scaling.cpu.scale_out_threshold <= 100 &&
      var.scaling.cpu.scale_in_threshold < var.scaling.cpu.scale_out_threshold &&
      var.scaling.cpu.scale_out_count >= 1 &&
      var.scaling.cpu.scale_out_count == floor(var.scaling.cpu.scale_out_count) &&
      var.scaling.cpu.scale_in_count >= 1 &&
      var.scaling.cpu.scale_in_count == floor(var.scaling.cpu.scale_in_count) &&
      var.scaling.cpu.time_window_minutes >= 5 &&
      var.scaling.cpu.time_window_minutes <= 60 &&
      var.scaling.cpu.time_window_minutes == floor(var.scaling.cpu.time_window_minutes) &&
      var.scaling.cpu.cooldown_minutes >= 1 &&
      var.scaling.cpu.cooldown_minutes <= 120 &&
      var.scaling.cpu.cooldown_minutes == floor(var.scaling.cpu.cooldown_minutes)
    )
    error_message = "scaling.cpu requires non-overlapping 0-100 thresholds, positive whole-number change counts, a 5-60 minute window, and a 1-120 minute cooldown."
  }
}

variable "zones" {
  description = "Optional availability zones used by the scale set."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "zones may contain only 1, 2, or 3."
  }
}

variable "upgrade_mode" {
  description = "VMSS model upgrade mode. Rolling is deferred until a workload health contract is available."
  type        = string
  default     = "Manual"

  # Disabled: azurerm validates this at plan time.
  # validation {
  #   condition     = contains(["Manual", "Automatic"], var.upgrade_mode)
  #   error_message = "upgrade_mode must be Manual or Automatic."
  # }
}

variable "load_balancer_backend_address_pool_ids" {
  description = "Optional Load Balancer backend pools joined by every VMSS instance."
  type        = set(string)
  default     = []
}

variable "application_gateway_backend_address_pool_ids" {
  description = "Optional Application Gateway backend pools joined by every VMSS instance."
  type        = set(string)
  default     = []
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking when supported by the selected VM SKU."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the VMSS and autoscale setting."
  type        = map(string)
  default     = {}
}
