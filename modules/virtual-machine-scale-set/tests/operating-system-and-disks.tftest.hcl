mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_linux_virtual_machine_scale_set" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vmss-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-linux"
      unique_id = "linux-vmss-unique-id"
      identity = {
        principal_id = "11111111-1111-1111-1111-111111111111"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
        type         = "SystemAssigned"
      }
    }
  }

  mock_resource "azurerm_windows_virtual_machine_scale_set" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vmss-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-windows"
      unique_id = "windows-vmss-unique-id"
      identity = {
        principal_id = "33333333-3333-3333-3333-333333333333"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
        type         = "SystemAssigned"
      }
    }
  }

  mock_resource "azurerm_monitor_autoscale_setting" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vmss-test/providers/Microsoft.Insights/autoscaleSettings/autoscale-test"
    }
  }
}

variables {
  name                   = "vmss-test"
  autoscale_setting_name = "autoscale-vmss-test"
  network_interface_name = "nic-vmss-test"
  resource_group_name    = "rg-vmss-test"
  location               = "swedencentral"
  subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vmss-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vms"
  admin_ssh_public_key   = "ssh-rsa ${base64encode(join("", ["\u0000\u0000\u0000\u0007", "ssh-rsa", "\u0000\u0000\u0000\u0003\u0001\u0000\u0001", "\u0000\u0000\u0001\u0000\u007f", join("", [for i in range(255) : "A"])]))}"
}

run "linux_fixed_defaults" {
  command = plan

  assert {
    condition = (
      length(azurerm_linux_virtual_machine_scale_set.this) == 1 &&
      length(azurerm_windows_virtual_machine_scale_set.this) == 0 &&
      azurerm_linux_virtual_machine_scale_set.this[0].instances == 2 &&
      azurerm_linux_virtual_machine_scale_set.this[0].source_image_reference[0].publisher == "Canonical" &&
      azurerm_linux_virtual_machine_scale_set.this[0].source_image_reference[0].offer == "0001-com-ubuntu-server-jammy" &&
      azurerm_linux_virtual_machine_scale_set.this[0].source_image_reference[0].sku == "22_04-lts-gen2" &&
      azurerm_linux_virtual_machine_scale_set.this[0].source_image_reference[0].version == "latest" &&
      azurerm_linux_virtual_machine_scale_set.this[0].os_disk[0].disk_size_gb == 32
    )
    error_message = "Linux defaults must select Ubuntu 22.04 Gen2, two initial instances, and a 32 GiB OS disk."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine_scale_set.this[0].disable_password_authentication &&
      azurerm_linux_virtual_machine_scale_set.this[0].secure_boot_enabled &&
      azurerm_linux_virtual_machine_scale_set.this[0].vtpm_enabled &&
      azurerm_linux_virtual_machine_scale_set.this[0].network_interface[0].ip_configuration[0].subnet_id == var.subnet_id &&
      length(azurerm_linux_virtual_machine_scale_set.this[0].network_interface[0].ip_configuration[0].public_ip_address) == 0 &&
      azurerm_linux_virtual_machine_scale_set.this[0].identity[0].type == "SystemAssigned"
    )
    error_message = "Linux VMSS instances must use SSH-only authentication, Trusted Launch, managed identity, and private networking."
  }

  assert {
    condition = (
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].minimum == 2 &&
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].default == 2 &&
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].maximum == 2 &&
      length(azurerm_monitor_autoscale_setting.this.profile[0].rule) == 0 &&
      output.scaling_mode == "fixed"
    )
    error_message = "Fixed mode must give Azure Monitor equal capacity bounds without dynamic rules."
  }
}

run "linux_autoscale_custom_image_and_disks" {
  command = plan

  variables {
    source_image_reference = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadOnly"
      storage_account_type = "Premium_LRS"
      disk_size_gb         = 64
    }
    data_disks = {
      app = {
        lun                  = 0
        disk_size_gb         = 128
        storage_account_type = "Premium_LRS"
        caching              = "ReadOnly"
      }
      logs = {
        lun                  = 1
        disk_size_gb         = 256
        storage_account_type = "StandardSSD_LRS"
        caching              = "ReadWrite"
      }
    }
    scaling = {
      mode              = "autoscale"
      minimum_instances = 2
      default_instances = 3
      maximum_instances = 6
      cpu = {
        scale_out_threshold = 80
        scale_in_threshold  = 20
        scale_out_count     = 2
        scale_in_count      = 1
        time_window_minutes = 10
        cooldown_minutes    = 5
      }
    }
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine_scale_set.this[0].instances == 3 &&
      azurerm_linux_virtual_machine_scale_set.this[0].source_image_reference[0].offer == "ubuntu-24_04-lts" &&
      azurerm_linux_virtual_machine_scale_set.this[0].os_disk[0].disk_size_gb == 64 &&
      azurerm_linux_virtual_machine_scale_set.this[0].os_disk[0].storage_account_type == "Premium_LRS" &&
      length(azurerm_linux_virtual_machine_scale_set.this[0].data_disk) == 2 &&
      one([for disk in azurerm_linux_virtual_machine_scale_set.this[0].data_disk : disk if disk.lun == 0]).disk_size_gb == 128 &&
      one([for disk in azurerm_linux_virtual_machine_scale_set.this[0].data_disk : disk if disk.lun == 1]).disk_size_gb == 256
    )
    error_message = "Linux custom images, OS disks, and multiple per-instance data disks must be preserved."
  }

  assert {
    condition = (
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].minimum == 2 &&
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].default == 3 &&
      azurerm_monitor_autoscale_setting.this.profile[0].capacity[0].maximum == 6 &&
      length(azurerm_monitor_autoscale_setting.this.profile[0].rule) == 2 &&
      one([for rule in azurerm_monitor_autoscale_setting.this.profile[0].rule : rule if rule.scale_action[0].direction == "Increase"]).metric_trigger[0].threshold == 80 &&
      one([for rule in azurerm_monitor_autoscale_setting.this.profile[0].rule : rule if rule.scale_action[0].direction == "Decrease"]).metric_trigger[0].threshold == 20 &&
      output.scaling_mode == "autoscale"
    )
    error_message = "Autoscale mode must configure bounded CPU scale-out and scale-in rules."
  }
}

