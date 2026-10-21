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
  computer_name_prefix            = var.computer_name_prefix
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

  name                 = var.name
  resource_group_name  = var.resource_group_name
  location             = var.location
  sku                  = var.size
  instances            = var.scaling.default_instances
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  computer_name_prefix = var.computer_name_prefix
  zones                = length(var.zones) > 0 ? var.zones : null
  upgrade_mode         = var.upgrade_mode
  secure_boot_enabled  = true
  vtpm_enabled         = true
  tags                 = var.tags

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
