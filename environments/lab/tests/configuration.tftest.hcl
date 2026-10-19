mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-linux"
    }
  }
  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-windows"
    }
  }
  mock_resource "azurerm_linux_virtual_machine_scale_set" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-linux"
      unique_id = "linux-vmss-unique-id"
      identity = {
        principal_id = "55555555-5555-5555-5555-555555555555"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
        type         = "SystemAssigned"
      }
    }
  }
  mock_resource "azurerm_windows_virtual_machine_scale_set" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-windows"
      unique_id = "windows-vmss-unique-id"
      identity = {
        principal_id = "66666666-6666-6666-6666-666666666666"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
        type         = "SystemAssigned"
      }
    }
  }
  mock_resource "azurerm_monitor_autoscale_setting" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/autoscaleSettings/autoscale-test"
    }
  }
  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/data"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-test"
    }
  }
  mock_resource "azurerm_linux_function_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-test"
      default_hostname = "func-linux.azurewebsites.net"
    }
  }
  mock_resource "azurerm_windows_function_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-windows"
      default_hostname = "func-windows.azurewebsites.net"
    }
  }
  mock_resource "azurerm_linux_web_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-linux"
      default_hostname = "app-linux.azurewebsites.net"
      identity = {
        principal_id = "33333333-3333-3333-3333-333333333333"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
  mock_resource "azurerm_windows_web_app" {
    override_during = plan
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-windows"
      default_hostname = "app-windows.azurewebsites.net"
      identity = {
        principal_id = "44444444-4444-4444-4444-444444444444"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
    }
  }
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/cae-test"
      default_domain    = "test.azurecontainerapps.io"
      static_ip_address = "10.42.2.4"
    }
  }
  mock_resource "azurerm_container_registry" {
    override_during = plan
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/crmetlenlabtest1"
      login_server = "crmetlenlabtest1.azurecr.io"
    }
  }
  mock_resource "azurerm_private_endpoint" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateEndpoints/pe-test"
    }
  }
}

override_module {
  target = module.network
  outputs = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    subnet_ids = {
      virtual_machines     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vms"
      private_endpoints    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/endpoints"
      web_app_integration  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web-app"
      function_integration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
      container_apps       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps"
    }
  }
}

override_module {
  target  = module.nat_gateway[0]
  outputs = { id = "mock-nat", public_ip_address = "203.0.113.10" }
}

override_module {
  target = module.private_dns
  outputs = {
    zone_ids = {
      for service in ["azurecr.io", "blob.core.windows.net", "file.core.windows.net", "queue.core.windows.net", "table.core.windows.net", "azurewebsites.net"] :
      "privatelink.${service}" => "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.${service}"
    }
  }
}

override_module {
  target = module.function_storage[0]
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfunctiontest"
    name               = "stfunctiontest"
    primary_access_key = "test-only-storage-key"
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "22222222-2222-2222-2222-222222222222"
  naming          = { unique_suffix = "test1" }
  container_apps  = {}
  web_app         = {}
  function_app    = {}
  virtual_machines = {
    primary = {}
  }
  storage_accounts      = {}
  premium_file_accounts = {}
  services = {
    virtual_machine_scale_set = false
    key_vault                 = false
    container_registry        = false
    azure_sql                 = false
    sql_managed_instance      = false
    postgresql                = false
    mysql                     = false
    container_apps            = false
    cosmos_db                 = false
    web_app                   = false
    function_app              = true
  }
}

run "linux_defaults" {
  command = plan
  assert {
    condition = (
      output.virtual_machines["primary"].os_type == "Linux" &&
      output.virtual_machines["primary"].name == "vm-primary-metlen-lab-test1" &&
      length(tls_private_key.vm) == 1 &&
      contains(keys(output.vm_ssh_public_keys), "primary") &&
      length(random_password.vm_windows) == 0 &&
      length(output.vm_windows_admin_passwords) == 0 &&
      output.function_app_os_type == "Linux" &&
      output.function_app_hostname == "func-linux.azurewebsites.net" &&
      output.generated_resource_names.subnets == {
        private_endpoints    = "snet-pe-metlen-lab-test1"
        virtual_machines     = "snet-vm-metlen-lab-test1"
        container_apps       = "snet-aca-metlen-lab-test1"
        web_app_integration  = "snet-app-metlen-lab-test1"
        function_integration = "snet-func-metlen-lab-test1"
        postgresql           = "snet-psql-metlen-lab-test1"
        mysql                = "snet-mysql-metlen-lab-test1"
        sql_managed_instance = "snet-sqlmi-metlen-lab-test1"
      }
    )
    error_message = "Linux defaults must retain SSH credentials without a Windows password and use abbreviated subnet roles with full deployment context."
  }
}