run "windows_defaults" {
  command = plan

  variables {
    os_type              = "Windows"
    admin_password       = "MockOnly-Passw0rd!123"
    admin_ssh_public_key = null
  }

  assert {
    condition = (
      length(azurerm_linux_virtual_machine_scale_set.this) == 0 &&
      length(azurerm_windows_virtual_machine_scale_set.this) == 1 &&
      azurerm_windows_virtual_machine_scale_set.this[0].source_image_reference[0].publisher == "MicrosoftWindowsServer" &&
      azurerm_windows_virtual_machine_scale_set.this[0].source_image_reference[0].offer == "WindowsServer" &&
      azurerm_windows_virtual_machine_scale_set.this[0].source_image_reference[0].sku == "2022-datacenter-azure-edition" &&
      azurerm_windows_virtual_machine_scale_set.this[0].source_image_reference[0].version == "latest" &&
      azurerm_windows_virtual_machine_scale_set.this[0].os_disk[0].disk_size_gb == 127 &&
      azurerm_windows_virtual_machine_scale_set.this[0].admin_password == var.admin_password
    )
    error_message = "Windows defaults must select Windows Server 2022 Azure Edition, a 127 GiB OS disk, and password authentication."
  }

  assert {
    condition = (
      output.id == azurerm_windows_virtual_machine_scale_set.this[0].id &&
      output.name == var.name &&
      output.os_type == "Windows" &&
      output.principal_id == "33333333-3333-3333-3333-333333333333" &&
      output.autoscale_setting_id == azurerm_monitor_autoscale_setting.this.id
    )
    error_message = "Windows must expose the shared VMSS and autoscale outputs."
  }
}

run "invalid_os" {
  command = plan
  variables { os_type = "FreeBSD" }
  expect_failures = [var.os_type]
}

run "missing_linux_key" {
  command = plan
  variables { admin_ssh_public_key = null }
  expect_failures = [var.admin_ssh_public_key]
}

run "missing_windows_password" {
  command = plan
  variables {
    os_type              = "Windows"
    admin_ssh_public_key = null
  }
  expect_failures = [var.admin_password]
}

run "duplicate_data_disk_luns" {
  command = plan
  variables {
    data_disks = {
      app  = { lun = 0, disk_size_gb = 32 }
      logs = { lun = 0, disk_size_gb = 64 }
    }
  }
  expect_failures = [var.data_disks]
}

run "invalid_autoscale_capacity_order" {
  command = plan
  variables {
    scaling = {
      mode              = "autoscale"
      minimum_instances = 4
      default_instances = 3
      maximum_instances = 6
    }
  }
  expect_failures = [var.scaling]
}

run "overlapping_cpu_thresholds" {
  command = plan
  variables {
    scaling = {
      mode = "autoscale"
      cpu = {
        scale_out_threshold = 40
        scale_in_threshold  = 50
      }
    }
  }
  expect_failures = [var.scaling]
}

run "reject_autoscale_time_window_below_azure_minimum" {
  command = plan
  variables {
    scaling = {
      mode = "autoscale"
      cpu = {
        time_window_minutes = 4
      }
    }
  }
  expect_failures = [var.scaling]
}

run "accept_autoscale_minimum_time_window" {
  command = plan
  variables {
    scaling = {
      mode = "autoscale"
      cpu = {
        time_window_minutes = 5
      }
    }
  }

  assert {
    condition = alltrue([
      for rule in azurerm_monitor_autoscale_setting.this.profile[0].rule :
      rule.metric_trigger[0].time_window == "PT5M"
    ])
    error_message = "Azure Monitor autoscale rules must accept and preserve the five-minute minimum evaluation window."
  }
}
