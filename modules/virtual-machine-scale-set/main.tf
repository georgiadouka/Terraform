terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "name" {
  description = "Virtual Machine Scale Set name."
  type        = string

  validation {
    condition     = trimspace(var.name) != ""
    error_message = "name must be nonempty."
  }
}

variable "autoscale_setting_name" {
  description = "Azure Monitor autoscale setting name."
  type        = string

  validation {
    condition     = trimspace(var.autoscale_setting_name) != ""
    error_message = "autoscale_setting_name must be nonempty."
  }
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
    error_message = "admin_ssh_public_key must be nonempty for Linux scale sets."
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
  description = "Administrator password required for Windows; generated and supplied by the caller."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.os_type != "Windows" || try(trimspace(var.admin_password) != "", false)
    error_message = "admin_password must be nonempty for Windows scale sets."
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

  validation {
    condition     = contains(["Manual", "Automatic"], var.upgrade_mode)
    error_message = "upgrade_mode must be Manual or Automatic."
  }
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

locals {
  default_linux_image = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  default_windows_image = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  source_image_reference = var.source_image_reference != null ? var.source_image_reference : (
    var.os_type == "Windows" ? local.default_windows_image : local.default_linux_image
  )
  uses_default_windows_image = alltrue([
    for field in ["publisher", "offer", "sku"] :
    try(lower(local.source_image_reference[field]) == lower(local.default_windows_image[field]), false)
  ])
  os_disk_size_gb = coalesce(var.os_disk.disk_size_gb, var.os_type == "Windows" ? 127 : 32)

  capacity = var.scaling.mode == "fixed" ? {
    minimum = var.scaling.default_instances
    default = var.scaling.default_instances
    maximum = var.scaling.default_instances
    } : {
    minimum = var.scaling.minimum_instances
    default = var.scaling.default_instances
    maximum = var.scaling.maximum_instances
  }
  autoscale_rules = var.scaling.mode == "autoscale" ? {
    scale_out = {
      operator  = "GreaterThan"
      threshold = var.scaling.cpu.scale_out_threshold
      direction = "Increase"
      count     = var.scaling.cpu.scale_out_count
    }
    scale_in = {
      operator  = "LessThan"
      threshold = var.scaling.cpu.scale_in_threshold
      direction = "Decrease"
      count     = var.scaling.cpu.scale_in_count
    }
  } : {}

  virtual_machine_scale_set_id = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine_scale_set.this[0].id
  ) : azurerm_linux_virtual_machine_scale_set.this[0].id
  virtual_machine_scale_set_name = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine_scale_set.this[0].name
  ) : azurerm_linux_virtual_machine_scale_set.this[0].name
  virtual_machine_scale_set_unique_id = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine_scale_set.this[0].unique_id
  ) : azurerm_linux_virtual_machine_scale_set.this[0].unique_id
  virtual_machine_scale_set_principal_id = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine_scale_set.this[0].identity[0].principal_id
  ) : azurerm_linux_virtual_machine_scale_set.this[0].identity[0].principal_id
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  sku                             = var.size
  instances                       = var.scaling.default_instances
  admin_username                  = var.admin_username
  disable_password_authentication = true
  zones                           = length(var.zones) > 0 ? var.zones : null
  upgrade_mode                    = var.upgrade_mode
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = local.os_disk_size_gb
  }

  dynamic "data_disk" {
    for_each = var.data_disks

    content {
      caching              = data_disk.value.caching
      create_option        = "Empty"
      disk_size_gb         = data_disk.value.disk_size_gb
      lun                  = data_disk.value.lun
      storage_account_type = data_disk.value.storage_account_type
    }
  }

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }

  network_interface {
    name                          = var.network_interface_name
    primary                       = true
    enable_accelerated_networking = var.enable_accelerated_networking

    ip_configuration {
      name                                         = "primary"
      primary                                      = true
      subnet_id                                    = var.subnet_id
      load_balancer_backend_address_pool_ids       = var.load_balancer_backend_address_pool_ids
      application_gateway_backend_address_pool_ids = var.application_gateway_backend_address_pool_ids
    }
  }

  lifecycle {
    ignore_changes = [instances]
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "this" {
  count = var.os_type == "Windows" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.size
  instances           = var.scaling.default_instances
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zones               = length(var.zones) > 0 ? var.zones : null
  upgrade_mode        = var.upgrade_mode
  secure_boot_enabled = true
  vtpm_enabled        = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = local.os_disk_size_gb
  }

  dynamic "data_disk" {
    for_each = var.data_disks

    content {
      caching              = data_disk.value.caching
      create_option        = "Empty"
      disk_size_gb         = data_disk.value.disk_size_gb
      lun                  = data_disk.value.lun
      storage_account_type = data_disk.value.storage_account_type
    }
  }

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }

  network_interface {
    name                          = var.network_interface_name
    primary                       = true
    enable_accelerated_networking = var.enable_accelerated_networking

    ip_configuration {
      name                                         = "primary"
      primary                                      = true
      subnet_id                                    = var.subnet_id
      load_balancer_backend_address_pool_ids       = var.load_balancer_backend_address_pool_ids
      application_gateway_backend_address_pool_ids = var.application_gateway_backend_address_pool_ids
    }
  }

  lifecycle {
    ignore_changes = [instances]
  }
}

resource "azurerm_monitor_autoscale_setting" "this" {
  name                = var.autoscale_setting_name
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = local.virtual_machine_scale_set_id
  enabled             = true
  tags                = var.tags

  profile {
    name = "${var.scaling.mode}-capacity"

    capacity {
      minimum = local.capacity.minimum
      default = local.capacity.default
      maximum = local.capacity.maximum
    }

    dynamic "rule" {
      for_each = local.autoscale_rules

      content {
        metric_trigger {
          metric_name              = "Percentage CPU"
          metric_namespace         = "Microsoft.Compute/virtualMachineScaleSets"
          metric_resource_id       = local.virtual_machine_scale_set_id
          divide_by_instance_count = false
          statistic                = "Average"
          time_aggregation         = "Average"
          time_grain               = "PT1M"
          time_window              = "PT${var.scaling.cpu.time_window_minutes}M"
          operator                 = rule.value.operator
          threshold                = rule.value.threshold
        }

        scale_action {
          direction = rule.value.direction
          type      = "ChangeCount"
          value     = rule.value.count
          cooldown  = "PT${var.scaling.cpu.cooldown_minutes}M"
        }
      }
    }
  }
}

output "id" {
  description = "Virtual Machine Scale Set ID."
  value       = local.virtual_machine_scale_set_id
}

output "name" {
  description = "Virtual Machine Scale Set name."
  value       = local.virtual_machine_scale_set_name
}

output "unique_id" {
  description = "Azure-generated Virtual Machine Scale Set unique ID."
  value       = local.virtual_machine_scale_set_unique_id
}

output "os_type" {
  description = "Selected operating system."
  value       = var.os_type
}

output "principal_id" {
  description = "System-assigned managed identity principal ID."
  value       = local.virtual_machine_scale_set_principal_id
}

output "autoscale_setting_id" {
  description = "Azure Monitor autoscale setting ID."
  value       = azurerm_monitor_autoscale_setting.this.id
}

output "scaling_mode" {
  description = "Selected capacity mode: fixed or autoscale."
  value       = var.scaling.mode
}