run "windows_and_node" {
  command = plan
  variables {
    environment      = "long-env"
    virtual_machines = { primary = { os_type = "Windows" } }
    function_app     = { runtime = { name = "node", version = "22" } }
  }
  assert {
    condition = (
      output.virtual_machines["primary"].os_type == "Windows" &&
      length(tls_private_key.vm) == 0 &&
      length(output.vm_ssh_public_keys) == 0 &&
      length(random_password.vm_windows) == 1 &&
      contains(keys(output.vm_windows_admin_passwords), "primary")
    )
    error_message = "Windows must generate password credentials instead of an SSH key."
  }
}

run "multiple_virtual_machines" {
  command = plan
  variables {
    virtual_machines = {
      api = {
        size       = "Standard_B2s_v2"
        data_disks = {}
      }
      worker = {
        size       = "Standard_D2s_v5"
        data_disks = {}
      }
      admin = {
        os_type    = "Windows"
        size       = "Standard_D2s_v5"
        data_disks = {}
      }
    }
  }
  assert {
    condition = (
      length(module.virtual_machine) == 3 &&
      length(output.virtual_machines) == 3 &&
      length(output.vm_ssh_public_keys) == 2 &&
      length(output.vm_windows_admin_passwords) == 1 &&
      output.virtual_machines["api"].name == "vm-api-metlen-lab-test1" &&
      output.virtual_machines["worker"].name == "vm-worker-metlen-lab-test1" &&
      output.virtual_machines["admin"].name == "vm-admin-metlen-lab-test1" &&
      output.virtual_machines["admin"].os_type == "Windows"
    )
    error_message = "Each virtual_machines entry must create one independently named VM with credentials matching its operating system."
  }
}

run "vmss_linux_autoscale" {
  command = plan
  variables {
    services = merge(var.services, { virtual_machine_scale_set = true })
    virtual_machine_scale_set = {
      data_disks = {
        app  = { lun = 0, disk_size_gb = 128 }
        logs = { lun = 1, disk_size_gb = 256 }
      }
      scaling = {
        mode              = "autoscale"
        minimum_instances = 2
        default_instances = 3
        maximum_instances = 6
      }
    }
  }
  assert {
    condition = (
      output.vmss_name == "vmss-metlen-lab-test1" &&
      output.vmss_os_type == "Linux" &&
      output.vmss_scaling_mode == "autoscale" &&
      output.vmss_windows_admin_password == null &&
      length(module.virtual_machine_scale_set) == 1 &&
      length(tls_private_key.vmss) == 1 &&
      length(random_password.vmss_windows) == 0
    )
    error_message = "The lab must create the named Linux VMSS with independent SSH credentials, managed identity, and autoscaling."
  }
}

run "vmss_windows_fixed" {
  command = plan
  variables {
    services                  = merge(var.services, { virtual_machine_scale_set = true })
    virtual_machine_scale_set = { os_type = "Windows", scaling = { mode = "fixed", default_instances = 2 } }
  }
  assert {
    condition = (
      output.vmss_os_type == "Windows" &&
      output.vmss_scaling_mode == "fixed" &&
      output.vmss_ssh_public_key == null &&
      length(module.virtual_machine_scale_set) == 1 &&
      length(tls_private_key.vmss) == 0 &&
      length(random_password.vmss_windows) == 1
    )
    error_message = "The lab must create the Windows VMSS with independent password credentials and fixed Azure Monitor capacity."
  }
}

run "vmss_only_keeps_shared_network" {
  command = plan
  variables {
    virtual_machines = {}
    services = {
      virtual_machine_scale_set = true
      key_vault                 = false
      container_registry        = false
      azure_sql                 = false
      sql_managed_instance      = false
      postgresql                = false
      mysql                     = false
      container_apps            = false
      cosmos_db                 = false
      web_app                   = false
      function_app              = false
    }
  }
  assert {
    condition = (
      local.nat_gateway_required &&
      local.subnet_enabled.virtual_machines &&
      length(module.nat_gateway) == 1 &&
      length(module.virtual_machine) == 0 &&
      length(module.virtual_machine_scale_set) == 1
    )
    error_message = "A VMSS-only lab must retain the shared VM subnet and NAT Gateway without creating the standalone VM."
  }
}

