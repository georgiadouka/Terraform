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

resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = var.load_balancer_backend_address_pool_ids

  network_interface_id    = azurerm_network_interface.this.id
  ip_configuration_name   = "primary"
  backend_address_pool_id = each.value
}

resource "azurerm_linux_virtual_machine" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = var.admin_password == null
  network_interface_ids           = [azurerm_network_interface.this.id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = var.tags

  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_public_key == null ? [] : [var.admin_ssh_public_key]

    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
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

  # A changed admin_password would replace the VM. Users change the password
  # inside the OS after first sign-in, so Terraform keeps the initial value.
  # Azure Update Manager (usually through Azure Policy) turns on the bypass
  # setting so its maintenance schedules can patch the VM; patching is left to
  # it.
  lifecycle {
    ignore_changes = [admin_password, bypass_platform_safety_checks_on_user_schedule_enabled]
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

  # See azurerm_linux_virtual_machine: the initial password and the Update
  # Manager bypass setting are not enforced.
  lifecycle {
    ignore_changes = [admin_password, bypass_platform_safety_checks_on_user_schedule_enabled]
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
