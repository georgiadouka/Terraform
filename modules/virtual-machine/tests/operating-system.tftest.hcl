mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_network_interface" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Network/networkInterfaces/nic-test"
      private_ip_address = "10.0.1.4"
    }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Compute/virtualMachines/linux-test"
    }
  }
  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Compute/virtualMachines/windows-test"
    }
  }
  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Compute/disks/data-test"
    }
  }
}

variables {
  name                   = "vm-test"
  resource_group_name    = "rg-vm-test"
  location               = "swedencentral"
  subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vms"
  network_interface_name = "nic-test"
  os_disk_name           = "os-test"
  data_disk_names        = {}
  admin_ssh_public_key   = "ssh-rsa ${base64encode(join("", ["\u0000\u0000\u0000\u0007", "ssh-rsa", "\u0000\u0000\u0000\u0003\u0001\u0000\u0001", "\u0000\u0000\u0001\u0000\u007f", join("", [for i in range(255) : "A"])]))}"
}

run "linux_defaults" {
  command = plan

  assert {
    condition = (
      length(azurerm_linux_virtual_machine.this) == 1 &&
      length(azurerm_windows_virtual_machine.this) == 0 &&
      azurerm_linux_virtual_machine.this[0].os_disk[0].disk_size_gb == 32 &&
      azurerm_linux_virtual_machine.this[0].source_image_reference[0].publisher == "Canonical" &&
      azurerm_linux_virtual_machine.this[0].source_image_reference[0].offer == "0001-com-ubuntu-server-jammy" &&
      azurerm_linux_virtual_machine.this[0].source_image_reference[0].sku == "22_04-lts-gen2" &&
      azurerm_linux_virtual_machine.this[0].source_image_reference[0].version == "latest"
    )
    error_message = "Existing Linux callers must retain Ubuntu 22.04 Gen2 and a 32 GB OS disk."
  }
  assert {
    condition = (
      azurerm_linux_virtual_machine.this[0].disable_password_authentication &&
      one(azurerm_linux_virtual_machine.this[0].admin_ssh_key).public_key == var.admin_ssh_public_key &&
      azurerm_linux_virtual_machine.this[0].secure_boot_enabled &&
      azurerm_linux_virtual_machine.this[0].vtpm_enabled &&
      output.id == azurerm_linux_virtual_machine.this[0].id &&
      output.name == var.name &&
      output.private_ip_address == "10.0.1.4"
    )
    error_message = "Linux must retain SSH-only authentication, trusted launch, and shared outputs."
  }
  assert {
    condition     = length(azurerm_network_interface_backend_address_pool_association.this) == 0
    error_message = "By default the NIC must not join any load balancer backend pool."
  }
}

run "joins_load_balancer_backend_pool" {
  command = plan

  variables {
    load_balancer_backend_address_pool_ids = {
      web = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm-test/providers/Microsoft.Network/loadBalancers/lbi-web/backendAddressPools/lbbe-web"
    }
  }

  assert {
    condition = (
      length(azurerm_network_interface_backend_address_pool_association.this) == 1 &&
      azurerm_network_interface_backend_address_pool_association.this["web"].ip_configuration_name == "primary" &&
      azurerm_network_interface_backend_address_pool_association.this["web"].network_interface_id == azurerm_network_interface.this.id &&
      endswith(azurerm_network_interface_backend_address_pool_association.this["web"].backend_address_pool_id, "/backendAddressPools/lbbe-web")
    )
    error_message = "The NIC's primary IP configuration must join each configured backend pool."
  }
}