run "disabled_services" {
  command = plan
  variables {
    virtual_machines = {}
    services = {
      virtual_machine_scale_set = false
      key_vault                 = false
      container_registry        = false
      azure_sql                 = false
      sql_managed_instance      = false
      postgresql                = false
      mysql                     = false
      container_apps            = false
      cosmos_db                 = false
      web_app                   = false
      function_app              = false
    }
  }
  assert {
    condition = (
      length(output.virtual_machines) == 0 &&
      length(output.vm_ssh_public_keys) == 0 &&
      length(output.vm_windows_admin_passwords) == 0 &&
      length(tls_private_key.vm) == 0 &&
      length(random_password.vm_windows) == 0 &&
      output.vmss_id == null &&
      output.vmss_os_type == null &&
      output.vmss_ssh_public_key == null &&
      output.vmss_windows_admin_password == null &&
      length(tls_private_key.vmss) == 0 &&
      length(random_password.vmss_windows) == 0 &&
      length(module.function_app) == 0 &&
      output.function_app_os_type == null &&
      output.function_app_hostname == null &&
      output.container_registry_id == null &&
      output.web_app_id == null &&
      length(output.container_app_dedicated_workload_profile_names) == 0 &&
      output.container_app_workload_profile_name == null
    )
    error_message = "Disabled services must not generate VM credentials or a Function App."
  }
}

run "web_app_linux_default" {
  command = plan
  variables {
    services = merge(var.services, { web_app = true })
  }
  assert {
    condition = (
      output.web_app_mode == "linux" &&
      output.web_app_hostname == "app-linux.azurewebsites.net" &&
      endswith(output.web_app_id, "/sites/app-linux") &&
      length(module.web_app) == 1 &&
      length(module.web_app_private_endpoint) == 1 &&
      output.private_endpoint_ids.web_app != null
    )
    error_message = "The root configuration must create the default private Linux Web App and Private Endpoint."
  }
}

run "web_app_windows" {
  command = plan
  variables {
    services = merge(var.services, { web_app = true })
    web_app = {
      mode    = "windows"
      runtime = { name = "dotnet", version = "8.0" }
    }
  }
  assert {
    condition = (
      output.web_app_mode == "windows" &&
      output.web_app_hostname == "app-windows.azurewebsites.net" &&
      endswith(output.web_app_id, "/sites/app-windows") &&
      output.web_app_principal_id == "44444444-4444-4444-4444-444444444444"
    )
    error_message = "The root configuration must select a private Windows Web App independently of the VM and Function App OS."
  }
}

run "web_app_container" {
  command = plan
  variables {
    services = merge(var.services, { web_app = true })
    web_app  = { mode = "container" }
  }
  assert {
    condition = (
      output.web_app_mode == "container" &&
      output.web_app_hostname == "app-linux.azurewebsites.net" &&
      endswith(output.web_app_id, "/sites/app-linux")
    )
    error_message = "Container mode must use the Linux Web App resource and preserve private endpoint wiring."
  }
}

run "container_registry_private_only" {
  command = plan
  variables {
    services = merge(var.services, { container_registry = true })
  }
  assert {
    condition = (
      output.container_registry_name == "crmetlenlabtest1" &&
      output.container_registry_login_server == "crmetlenlabtest1.azurecr.io" &&
      output.container_registry_sku == "Premium" &&
      length(module.container_registry) == 1 &&
      length(module.container_registry_private_endpoint) == 1 &&
      output.private_endpoint_ids.container_registry != null
    )
    error_message = "The root configuration must create a Premium registry with its mandatory Private Endpoint."
  }
}

run "storage_entra_only" {
  command = plan
  variables {
    storage_accounts = {
      primary = {
        containers                = ["appdata"]
        file_shares               = {}
        shared_access_key_enabled = false
        data_plane_role_assignments = {
          app_blob_reader = {
            principal_id         = "77777777-7777-7777-7777-777777777777"
            role_definition_name = "Storage Blob Data Reader"
            principal_type       = "ServicePrincipal"
          }
        }
      }
    }
  }
  assert {
    condition = (
      module.storage["primary"].shared_access_key_enabled == false &&
      module.storage["primary"].primary_access_key == null &&
      length(module.storage["primary"].file_share_ids) == 0 &&
      contains(keys(module.storage["primary"].data_plane_role_assignment_ids), "app_blob_reader") &&
      output.storage_accounts["primary"].name == "stprimae3b7cmetlenltest1"
    )
    error_message = "Entra-only storage must disable key outputs, omit key-dependent file shares, and create requested workload RBAC."
  }
}

