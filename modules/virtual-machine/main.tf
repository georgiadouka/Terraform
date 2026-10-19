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
  virtual_machine_id = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine.this[0].id
  ) : azurerm_linux_virtual_machine.this[0].id
  virtual_machine_name = var.os_type == "Windows" ? (
    azurerm_windows_virtual_machine.this[0].name
  ) : azurerm_linux_virtual_machine.this[0].name
}

variable "tags" {
  description = "Tags applied to VM resources."
  type        = map(string)
  default     = {}
}

resource "azurerm_network_interface" "this" {
  name                = var.network_interface_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = var.os_disk_name
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = local.os_disk_size_gb
  }

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  count = var.os_type == "Windows" ? 1 : 0

  name                  = var.name
  computer_name         = var.computer_name == null ? var.name : var.computer_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.this.id]
  secure_boot_enabled   = true
  vtpm_enabled          = true
  tags                  = var.tags

  os_disk {
    name                 = var.os_disk_name
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = local.os_disk_size_gb
  }

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }
}

resource "azurerm_managed_disk" "data" {
  for_each = var.data_disks

  name                 = var.data_disk_names[each.key]
  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  for_each = var.data_disks

  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = local.virtual_machine_id
  lun                = each.value.lun
  caching            = each.value.caching
}

output "id" {
  description = "Virtual machine ID."
  value       = local.virtual_machine_id
}

output "name" {
  description = "Virtual machine name."
  value       = local.virtual_machine_name
}

output "private_ip_address" {
  description = "Virtual machine private IP address."
  value       = azurerm_network_interface.this.private_ip_address
}

output "data_disk_ids" {
  description = "Managed disk IDs keyed by logical name."
  value       = { for key, disk in azurerm_managed_disk.data : key => disk.id }
}