run "linux_custom_image_and_disks" {
  command = plan
  variables {
    source_image_reference = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
    os_disk = { disk_size_gb = 64, caching = "ReadOnly", storage_account_type = "Premium_LRS" }
    data_disks = {
      data = { lun = 2, disk_size_gb = 128, caching = "ReadOnly" }
    }
    data_disk_names = { data = "data-test" }
  }
  assert {
    condition = (
      azurerm_linux_virtual_machine.this[0].os_disk[0].disk_size_gb == 64 &&
      azurerm_linux_virtual_machine.this[0].os_disk[0].caching == "ReadOnly" &&
      azurerm_linux_virtual_machine.this[0].os_disk[0].storage_account_type == "Premium_LRS" &&
      azurerm_linux_virtual_machine.this[0].source_image_reference[0].offer == "ubuntu-24_04-lts" &&
      azurerm_virtual_machine_data_disk_attachment.this["data"].virtual_machine_id == output.id &&
      azurerm_virtual_machine_data_disk_attachment.this["data"].lun == 2 &&
      output.data_disk_ids["data"] == azurerm_managed_disk.data["data"].id
    )
    error_message = "Linux custom images, disk settings, attachments, and disk outputs must remain supported."
  }
}

run "windows_defaults" {
  command = plan
  variables {
    os_type              = "Windows"
    admin_password       = "MockOnly-Passw0rd!123"
    admin_ssh_public_key = null
    computer_name        = "win-test"
    os_disk              = { disk_size_gb = null }
    data_disks = {
      data = { lun = 0, disk_size_gb = 256, caching = "None" }
    }
    data_disk_names = { data = "data-test" }
  }
  assert {
    condition = (
      length(azurerm_linux_virtual_machine.this) == 0 &&
      length(azurerm_windows_virtual_machine.this) == 1 &&
      azurerm_windows_virtual_machine.this[0].source_image_reference[0].publisher == "MicrosoftWindowsServer" &&
      azurerm_windows_virtual_machine.this[0].source_image_reference[0].offer == "WindowsServer" &&
      azurerm_windows_virtual_machine.this[0].source_image_reference[0].sku == "2022-datacenter-azure-edition" &&
      azurerm_windows_virtual_machine.this[0].source_image_reference[0].version == "latest" &&
      azurerm_windows_virtual_machine.this[0].os_disk[0].disk_size_gb == 127
    )
    error_message = "Windows must select only Windows Server 2022 Azure Edition and a 127 GB OS disk."
  }
  assert {
    condition = (
      azurerm_windows_virtual_machine.this[0].admin_password == var.admin_password &&
      azurerm_windows_virtual_machine.this[0].computer_name == "win-test" &&
      azurerm_windows_virtual_machine.this[0].secure_boot_enabled &&
      azurerm_windows_virtual_machine.this[0].vtpm_enabled &&
      azurerm_windows_virtual_machine.this[0].network_interface_ids == tolist([azurerm_network_interface.this.id]) &&
      azurerm_network_interface.this.ip_configuration[0].public_ip_address_id == null &&
      output.id == azurerm_windows_virtual_machine.this[0].id &&
      output.name == var.name &&
      output.private_ip_address == "10.0.1.4" &&
      azurerm_managed_disk.data["data"].disk_size_gb == 256 &&
      azurerm_virtual_machine_data_disk_attachment.this["data"].virtual_machine_id == output.id &&
      azurerm_virtual_machine_data_disk_attachment.this["data"].managed_disk_id == output.data_disk_ids["data"] &&
      azurerm_virtual_machine_data_disk_attachment.this["data"].caching == "None"
    )
    error_message = "Windows authentication, trusted launch, private-only networking, disk attachments, and outputs must match the selected VM."
  }
}

run "windows_name_fallback_and_larger_disk" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    os_disk        = { disk_size_gb = 256 }
  }
  assert {
    condition = (
      azurerm_windows_virtual_machine.this[0].computer_name == var.name &&
      azurerm_windows_virtual_machine.this[0].os_disk[0].disk_size_gb == 256
    )
    error_message = "Windows must default computer_name to name and allow a larger OS disk."
  }
}