run "storage_shared_key" {
  command = plan
  variables {
    storage_use_azuread = false
    storage_accounts = {
      primary = {
        containers                = []
        shared_access_key_enabled = true
        file_shares = {
          shared = {
            quota_gb    = 100
            access_tier = "TransactionOptimized"
          }
        }
      }
    }
  }
  assert {
    condition = (
      module.storage["primary"].shared_access_key_enabled &&
      length(module.storage["primary"].file_share_ids) == 1
    )
    error_message = "Shared Key mode must remain available for tenants that permit it and must support AzureRM-managed file shares."
  }
}

run "multiple_storage_accounts" {
  command = plan
  variables {
    storage_accounts = {
      primary = {
        containers  = ["appdata"]
        file_shares = {}
      }
      archive = {
        replication_type = "ZRS"
        containers       = ["audit"]
        file_shares      = {}
      }
    }
  }
  assert {
    condition = (
      length(module.storage) == 2 &&
      length(output.storage_accounts) == 2 &&
      length(module.storage_private_endpoints) == 4 &&
      length(output.private_endpoint_ids.storage["primary"]) == 2 &&
      length(output.private_endpoint_ids.storage["archive"]) == 2 &&
      output.storage_accounts["primary"].name == "stprimae3b7cmetlenltest1" &&
      output.storage_accounts["archive"].name != output.storage_accounts["primary"].name &&
      length(output.storage_accounts["archive"].name) <= 24 &&
      output.storage_accounts["primary"].blob_hostname == "stprimae3b7cmetlenltest1.blob.core.windows.net"
    )
    error_message = "Each storage_accounts entry must create one distinctly named StorageV2 account with blob and file Private Endpoints."
  }
}

run "multiple_premium_file_accounts" {
  command = plan
  variables {
    premium_file_accounts = {
      primary = {
        file_shares = {
          premium = { quota_gb = 100 }
        }
      }
      analytics = {
        replication_type = "ZRS"
        file_shares = {
          models = { quota_gb = 200 }
        }
      }
    }
  }
  assert {
    condition = (
      length(module.premium_files) == 2 &&
      length(output.premium_file_accounts) == 2 &&
      length(module.premium_files_private_endpoint) == 2 &&
      length(output.private_endpoint_ids.premium_files) == 2 &&
      length(output.premium_file_accounts["primary"].file_share_ids) == 1 &&
      length(output.premium_file_accounts["analytics"].file_share_ids) == 1 &&
      output.premium_file_accounts["primary"].name == "stpfprimae3b7cmetletest1" &&
      output.premium_file_accounts["analytics"].name != output.premium_file_accounts["primary"].name &&
      length(output.premium_file_accounts["analytics"].name) <= 24 &&
      output.premium_file_accounts["primary"].file_hostname == "stpfprimae3b7cmetletest1.file.core.windows.net"
    )
    error_message = "Each premium_file_accounts entry must create one distinctly named FileStorage account, its shares, and a file Private Endpoint."
  }
}

run "reject_invalid_storage_account_key" {
  command = plan
  variables {
    storage_accounts = {
      Invalid = {}
    }
  }
  expect_failures = [var.storage_accounts]
}

run "reject_invalid_premium_file_account_key" {
  command = plan
  variables {
    premium_file_accounts = {
      "bad--key" = {}
    }
  }
  expect_failures = [var.premium_file_accounts]
}

run "reject_shared_key_provider_with_keyless_account" {
  command = plan
  variables {
    storage_use_azuread = false
    storage_accounts = {
      primary = {
        file_shares               = {}
        shared_access_key_enabled = false
      }
    }
  }
  expect_failures = [var.storage_use_azuread]
}

run "container_apps_consumption" {
  command = plan
  variables {
    services = merge(var.services, { container_apps = true })
  }
  assert {
    condition = (
      length(output.container_app_dedicated_workload_profile_names) == 0 &&
      output.container_app_workload_profile_name == "Consumption"
    )
    error_message = "The root default must retain Consumption-only placement."
  }
}