run "windows_custom_smaller_image" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    os_disk        = { disk_size_gb = 64 }
    source_image_reference = {
      publisher = "custom"
      offer     = "custom"
      sku       = "small-windows"
      version   = "1.0.0"
    }
  }
  assert {
    condition = (
      azurerm_windows_virtual_machine.this[0].os_disk[0].disk_size_gb == 64 &&
      azurerm_windows_virtual_machine.this[0].source_image_reference[0].sku == "small-windows"
    )
    error_message = "Custom Windows images must allow their own OS disk sizing."
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

run "blank_linux_key" {
  command = plan
  variables { admin_ssh_public_key = " " }
  expect_failures = [var.admin_ssh_public_key]
}

run "missing_windows_password" {
  command = plan
  variables { os_type = "Windows" }
  expect_failures = [var.admin_password]
}

run "blank_windows_password" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = " "
  }
  expect_failures = [var.admin_password]
}

run "undersized_windows_default_disk" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    os_disk        = { disk_size_gb = 126 }
  }
  expect_failures = [var.os_disk]
}

run "undersized_explicit_windows_default_image_disk" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    os_disk        = { disk_size_gb = 32 }
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
  }
  expect_failures = [var.os_disk]
}

run "invalid_computer_name_length" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    computer_name  = "sixteen-charname1"
  }
  expect_failures = [var.computer_name]
}

run "invalid_computer_name_characters" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    computer_name  = "win_test"
  }
  expect_failures = [var.computer_name]
}

run "numeric_computer_name" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    computer_name  = "12345"
  }
  expect_failures = [var.computer_name]
}

run "blank_computer_name" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    computer_name  = ""
  }
  expect_failures = [var.computer_name]
}

run "invalid_windows_name_fallback" {
  command = plan
  variables {
    os_type        = "Windows"
    admin_password = "MockOnly-Passw0rd!123"
    name           = "vm-name-is-too-long-for-windows"
  }
  expect_failures = [var.computer_name]
}

run "blank_image_field" {
  command = plan
  variables {
    source_image_reference = {
      publisher = " "
      offer     = "offer"
      sku       = "sku"
      version   = "latest"
    }
  }
  expect_failures = [var.source_image_reference]
}

run "null_image_field" {
  command = plan
  variables {
    source_image_reference = {
      publisher = "Canonical"
      offer     = "offer"
      sku       = "sku"
      version   = null
    }
  }
  expect_failures = [var.source_image_reference]
}

run "fractional_os_disk" {
  command = plan
  variables { os_disk = { disk_size_gb = 32.5 } }
  expect_failures = [var.os_disk]
}

run "nonpositive_os_disk" {
  command = plan
  variables { os_disk = { disk_size_gb = 0 } }
  expect_failures = [var.os_disk]
}

run "duplicate_data_disk_luns" {
  command = plan
  variables {
    data_disk_names = { one = "data-one", two = "data-two" }
    data_disks = {
      one = { lun = 0, disk_size_gb = 32 }
      two = { lun = 0, disk_size_gb = 64 }
    }
  }
  expect_failures = [var.data_disks]
}

run "blank_size" {
  command = plan
  variables { size = " " }
  expect_failures = [var.size]
}

run "blank_admin_username" {
  command = plan
  variables { admin_username = " " }
  expect_failures = [var.admin_username]
}

run "invalid_data_disk_label" {
  command = plan
  variables {
    data_disk_names = { Invalid_Label = "data-test" }
    data_disks = {
      Invalid_Label = { lun = 0, disk_size_gb = 32 }
    }
  }
  expect_failures = [var.data_disks]
}

run "mismatched_data_disk_names" {
  command = plan
  variables {
    data_disk_names = {}
    data_disks = {
      data = { lun = 0, disk_size_gb = 32 }
    }
  }
  expect_failures = [var.data_disk_names]
}

run "blank_data_disk_name" {
  command = plan
  variables {
    data_disk_names = { data = " " }
    data_disks = {
      data = { lun = 0, disk_size_gb = 32 }
    }
  }
  expect_failures = [var.data_disk_names]
}

run "duplicate_data_disk_names" {
  command = plan
  variables {
    data_disk_names = { one = "data-test", two = "DATA-TEST" }
    data_disks = {
      one = { lun = 0, disk_size_gb = 32 }
      two = { lun = 1, disk_size_gb = 64 }
    }
  }
  expect_failures = [var.data_disk_names]
}