run "container_apps_single_profile" {
  command = plan
  variables {
    services = merge(var.services, { container_apps = true })
    container_apps = {
      dedicated_workload_profiles = { general = { workload_profile_type = "D4" } }
      app_workload_profile        = "general"
    }
  }
  assert {
    condition = (
      output.container_app_dedicated_workload_profile_names["general"] == "wp-general01" &&
      output.container_app_workload_profile_name == output.container_app_dedicated_workload_profile_names["general"] &&
      output.container_app_dedicated_workload_profile_name == output.container_app_dedicated_workload_profile_names["general"]
    )
    error_message = "A single dedicated profile must use its deterministic Azure name, remain selectable through tfvars, and be available through both output shapes."
  }
}

run "container_apps_multiple_profiles" {
  command = plan
  variables {
    services = merge(var.services, { container_apps = true })
    container_apps = {
      dedicated_workload_profiles = {
        general = { workload_profile_type = "D4", minimum_count = 0, maximum_count = 3 }
        memory  = { workload_profile_type = "E4", minimum_count = 1, maximum_count = 2 }
      }
      app_workload_profile = "memory"
    }
  }
  assert {
    condition = (
      output.container_app_workload_profile_name == output.container_app_dedicated_workload_profile_names["memory"] &&
      output.container_app_dedicated_workload_profile_names["general"] == "wp-general01" &&
      output.container_app_dedicated_workload_profile_names["memory"] == "wp-memory01" &&
      output.container_app_dedicated_workload_profile_names["general"] == run.container_apps_single_profile.container_app_dedicated_workload_profile_names["general"] &&
      length(distinct(values(output.container_app_dedicated_workload_profile_names))) == 2 &&
      alltrue([for name in values(output.container_app_dedicated_workload_profile_names) : length(name) <= 15]) &&
      output.container_app_dedicated_workload_profile_name == null
    )
    error_message = "Root configuration must pass logical placement and generate the requested deterministic Azure profile names."
  }
}

run "container_apps_long_profile_prefix" {
  command = plan
  variables {
    services = merge(var.services, { container_apps = true })
    naming = {
      unique_suffix = "test1"
      prefixes      = { container_apps_profile = "longprefix" }
    }
    container_apps = {
      dedicated_workload_profiles = {
        general = { workload_profile_type = "D4" }
        memory  = { workload_profile_type = "E4" }
      }
    }
  }
  assert {
    condition = (
      output.container_app_dedicated_workload_profile_names["general"] == "lon-${substr(sha1("general"), 0, 8)}01" &&
      output.container_app_dedicated_workload_profile_names["memory"] == "lon-${substr(sha1("memory"), 0, 8)}01" &&
      length(distinct(values(output.container_app_dedicated_workload_profile_names))) == 2 &&
      alltrue([for name in values(output.container_app_dedicated_workload_profile_names) : length(name) <= 15])
    )
    error_message = "Long profile prefixes must fall back to unique deterministic names within Azure's 15-character limit."
  }
}

run "container_apps_legacy_profile" {
  command = plan
  variables {
    services = merge(var.services, { container_apps = true })
    container_apps = {
      dedicated_workload_profile = {
        enabled               = true
        workload_profile_type = "D4"
        minimum_count         = 0
        maximum_count         = 3
        use_for_app           = true
      }
    }
  }
  assert {
    condition = (
      output.container_app_workload_profile_name == "wp-legacy01" &&
      output.container_app_dedicated_workload_profile_name == "wp-legacy01" &&
      output.container_app_dedicated_workload_profile_names["legacy"] == "wp-legacy01"
    )
    error_message = "The legacy profile must use a plan-time-known Azure name and retain app placement."
  }
}

run "windows_function_app" {
  command = plan
  variables {
    function_app = {
      os_type = "Windows"
      runtime = { name = "dotnet-isolated", version = "8.0" }
    }
  }
  assert {
    condition = (
      output.function_app_os_type == "Windows" &&
      output.function_app_hostname == "func-windows.azurewebsites.net" &&
      endswith(module.function_app[0].id, "/sites/func-windows") &&
      length(module.function_app_private_endpoint) == 1 &&
      output.virtual_machines["primary"].os_type == "Linux"
    )
    error_message = "Root tfvars must select Windows Functions independently of VM OS and preserve the existing app ID/hostname and Private Endpoint wiring."
  }
}

run "windows_function_app_node" {
  command = plan
  variables {
    function_app = {
      os_type = "Windows"
      runtime = { name = "node", version = "22" }
    }
  }
  assert {
    condition     = output.function_app_os_type == "Windows" && output.function_app_hostname == "func-windows.azurewebsites.net"
    error_message = "Windows Node must be selectable through the root object."
  }
}
