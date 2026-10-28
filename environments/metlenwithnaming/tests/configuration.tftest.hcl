# The azurerm.hub alias is configured even when hub_peering is unset.
mock_provider "azurerm" {
  alias = "hub"
}

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
    override_during = plan
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
      virtual_machines              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vms"
      private_endpoints             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/endpoints"
      web_app_integration           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web-app"
      function_integration          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
      "container_apps/primary"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps-primary"
      "container_apps/jobs"         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps-jobs"
      "container_apps/longenvname1" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps-long"
      load_balancers                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/lb"
      mysql                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/mysql"
      postgresql                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/postgresql"
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
      for service in ["vaultcore.azure.net", "database.windows.net", "documents.azure.com", "gremlin.cosmos.azure.com", "cassandra.cosmos.azure.com", "table.cosmos.azure.com", "mongo.cosmos.azure.com", "azurecr.io", "blob.core.windows.net", "file.core.windows.net", "queue.core.windows.net", "table.core.windows.net", "azurewebsites.net", "mysql.database.azure.com", "postgres.database.azure.com"] :
      "privatelink.${service}" => "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.${service}"
    }
  }
}

override_module {
  target = module.function_storage["primary"]
  outputs = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/stfunctiontest"
    name               = "stfunctiontest"
    primary_access_key = "test-only-storage-key"
  }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  subscription_id             = "00000000-0000-0000-0000-000000000000"
  tenant_id                   = "22222222-2222-2222-2222-222222222222"
  naming                      = { unique_suffix = "test1" }
  container_apps_environments = {}
  load_balancers              = {}
  web_apps                    = {}
  app_service_plans = {
    functions = { sequence = "01", sku_name = "EP1" }
  }
  function_apps = {
    primary = { service_plan = "functions", storage_sequence = "09" }
  }
  virtual_machines = {
    primary = {}
  }
  storage_accounts      = {}
  premium_file_accounts = {}
  storage_use_azuread   = true
  location              = "swedencentral"
  project_name          = "metlen"
  environment           = "lab"
  naming_tokens         = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  address_space         = ["10.42.0.0/20"]
  subnet_cidrs = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }
  virtual_machine_scale_sets = {}
  nat_gateway                = {}
  log_analytics_workspace    = {}
  key_vaults                 = {}
  container_registries       = {}
  azure_sql_servers          = {}
  cosmos_db_accounts         = {}
  sql_managed_instances      = {}
  postgresql_servers         = {}
  mysql_servers              = {}
  tags                       = {}
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
}

run "linux_defaults" {
  command = plan
  assert {
    condition = (
      output.virtual_machines["primary"].os_type == "Linux" &&
      output.virtual_machines["primary"].name == "vm-primary-metlen-lab-test1" &&
      output.virtual_machines["primary"].admin_username == "azureadmin" &&
      output.function_apps["primary"].os_type == "Linux" &&
      output.function_apps["primary"].hostname == "func-linux.azurewebsites.net" &&
      output.generated_resource_names.virtual_network == "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE" &&
      output.generated_resource_names.subnets == {
        private_endpoints    = "PPAECMDEVPRV01"
        virtual_machines     = "PPAECMDEVPRV02"
        web_app_integration  = "PPAECMDEVPRV03"
        function_integration = "PPAECMDEVPRV04"
        postgresql           = "PPAECMDEVPRV05"
        mysql                = "PPAECMDEVPRV06"
        sql_managed_instance = "PPAECMDEVPRV07"
        load_balancers       = "PPAECMDEVPRV08"
      }
    )
    error_message = "Linux defaults must sign in with the default admin username, and network names must follow the METLEN VNT and <DPT><APP><ENV>PRV<NN> subnet patterns."
  }
}

run "windows_and_node" {
  command = plan
  variables {
    environment      = "long-env"
    virtual_machines = { primary = { os_type = "Windows" } }
    function_apps = {
      primary = {
        service_plan     = "functions"
        storage_sequence = "09"
        runtime          = { name = "node", version = "22" }
      }
    }
  }
  assert {
    condition = (
      output.virtual_machines["primary"].os_type == "Windows" &&
      output.virtual_machines["primary"].admin_username == "azureadmin"
    )
    error_message = "A Windows VM must sign in with the admin username and the shared vm_admin_password."
  }
}

run "reject_missing_vm_admin_password" {
  command = plan
  variables {
    vm_admin_password = null
  }
  expect_failures = [var.vm_admin_password]
}

run "reject_weak_vm_admin_password" {
  command = plan
  variables {
    vm_admin_password = "alllowercaseletters"
  }
  expect_failures = [var.vm_admin_password]
}

run "vm_admin_password_optional_without_machines" {
  command = plan
  variables {
    virtual_machines  = {}
    vm_admin_password = null
  }
  assert {
    condition     = length(module.virtual_machine) == 0
    error_message = "vm_admin_password must only be required when VMs or scale sets exist."
  }
}

run "reject_missing_database_admin_password" {
  command = plan
  variables {
    mysql_servers           = { primary = {} }
    database_admin_password = null
  }
  expect_failures = [var.database_admin_password]
}

run "reject_weak_database_admin_password" {
  command = plan
  variables {
    postgresql_servers      = { primary = {} }
    database_admin_password = "Short1!"
  }
  expect_failures = [var.database_admin_password]
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
      output.virtual_machines["api"].name == "vm-api-metlen-lab-test1" &&
      output.virtual_machines["worker"].name == "vm-worker-metlen-lab-test1" &&
      output.virtual_machines["admin"].name == "vm-admin-metlen-lab-test1" &&
      output.virtual_machines["admin"].os_type == "Windows"
    )
    error_message = "Each virtual_machines entry must create one independently named VM."
  }
}

run "vmss_linux_autoscale" {
  command = plan
  variables {
    virtual_machine_scale_sets = {
      web = {
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
  }
  assert {
    condition = (
      output.virtual_machine_scale_sets["web"].name == "vmss-web-metlen-lab-test1" &&
      output.virtual_machine_scale_sets["web"].os_type == "Linux" &&
      output.virtual_machine_scale_sets["web"].scaling_mode == "autoscale" &&
      local.resource_names.virtual_machine_scale_sets["web"].network_interface_name == "nic-vmss-web-metlen-lab-test1" &&
      local.resource_names.virtual_machine_scale_sets["web"].autoscale_setting_name == "autoscale-web-metlen-lab-test1" &&
      output.virtual_machine_scale_sets["web"].computer_name_prefix == "vmss${substr(sha1("web"), 0, 5)}" &&
      output.virtual_machine_scale_sets["web"].admin_username == "azureadmin" &&
      length(module.virtual_machine_scale_set) == 1
    )
    error_message = "A Linux scale set entry must create a keyed scale set with its own names, hostname prefix, and autoscaling."
  }
}

run "vmss_windows_fixed" {
  command = plan
  variables {
    virtual_machine_scale_sets = {
      jobs = { os_type = "Windows", scaling = { mode = "fixed", default_instances = 2 } }
    }
  }
  assert {
    condition = (
      output.virtual_machine_scale_sets["jobs"].os_type == "Windows" &&
      output.virtual_machine_scale_sets["jobs"].scaling_mode == "fixed" &&
      length(output.virtual_machine_scale_sets["jobs"].computer_name_prefix) <= 9
    )
    error_message = "A Windows scale set entry must use fixed capacity and a hostname prefix within the Windows limit."
  }
}

run "multiple_vm_scale_sets" {
  command = plan
  variables {
    virtual_machines = {}
    virtual_machine_scale_sets = {
      web  = {}
      api  = {}
      jobs = { os_type = "Windows" }
    }
  }
  assert {
    condition = (
      length(module.virtual_machine_scale_set) == 3 &&
      length(distinct([for names in values(local.resource_names.virtual_machine_scale_sets) : names.computer_name_prefix])) == 3 &&
      length(distinct([for names in values(local.resource_names.virtual_machine_scale_sets) : names.name])) == 3 &&
      length(distinct([for names in values(local.resource_names.virtual_machine_scale_sets) : names.autoscale_setting_name])) == 3 &&
      local.subnet_enabled.virtual_machines &&
      length(module.nat_gateway) == 0 &&
      length(module.virtual_machine) == 0
    )
    error_message = "Each scale set entry must have its own names and hostname prefix while sharing the VM subnet; no NAT Gateway unless nat_gateway.subnets lists it."
  }
}

run "reject_invalid_vm_scale_set_key" {
  command = plan
  variables {
    virtual_machine_scale_sets = {
      "Bad_Key" = {}
    }
  }
  expect_failures = [var.virtual_machine_scale_sets]
}

run "vmss_only_keeps_shared_network" {
  command = plan
  variables {
    virtual_machines           = {}
    virtual_machine_scale_sets = { app = {} }
    function_apps              = {}
    app_service_plans          = {}
    nat_gateway                = { subnets = ["virtual_machines"] }
  }
  assert {
    condition = (
      local.nat_gateway_required &&
      local.subnet_enabled.virtual_machines &&
      length(module.nat_gateway) == 1 &&
      length(module.virtual_machine) == 0 &&
      length(module.virtual_machine_scale_set) == 1
    )
    error_message = "A VMSS-only lab must retain the shared VM subnet and its NAT Gateway without creating the standalone VM."
  }
}

run "nat_gateway_is_opt_in" {
  command = plan
  assert {
    condition = (
      !local.nat_gateway_required &&
      length(module.nat_gateway) == 0 &&
      output.nat_gateway_id == null &&
      output.nat_gateway_public_ip_address == null
    )
    error_message = "Without nat_gateway.subnets no NAT Gateway or Public IP may be created, even when VMs exist."
  }
}

run "nat_gateway_per_subnet" {
  command = plan
  variables {
    nat_gateway = { subnets = ["virtual_machines", "function_integration"] }
  }
  assert {
    condition = (
      length(module.nat_gateway) == 1 &&
      toset(local.nat_gateway_subnet_keys) == toset(["virtual_machines", "function_integration"])
    )
    error_message = "The NAT Gateway must be associated with exactly the subnets listed in nat_gateway.subnets."
  }
}

run "hub_and_spoke_egress_without_nat_gateway" {
  command = plan
  variables {
    route_tables = {
      egress = {
        subnets = ["virtual_machines"]
        routes = {
          default-to-hub = {
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = "10.0.0.4"
          }
        }
      }
    }
  }
  assert {
    condition     = length(module.nat_gateway) == 0 && length(module.route_table) == 1
    error_message = "A spoke that routes 0.0.0.0/0 to the hub must deploy without a NAT Gateway."
  }
}

run "warn_when_route_bypasses_nat_gateway" {
  command = plan
  variables {
    nat_gateway = { subnets = ["virtual_machines"] }
    route_tables = {
      egress = {
        subnets = ["virtual_machines"]
        routes = {
          default-to-hub = {
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = "10.0.0.4"
          }
        }
      }
    }
  }
  expect_failures = [check.nat_gateway_bypassed]
}

run "reject_nat_gateway_subnet_not_deployed" {
  command = plan
  variables {
    nat_gateway = { subnets = ["mysql"] }
  }
  expect_failures = [var.nat_gateway]
}

run "reject_duplicate_nat_gateway_subnet" {
  command = plan
  variables {
    nat_gateway = { subnets = ["virtual_machines", "virtual_machines"] }
  }
  expect_failures = [var.nat_gateway]
}

run "subnets_are_private" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      primary = {}
    }
  }
  assert {
    condition = (
      contains(keys(local.subnets), "container_apps/primary") &&
      alltrue([for subnet in values(local.subnets) : !subnet.default_outbound_access_enabled])
    )
    error_message = "Every subnet must be private (no implicit default outbound access)."
  }
}

run "disabled_services" {
  command = plan
  variables {
    virtual_machines  = {}
    function_apps     = {}
    app_service_plans = {}
  }
  assert {
    condition = (
      length(output.virtual_machines) == 0 &&
      length(output.virtual_machine_scale_sets) == 0 &&
      length(module.function_app) == 0 &&
      length(module.function_storage) == 0 &&
      length(output.function_apps) == 0 &&
      !local.subnet_enabled.function_integration &&
      length(output.container_registries) == 0 &&
      length(output.web_apps) == 0 &&
      length(module.app_service_plan) == 0 &&
      length(output.container_apps_environments) == 0 &&
      output.log_analytics_workspace_id == null
    )
    error_message = "Disabled services must not generate VM credentials or a Function App."
  }
}

run "web_app_linux_default" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps          = { primary = { service_plan = "web" } }
  }
  assert {
    condition = (
      output.web_apps["primary"].mode == "linux" &&
      output.web_apps["primary"].hostname == "app-linux.azurewebsites.net" &&
      endswith(output.web_apps["primary"].id, "/sites/app-linux") &&
      output.web_apps["primary"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-00" &&
      output.web_apps["primary"].service_plan == "web" &&
      output.web_apps["primary"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00" &&
      output.app_service_plans["web"].web_apps == tolist(["primary"]) &&
      output.app_service_plans["web"].sku_name == "B1" &&
      length(module.app_service_plan) == 2 &&
      length(module.web_app) == 1 &&
      local.subnet_enabled.web_app_integration &&
      contains(keys(module.private_endpoints), "web_app/primary") &&
      output.private_endpoint_ids.web_apps["primary"] != null
    )
    error_message = "A web_apps entry must create a private Linux Web App on its selected plan, with its own Private Endpoint."
  }
}

run "web_app_windows" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00", os_type = "Windows" } })
    web_apps = {
      primary = {
        service_plan = "web"
        mode         = "windows"
        runtime      = { name = "dotnet", version = "8.0" }
      }
    }
  }
  assert {
    condition = (
      output.web_apps["primary"].mode == "windows" &&
      output.web_apps["primary"].hostname == "app-windows.azurewebsites.net" &&
      endswith(output.web_apps["primary"].id, "/sites/app-windows") &&
      output.web_apps["primary"].principal_id == "44444444-4444-4444-4444-444444444444"
    )
    error_message = "The root configuration must select a private Windows Web App independently of the VM and Function App OS."
  }
}

run "web_app_container" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps          = { primary = { service_plan = "web", mode = "container" } }
  }
  assert {
    condition = (
      output.web_apps["primary"].mode == "container" &&
      output.web_apps["primary"].hostname == "app-linux.azurewebsites.net" &&
      endswith(output.web_apps["primary"].id, "/sites/app-linux")
    )
    error_message = "Container mode must use the Linux Web App resource and preserve private endpoint wiring."
  }
}

run "web_apps_share_a_plan" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps = {
      portal = { service_plan = "web" }
      api    = { service_plan = "web", sequence = "01", mode = "container" }
    }
  }
  assert {
    condition = (
      length(module.app_service_plan) == 2 &&
      length(module.web_app) == 2 &&
      output.web_apps["portal"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00" &&
      output.web_apps["api"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00" &&
      output.app_service_plans["web"].web_apps == tolist(["api", "portal"])
    )
    error_message = "Several Web Apps must be able to share one App Service Plan."
  }
}

run "multiple_web_apps_on_separate_plans" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, {
      portal = { sequence = "00" }
      api    = { sequence = "02", os_type = "Windows", sku_name = "P0v3" }
    })
    web_apps = {
      portal = { service_plan = "portal" }
      api = {
        service_plan = "api"
        sequence     = "01"
        mode         = "windows"
        runtime      = { name = "dotnet", version = "8.0" }
      }
    }
  }
  assert {
    condition = (
      length(module.app_service_plan) == 3 &&
      length(module.web_app) == 2 &&
      output.web_apps["portal"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-00" &&
      output.web_apps["portal"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-00" &&
      output.web_apps["api"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-01" &&
      output.web_apps["api"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-02" &&
      output.app_service_plans["api"].sku_name == "P0v3" &&
      output.web_apps["portal"].mode == "linux" &&
      output.web_apps["api"].mode == "windows" &&
      local.private_endpoint_names["web_app/api"].name == "M-AZU-APP-IT-PPA-ECM-DEV-SWE-01-sites" &&
      length([for key in keys(module.private_endpoints) : key if startswith(key, "web_app/")]) == 2 &&
      keys(output.private_endpoint_ids.web_apps) == ["api", "portal"] &&
      length([for key in keys(local.subnets) : key if key == "web_app_integration"]) == 1
    )
    error_message = "Each Web App must run on its selected plan with its own Private Endpoint, and every app must share the one integration subnet."
  }
}

run "reject_duplicate_web_app_sequence" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps = {
      portal = { service_plan = "web" }
      api    = { service_plan = "web" }
    }
  }
  expect_failures = [var.web_apps]
}

run "reject_duplicate_app_service_plan_sequence" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "01" } })
    web_apps          = { primary = { service_plan = "web" } }
  }
  expect_failures = [var.app_service_plans]
}

run "reject_web_app_unknown_plan" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps          = { primary = { service_plan = "webb" } }
  }
  expect_failures = [var.web_apps]
}

run "reject_web_app_on_elastic_premium_plan" {
  command = plan
  variables {
    web_apps = { primary = { service_plan = "functions" } }
  }
  expect_failures = [var.web_apps]
}

run "reject_web_app_os_mismatch" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps          = { primary = { service_plan = "web", mode = "windows", runtime = { name = "dotnet", version = "8.0" } } }
  }
  expect_failures = [var.web_apps]
}

run "reject_container_web_app_on_windows_plan" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00", os_type = "Windows" } })
    web_apps          = { primary = { service_plan = "web", mode = "container" } }
  }
  expect_failures = [var.web_apps]
}

run "reject_invalid_app_service_plan_sku" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00", sku_name = "F1" } })
    web_apps          = { primary = { service_plan = "web" } }
  }
  expect_failures = [var.app_service_plans]
}

run "reject_invalid_web_app_key" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps          = { "Bad_Key" = { service_plan = "web" } }
  }
  expect_failures = [var.web_apps]
}

run "warn_unused_app_service_plan" {
  command = plan
  variables {
    app_service_plans = merge(var.app_service_plans, { spare = { sequence = "05" } })
  }
  assert {
    condition     = local.unused_app_service_plans == tolist(["spare"])
    error_message = "An App Service Plan that no app uses must be reported."
  }
  expect_failures = [check.unused_app_service_plans]
}

run "reject_web_apps_on_two_plans_below_26" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { web_app_integration = "10.42.8.0/27" })
    app_service_plans = merge(var.app_service_plans, {
      portal = { sequence = "00" }
      api    = { sequence = "02" }
    })
    web_apps = {
      portal = { service_plan = "portal" }
      api    = { service_plan = "api", sequence = "01" }
    }
  }
  expect_failures = [var.web_apps]
}

run "web_apps_on_one_plan_allow_small_subnet" {
  command = plan
  variables {
    subnet_cidrs      = merge(var.subnet_cidrs, { web_app_integration = "10.42.8.0/28" })
    app_service_plans = merge(var.app_service_plans, { web = { sequence = "00" } })
    web_apps = {
      portal = { service_plan = "web" }
      api    = { service_plan = "web", sequence = "01" }
    }
  }
  assert {
    condition     = length(module.web_app) == 2
    error_message = "Apps on a single plan do not use multi-plan subnet join, so a subnet smaller than /26 must stay allowed."
  }
}

run "multiple_container_registries" {
  command = plan
  variables {
    container_registries = {
      primary = {}
      images  = { sequence = "01" }
    }
  }
  assert {
    condition = (
      length(module.container_registry) == 2 &&
      output.container_registries["primary"].name == "mazuacritppaecmdevswe00" &&
      output.container_registries["images"].name == "mazuacritppaecmdevswe01" &&
      output.container_registries["primary"].sku == "Premium" &&
      alltrue([
        for name in values(local.resource_names.container_registries) :
        can(regex("^[a-z0-9]{5,50}$", name))
      ]) &&
      local.private_endpoint_names["container_registry/images"].name == "mazuacritppaecmdevswe01-registry" &&
      length([for key in keys(module.private_endpoints) : key if startswith(key, "container_registry/")]) == 2 &&
      length(output.private_endpoint_ids.container_registries) == 2 &&
      contains(local.private_dns_zones, "privatelink.azurecr.io")
    )
    error_message = "Each container_registries entry must create one distinctly named Premium registry in the mazuacr compact family with its own registry Private Endpoint."
  }
}

run "reject_duplicate_container_registry_sequence" {
  command = plan
  variables {
    container_registries = {
      primary = {}
      images  = {}
    }
  }
  expect_failures = [var.container_registries]
}

run "reject_invalid_container_registry_key" {
  command = plan
  variables {
    container_registries = {
      "Bad_Key" = {}
    }
  }
  expect_failures = [var.container_registries]
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
      output.storage_accounts["primary"].name == "mazusoaitppaecmdevswe00"
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
        sequence         = "01"
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
      keys(module.storage_private_endpoints) == ["archive", "primary"] &&
      length(output.private_endpoint_ids.storage["primary"]) == 2 &&
      length(output.private_endpoint_ids.storage["archive"]) == 2 &&
      output.storage_accounts["primary"].name == "mazusoaitppaecmdevswe00" &&
      output.storage_accounts["archive"].name == "mazusoaitppaecmdevswe01" &&
      output.storage_accounts["primary"].blob_hostname == "mazusoaitppaecmdevswe00.blob.core.windows.net" &&
      local.private_endpoint_names["storage/archive/file"].name == "mazusoaitppaecmdevswe01-file"
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
        sequence         = "01"
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
      length([for key in keys(module.private_endpoints) : key if startswith(key, "premium_files/")]) == 2 &&
      length(output.private_endpoint_ids.premium_files) == 2 &&
      length(output.premium_file_accounts["primary"].file_share_ids) == 1 &&
      length(output.premium_file_accounts["analytics"].file_share_ids) == 1 &&
      output.premium_file_accounts["primary"].name == "mazusoaitppaecmdevswe00" &&
      output.premium_file_accounts["analytics"].name == "mazusoaitppaecmdevswe01" &&
      output.premium_file_accounts["primary"].file_hostname == "mazusoaitppaecmdevswe00.file.core.windows.net"
    )
    error_message = "Each premium_file_accounts entry must create one distinctly named FileStorage account, its shares, and a file Private Endpoint."
  }
}

run "multiple_key_vaults" {
  command = plan
  variables {
    key_vaults = {
      primary = {}
      secrets = {
        sequence                 = "01"
        sku_name                 = "premium"
        purge_protection_enabled = true
      }
    }
  }
  assert {
    condition = (
      length(module.key_vault) == 2 &&
      local.resource_names.key_vaults["primary"] == "mazukvaitppaecmdevswe00" &&
      local.resource_names.key_vaults["secrets"] == "mazukvaitppaecmdevswe01" &&
      output.key_vaults["primary"].hostname == "mazukvaitppaecmdevswe00.vault.azure.net" &&
      module.key_vault["primary"].name == "mazukvaitppaecmdevswe00" &&
      length([for key in keys(module.private_endpoints) : key if startswith(key, "key_vault/")]) == 2 &&
      local.private_endpoint_names["key_vault/secrets"].name == "mazukvaitppaecmdevswe01-vault" &&
      length(output.private_endpoint_ids.key_vaults) == 2 &&
      contains(local.private_dns_zones, "privatelink.vaultcore.azure.net") &&
      local.subnet_enabled.private_endpoints
    )
    error_message = "Each key_vaults entry must create one distinctly named Key Vault with its own vault Private Endpoint."
  }
}

run "reject_invalid_key_vault_key" {
  command = plan
  variables {
    key_vaults = {
      "Bad_Key" = {}
    }
  }
  expect_failures = [var.key_vaults]
}

run "multiple_cosmos_db_accounts" {
  command = plan
  variables {
    cosmos_db_accounts = {
      primary = {}
      graph   = { sequence = "01", api_type = "Gremlin" }
    }
  }
  assert {
    condition = (
      length(module.cosmos_db) == 2 &&
      local.resource_names.cosmos_db_accounts["primary"] == "m-azu-cdb-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.cosmos_db_accounts["graph"] == "m-azu-cdb-it-ppa-ecm-dev-swe-01" &&
      local.resource_names.cosmos_db_databases["graph"] == "graph" &&
      local.resource_names.cosmos_db_containers["graph"] == "graph" &&
      local.service_private_endpoints["cosmos_db/primary"].subresource == "Sql" &&
      local.service_private_endpoints["cosmos_db/graph"].subresource == "Gremlin" &&
      local.private_endpoint_names["cosmos_db/graph"].name == "m-azu-cdb-it-ppa-ecm-dev-swe-01-gremlin" &&
      contains(local.private_dns_zones, "privatelink.documents.azure.com") &&
      contains(local.private_dns_zones, "privatelink.gremlin.cosmos.azure.com") &&
      length(output.private_endpoint_ids.cosmos_db_accounts) == 2
    )
    error_message = "Each cosmos_db_accounts entry must create a distinctly named account whose API selects its own Private Endpoint subresource and DNS zone."
  }
}

# Account names are 3-44 lowercase characters. Database and container names
# are chosen by the application, default to the entry key, and must meet the
# rules of the account's API.
run "cosmos_db_names_are_configurable" {
  command = plan
  variables {
    cosmos_db_accounts = {
      longkeyname = { sequence = "99" }
      catalog     = { sequence = "01", database_name = "catalog-db", container_name = "products" }
      events      = { sequence = "02", api_type = "Cassandra", database_name = "telemetry", container_name = "device_events" }
      lookups     = { sequence = "03", api_type = "Table", container_name = "Countries" }
    }
  }
  assert {
    condition = (
      can(regex("^[a-z0-9][a-z0-9-]{1,42}[a-z0-9]$", local.resource_names.cosmos_db_accounts["longkeyname"])) &&
      local.resource_names.cosmos_db_databases["longkeyname"] == "longkeyname" &&
      local.resource_names.cosmos_db_containers["longkeyname"] == "longkeyname" &&
      local.resource_names.cosmos_db_databases["catalog"] == "catalog-db" &&
      local.resource_names.cosmos_db_containers["catalog"] == "products" &&
      local.resource_names.cosmos_db_databases["events"] == "telemetry" &&
      local.resource_names.cosmos_db_containers["events"] == "device_events" &&
      local.resource_names.cosmos_db_containers["lookups"] == "Countries"
    )
    error_message = "Cosmos DB database and container names must use database_name and container_name, or the entry key when unset."
  }
}

run "reject_cassandra_key_with_hyphen_as_default_name" {
  command = plan
  variables {
    cosmos_db_accounts = {
      raw-events = { api_type = "Cassandra" }
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "reject_table_container_name_with_underscore" {
  command = plan
  variables {
    cosmos_db_accounts = {
      lookups = { api_type = "Table", container_name = "country_codes" }
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "reject_nosql_container_name_with_slash" {
  command = plan
  variables {
    cosmos_db_accounts = {
      primary = { container_name = "orders/2026" }
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "reject_duplicate_cosmos_db_sequence" {
  command = plan
  variables {
    cosmos_db_accounts = {
      primary = {}
      graph   = { api_type = "Gremlin" }
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "reject_invalid_cosmos_db_key" {
  command = plan
  variables {
    cosmos_db_accounts = {
      "Bad_Key" = {}
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "reject_invalid_cosmos_db_api" {
  command = plan
  variables {
    cosmos_db_accounts = {
      primary = { api_type = "Etcd" }
    }
  }
  expect_failures = [var.cosmos_db_accounts]
}

run "multiple_azure_sql_servers" {
  command = plan
  variables {
    azure_sql_servers = {
      primary = {}
      reports = {
        sequence     = "01"
        elastic_pool = { enabled = true }
      }
    }
  }
  assert {
    condition = (
      length(module.azure_sql) == 2 &&
      local.resource_names.azure_sql_servers["primary"].server_name == "m-azu-sql-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.azure_sql_servers["primary"].database_name == "primary" &&
      local.resource_names.azure_sql_servers["reports"].server_name == "m-azu-sql-it-ppa-ecm-dev-swe-01" &&
      local.resource_names.azure_sql_servers["reports"].database_name == "reports" &&
      local.resource_names.azure_sql_servers["reports"].elastic_pool_name == "M-AZU-SEL-IT-PPA-ECM-DEV-SWE-01" &&
      output.azure_sql_servers["primary"].elastic_pool_id == null &&
      output.azure_sql_servers["reports"].elastic_pool_name == "M-AZU-SEL-IT-PPA-ECM-DEV-SWE-01" &&
      local.service_private_endpoints["azure_sql/primary"].subresource == "sqlServer" &&
      local.private_endpoint_names["azure_sql/reports"].name == "m-azu-sql-it-ppa-ecm-dev-swe-01-sqlserver" &&
      length([for key in keys(module.private_endpoints) : key if startswith(key, "azure_sql/")]) == 2 &&
      length(output.private_endpoint_ids.azure_sql_servers) == 2 &&
      contains(local.private_dns_zones, "privatelink.database.windows.net")
    )
    error_message = "Each azure_sql_servers entry must create a distinctly named server and database, an elastic pool only when enabled, and its own sqlServer Private Endpoint."
  }
}

run "reject_duplicate_azure_sql_server_sequence" {
  command = plan
  variables {
    azure_sql_servers = {
      primary = {}
      reports = {}
    }
  }
  expect_failures = [var.azure_sql_servers]
}

run "reject_invalid_azure_sql_server_key" {
  command = plan
  variables {
    azure_sql_servers = {
      "Bad_Key" = {}
    }
  }
  expect_failures = [var.azure_sql_servers]
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

run "container_apps_single_environment" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, {
      container_apps = {
        primary = "10.42.2.0/27"
        spare   = "10.42.3.0/27"
      }
    })
    container_apps_environments = {
      primary = { apps = { hello = {} } }
    }
  }
  assert {
    condition = (
      length(module.container_apps) == 1 &&
      length(module.log_analytics) == 1 &&
      output.log_analytics_workspace_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test" &&
      local.resource_names.container_apps_environments["primary"].name == "M-AZU-CEV-IT-PPA-ECM-DEV-SWE-00" &&
      local.resource_names.container_apps_environments["primary"].apps["hello"] == "m-azu-cap-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.container_apps_environments["primary"].private_dns_link_name == "pdnslink-container-apps-primary-metlen-lab-test1" &&
      local.subnets["container_apps/primary"].name == "PPAECMDEVPRV09" &&
      local.subnets["container_apps/primary"].address_prefixes == ["10.42.2.0/27"] &&
      local.subnets["container_apps/primary"].delegation.service == "Microsoft.App/environments" &&
      local.planned_subnet_address_prefixes["container_apps/primary"] == ["10.42.2.0/27"] &&
      !contains(keys(local.subnets), "container_apps/spare") &&
      local.planned_subnet_address_prefixes["container_apps/spare"] == ["10.42.3.0/27"] &&
      length(module.nat_gateway) == 0 &&
      length(output.container_apps_environments["primary"].dedicated_workload_profile_names) == 0 &&
      output.container_apps_environments["primary"].apps["hello"].workload_profile_name == "Consumption"
    )
    error_message = "An environment must use the subnet_cidrs.container_apps range with its own key, with no NAT Gateway unless listed, while unused ranges are only reserved."
  }
}

run "multiple_container_apps_environments" {
  command = plan
  variables {
    virtual_machines = {}
    subnet_cidrs = merge(var.subnet_cidrs, {
      container_apps = {
        primary = "10.42.2.0/27"
        jobs    = "10.42.3.0/24"
      }
    })
    container_apps_environments = {
      primary = {
        apps = {
          hello = {}
          api   = { sequence = "01", target_port = 8080 }
        }
      }
      jobs = {
        sequence      = "01"
        subnet_number = 8
        dedicated_workload_profiles = {
          general = { workload_profile_type = "D4" }
        }
        apps = {
          worker = { sequence = "02", workload_profile = "general" }
        }
      }
    }
    nat_gateway = { subnets = ["container_apps/primary", "container_apps/jobs"] }
  }
  assert {
    condition = (
      length(module.container_apps) == 2 &&
      length(module.log_analytics) == 1 &&
      local.nat_gateway_required &&
      toset(local.nat_gateway_subnet_keys) == toset(["container_apps/primary", "container_apps/jobs"]) &&
      local.subnets["container_apps/primary"].address_prefixes == ["10.42.2.0/27"] &&
      local.subnets["container_apps/jobs"].address_prefixes == ["10.42.3.0/24"] &&
      local.subnets["container_apps/primary"].name == "PPAECMDEVPRV09" &&
      local.subnets["container_apps/jobs"].name == "PPAECMDEVPRV08" &&
      local.resource_names.container_apps_environments["jobs"].name == "M-AZU-CEV-IT-PPA-ECM-DEV-SWE-01" &&
      local.resource_names.container_apps_environments["primary"].private_dns_link_name != local.resource_names.container_apps_environments["jobs"].private_dns_link_name &&
      local.resource_names.container_apps_environments["primary"].apps["api"] == "m-azu-cap-it-ppa-ecm-dev-swe-01" &&
      local.resource_names.container_apps_environments["jobs"].apps["worker"] == "m-azu-cap-it-ppa-ecm-dev-swe-02" &&
      length(output.container_apps_environments["primary"].apps) == 2 &&
      length(output.container_apps_environments["primary"].dedicated_workload_profile_names) == 0 &&
      output.container_apps_environments["jobs"].dedicated_workload_profile_names["general"] == "wp-general01" &&
      output.container_apps_environments["jobs"].apps["worker"].workload_profile_name == "wp-general01" &&
      output.container_apps_environments["primary"].apps["api"].workload_profile_name == "Consumption"
    )
    error_message = "Each environment must get the range matching its key, its own DNS link, workload profiles, and apps, and share one workspace and the NAT Gateway."
  }
}

run "container_apps_multiple_profiles" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/23" } })
    container_apps_environments = {
      primary = {
        dedicated_workload_profiles = {
          general = { workload_profile_type = "D4", minimum_count = 0, maximum_count = 3 }
          memory  = { workload_profile_type = "E4", minimum_count = 1, maximum_count = 2 }
        }
        apps = {
          hello = { workload_profile = "memory" }
          api   = { sequence = "01", workload_profile = "general" }
        }
      }
    }
  }
  assert {
    condition = (
      output.container_apps_environments["primary"].dedicated_workload_profile_names == { general = "wp-general01", memory = "wp-memory01" } &&
      output.container_apps_environments["primary"].apps["hello"].workload_profile_name == "wp-memory01" &&
      output.container_apps_environments["primary"].apps["api"].workload_profile_name == "wp-general01"
    )
    error_message = "Root configuration must pass logical placement per app and generate deterministic Azure profile names."
  }
}

run "container_apps_long_profile_prefix" {
  command = plan
  variables {
    naming = {
      unique_suffix = "test1"
      prefixes      = { container_apps_profile = "longprefix" }
    }
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      primary = {
        dedicated_workload_profiles = {
          general = { workload_profile_type = "D4" }
          memory  = { workload_profile_type = "E4" }
        }
      }
    }
  }
  assert {
    condition = (
      output.container_apps_environments["primary"].dedicated_workload_profile_names["general"] == "lon-${substr(sha1("general"), 0, 8)}01" &&
      output.container_apps_environments["primary"].dedicated_workload_profile_names["memory"] == "lon-${substr(sha1("memory"), 0, 8)}01" &&
      alltrue([for name in values(output.container_apps_environments["primary"].dedicated_workload_profile_names) : length(name) <= 15]) &&
      length(output.container_apps_environments["primary"].apps) == 0
    )
    error_message = "Long profile prefixes must fall back to unique deterministic names within Azure's 15-character limit."
  }
}

run "container_app_names_fit_azure_limits" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { longenvname1 = "10.42.2.0/27" } })
    container_apps_environments = {
      longenvname1 = { sequence = "99", apps = { longappname1 = { sequence = "99" } } }
    }
  }
  assert {
    condition = (
      local.resource_names.container_apps_environments["longenvname1"].apps["longappname1"] == "m-azu-cap-it-ppa-ecm-dev-swe-99" &&
      can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", local.resource_names.container_apps_environments["longenvname1"].apps["longappname1"])) &&
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,58}[a-zA-Z0-9]$", local.resource_names.container_apps_environments["longenvname1"].name))
    )
    error_message = "Container App names must stay within Azure's 2-32 lowercase limit and environment names within 2-60 characters, independent of the logical keys."
  }
}

run "reject_container_apps_environment_without_range" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      jobs = {}
    }
  }
  expect_failures = [var.container_apps_environments]
}

run "reject_small_container_apps_subnet" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/28" } })
  }
  expect_failures = [var.subnet_cidrs]
}

run "reject_invalid_container_apps_range_key" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { "Primary_1" = "10.42.2.0/27" } })
  }
  expect_failures = [var.subnet_cidrs]
}

run "reject_invalid_container_apps_environment_key" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      "primary-" = {}
    }
  }
  expect_failures = [var.container_apps_environments]
}

run "reject_overlong_container_app_key" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { container_apps = { primary = "10.42.2.0/27" } })
    container_apps_environments = {
      primary = { apps = { thirteenchars = {} } }
    }
  }
  expect_failures = [var.container_apps_environments]
}

run "reject_duplicate_container_app_sequence_across_environments" {
  command = plan
  variables {
    virtual_machines = {}
    subnet_cidrs = merge(var.subnet_cidrs, {
      container_apps = {
        primary = "10.42.2.0/27"
        jobs    = "10.42.3.0/27"
      }
    })
    container_apps_environments = {
      primary = { apps = { hello = {} } }
      jobs    = { sequence = "01", subnet_number = 8, apps = { worker = {} } }
    }
  }
  expect_failures = [var.container_apps_environments]
}

run "reject_duplicate_container_apps_environment_sequence" {
  command = plan
  variables {
    virtual_machines = {}
    subnet_cidrs = merge(var.subnet_cidrs, {
      container_apps = {
        primary = "10.42.2.0/27"
        jobs    = "10.42.3.0/27"
      }
    })
    container_apps_environments = {
      primary = {}
      jobs    = { subnet_number = 8 }
    }
  }
  expect_failures = [var.container_apps_environments]
}

run "load_balancer_with_vm_and_vmss_members" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/26" })
    virtual_machines = {
      primary = { load_balancer = "web" }
      worker  = { data_disks = {} }
    }
    virtual_machine_scale_sets = {
      app = { load_balancer = "web" }
    }
    load_balancers = {
      web = {
        probes = { http = { protocol = "Http", port = 80, request_path = "/" } }
        rules  = { http = { probe = "http", frontend_port = 80, backend_port = 80 } }
      }
    }
  }
  assert {
    condition = (
      length(module.load_balancer) == 1 &&
      local.resource_names.load_balancers["web"].name == "M-AZU-LBL-IT-PPA-ECM-DEV-SWE-00" &&
      local.resource_names.load_balancers["web"].frontend_ip_configuration_name == "frontend" &&
      local.resource_names.load_balancers["web"].backend_address_pool_name == "backend" &&
      local.resource_names.load_balancers["web"].probes["http"] == "http" &&
      local.resource_names.load_balancers["web"].rules["http"] == "http" &&
      local.subnets["load_balancers"].name == "PPAECMDEVPRV08" &&
      local.subnets["load_balancers"].address_prefixes == ["10.42.9.0/26"] &&
      !can(local.subnets["load_balancers"].delegation) &&
      local.planned_subnet_address_prefixes["load_balancers"] == ["10.42.9.0/26"] &&
      !contains(local.nat_gateway_subnet_keys, "load_balancers") &&
      output.load_balancers["web"].virtual_machines == tolist(["primary"]) &&
      output.load_balancers["web"].virtual_machine_scale_sets == tolist(["app"])
    )
    error_message = "A load balancer must use the shared undelegated subnet outside the NAT Gateway, generated names, and the VMs and scale sets that reference its key."
  }
}

run "multiple_load_balancers_share_one_subnet" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/26" })
    virtual_machines = {
      primary = { load_balancer = "web" }
      db      = { load_balancer = "data" }
    }
    load_balancers = {
      web = {
        probes = {
          http = { protocol = "Http", port = 80, request_path = "/" }
          tcp  = { port = 443 }
        }
        rules = {
          http  = { probe = "http", frontend_port = 80, backend_port = 80 }
          https = { probe = "tcp", frontend_port = 443, backend_port = 443 }
        }
      }
      data = {
        sequence           = "01"
        private_ip_address = "10.42.9.20"
        zones              = []
        probes             = { sql = { port = 1433 } }
        rules              = { sql = { probe = "sql", frontend_port = 1433, backend_port = 1433 } }
      }
    }
  }
  assert {
    condition = (
      length(module.load_balancer) == 2 &&
      length(local.resource_names.load_balancers["web"].rules) == 2 &&
      length([for key in keys(local.subnets) : key if startswith(key, "load_balancers")]) == 1 &&
      output.load_balancers["web"].subnet_id == output.load_balancers["data"].subnet_id &&
      output.load_balancers["web"].virtual_machines == tolist(["primary"]) &&
      output.load_balancers["data"].virtual_machines == tolist(["db"]) &&
      length(output.load_balancers["data"].virtual_machine_scale_sets) == 0
    )
    error_message = "Load balancers must share the one load balancer subnet while keeping their own probes, rules, and members."
  }
}

run "no_load_balancer_subnet_without_load_balancers" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/26" })
  }
  assert {
    condition = (
      !contains(keys(local.subnets), "load_balancers") &&
      local.planned_subnet_address_prefixes["load_balancers"] == ["10.42.9.0/26"]
    )
    error_message = "The load balancer range must be reserved but not created until a load balancer exists."
  }
}

run "reject_load_balancers_without_range" {
  command = plan
  variables {
    load_balancers = {
      web = {}
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_unknown_load_balancer_on_vm" {
  command = plan
  variables {
    virtual_machines = {
      primary = { load_balancer = "missing" }
    }
  }
  expect_failures = [var.virtual_machines]
}

run "reject_unknown_load_balancer_on_vmss" {
  command = plan
  variables {
    virtual_machine_scale_sets = {
      app = { load_balancer = "missing" }
    }
  }
  expect_failures = [var.virtual_machine_scale_sets]
}

run "reject_load_balancer_subnet_smaller_than_29" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/30" })
  }
  expect_failures = [var.subnet_cidrs]
}

run "reject_reserved_load_balancer_ip" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      web = { private_ip_address = "10.42.9.3" }
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_broadcast_load_balancer_ip" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      web = { private_ip_address = "10.42.9.15" }
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_load_balancer_ip_outside_subnet" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      web = { private_ip_address = "10.42.10.4" }
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_duplicate_load_balancer_ips" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      web = { private_ip_address = "10.42.9.4" }
      api = { private_ip_address = "10.42.9.4" }
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_invalid_load_balancer_key" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      "web-" = {}
    }
  }
  expect_failures = [var.load_balancers]
}

run "reject_invalid_load_balancer_rule_key" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { load_balancers = "10.42.9.0/28" })
    load_balancers = {
      web = {
        probes = { http = { port = 80 } }
        rules  = { "Http_Rule" = { probe = "http", frontend_port = 80, backend_port = 80 } }
      }
    }
  }
  expect_failures = [var.load_balancers]
}

run "multiple_mysql_servers" {
  command = plan
  variables {
    mysql_servers = {
      primary = {}
      reports = {
        sequence          = "01"
        sku_name          = "GP_Standard_D2ds_v4"
        high_availability = { enabled = true }
      }
    }
  }
  assert {
    condition = (
      length(module.mysql) == 2 &&
      local.resource_names.mysql_servers["primary"].server_name == "m-azu-mys-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.mysql_servers["primary"].database_name == "primary" &&
      local.resource_names.mysql_servers["reports"].server_name == "m-azu-mys-it-ppa-ecm-dev-swe-01" &&
      local.subnet_enabled.mysql &&
      local.subnets["mysql"].delegation.service == "Microsoft.DBforMySQL/flexibleServers" &&
      length([for key in keys(local.subnets) : key if startswith(key, "mysql")]) == 1 &&
      contains(local.private_dns_zones, "privatelink.mysql.database.azure.com") &&
      output.mysql_servers["primary"].name == "m-azu-mys-it-ppa-ecm-dev-swe-00" &&
      output.mysql_servers["primary"].administrator_login == "mysqladminuser" &&
      !output.mysql_servers["primary"].high_availability_enabled &&
      output.mysql_servers["reports"].high_availability_enabled
    )
    error_message = "Each mysql_servers entry must create its own named server and database, while all servers share one delegated subnet and DNS zone."
  }
}

run "mysql_is_opt_in" {
  command = plan
  assert {
    condition = (
      length(module.mysql) == 0 &&
      !local.subnet_enabled.mysql &&
      !contains(local.private_dns_zones, "privatelink.mysql.database.azure.com") &&
      length(output.mysql_servers) == 0
    )
    error_message = "An empty mysql_servers map must create no server, password, subnet, or DNS zone."
  }
}

run "mysql_names_meet_azure_rules" {
  command = plan
  variables {
    mysql_servers = {
      longkeyname1 = { sequence = "99" }
      reports      = { sequence = "01", database_name = "sales_reporting" }
    }
  }
  assert {
    condition = (
      local.resource_names.mysql_servers["longkeyname1"].server_name == "m-azu-mys-it-ppa-ecm-dev-swe-99" &&
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", local.resource_names.mysql_servers["longkeyname1"].server_name)) &&
      local.resource_names.mysql_servers["longkeyname1"].database_name == "longkeyname1" &&
      local.resource_names.mysql_servers["reports"].database_name == "sales_reporting" &&
      output.mysql_servers["reports"].database_name == "sales_reporting"
    )
    error_message = "MySQL server names must be 3-63 lowercase characters; the database uses database_name, or the entry key when unset."
  }
}

run "reject_uppercase_mysql_database_name" {
  command = plan
  variables {
    mysql_servers = {
      primary = { database_name = "SalesDb" }
    }
  }
  expect_failures = [var.mysql_servers]
}

run "reject_mysql_system_database_name" {
  command = plan
  variables {
    mysql_servers = {
      primary = { database_name = "mysql" }
    }
  }
  expect_failures = [var.mysql_servers]
}

run "reject_invalid_mysql_server_key" {
  command = plan
  variables {
    mysql_servers = {
      "primary-" = {}
    }
  }
  expect_failures = [var.mysql_servers]
}

run "reject_mysql_subnet_too_small" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { mysql = "10.42.6.0/29" })
    mysql_servers = {
      one = { sku_name = "GP_Standard_D2ds_v4", high_availability = { enabled = true } }
      two = { sequence = "01", sku_name = "GP_Standard_D2ds_v4", high_availability = { enabled = true } }
    }
  }
  expect_failures = [var.mysql_servers]
}

run "mysql_subnet_exactly_full" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { mysql = "10.42.6.0/29" })
    mysql_servers = {
      one = { sku_name = "GP_Standard_D2ds_v4", high_availability = { enabled = true } }
      two = { sequence = "01" }
    }
  }
  assert {
    condition     = length(module.mysql) == 2
    error_message = "A /29 has three usable addresses, enough for one HA server (two) and one non-HA server (one)."
  }
}

run "multiple_postgresql_servers" {
  command = plan
  variables {
    postgresql_servers = {
      primary = {}
      reports = {
        sequence          = "01"
        sku_name          = "B_Standard_B1ms"
        storage_mb        = 65536
        high_availability = { enabled = false }
      }
      ha = {
        sequence          = "02"
        high_availability = { enabled = true }
      }
    }
  }
  assert {
    condition = (
      length(module.postgresql) == 3 &&
      local.resource_names.postgresql_servers["primary"].server_name == "m-azu-pgs-it-ppa-ecm-dev-swe-00" &&
      local.resource_names.postgresql_servers["primary"].database_name == "primary" &&
      local.resource_names.postgresql_servers["reports"].server_name == "m-azu-pgs-it-ppa-ecm-dev-swe-01" &&
      local.subnet_enabled.postgresql &&
      local.subnets["postgresql"].delegation.service == "Microsoft.DBforPostgreSQL/flexibleServers" &&
      contains(local.subnets["postgresql"].service_endpoints, "Microsoft.Storage") &&
      length([for key in keys(local.subnets) : key if startswith(key, "postgresql")]) == 1 &&
      contains(local.private_dns_zones, "privatelink.postgres.database.azure.com") &&
      output.postgresql_servers["primary"].name == "m-azu-pgs-it-ppa-ecm-dev-swe-00" &&
      output.postgresql_servers["primary"].administrator_login == "pgadminuser" &&
      !output.postgresql_servers["primary"].high_availability_enabled &&
      output.postgresql_servers["ha"].high_availability_enabled
    )
    error_message = "Each postgresql_servers entry must create its own named server and database, while all servers share one delegated subnet and DNS zone."
  }
}

run "postgresql_is_opt_in" {
  command = plan
  assert {
    condition = (
      length(module.postgresql) == 0 &&
      !local.subnet_enabled.postgresql &&
      !contains(local.private_dns_zones, "privatelink.postgres.database.azure.com") &&
      length(output.postgresql_servers) == 0
    )
    error_message = "An empty postgresql_servers map must create no server, password, subnet, or DNS zone."
  }
}

run "postgresql_names_meet_azure_rules" {
  command = plan
  variables {
    postgresql_servers = {
      longkeyname1 = { sequence = "99" }
      reports      = { sequence = "01", database_name = "Sales_Reporting" }
    }
  }
  assert {
    condition = (
      local.resource_names.postgresql_servers["longkeyname1"].server_name == "m-azu-pgs-it-ppa-ecm-dev-swe-99" &&
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", local.resource_names.postgresql_servers["longkeyname1"].server_name)) &&
      local.resource_names.postgresql_servers["longkeyname1"].database_name == "longkeyname1" &&
      local.resource_names.postgresql_servers["reports"].database_name == "Sales_Reporting" &&
      output.postgresql_servers["reports"].database_name == "Sales_Reporting"
    )
    error_message = "PostgreSQL server names must be 3-63 lowercase characters; the database uses database_name, or the entry key when unset."
  }
}

run "reject_postgresql_database_name_starting_with_digit" {
  command = plan
  variables {
    postgresql_servers = {
      primary = { database_name = "1sales" }
    }
  }
  expect_failures = [var.postgresql_servers]
}

run "reject_postgresql_system_database_name" {
  command = plan
  variables {
    postgresql_servers = {
      primary = { database_name = "postgres" }
    }
  }
  expect_failures = [var.postgresql_servers]
}

run "reject_duplicate_postgresql_server_sequence" {
  command = plan
  variables {
    postgresql_servers = {
      primary = {}
      reports = {}
    }
  }
  expect_failures = [var.postgresql_servers]
}

run "reject_duplicate_mysql_server_sequence" {
  command = plan
  variables {
    mysql_servers = {
      primary = {}
      reports = {}
    }
  }
  expect_failures = [var.mysql_servers]
}

run "reject_invalid_postgresql_server_key" {
  command = plan
  variables {
    postgresql_servers = {
      "Primary" = {}
    }
  }
  expect_failures = [var.postgresql_servers]
}

run "reject_postgresql_subnet_below_minimum" {
  command = plan
  variables {
    subnet_cidrs       = merge(var.subnet_cidrs, { postgresql = "10.42.5.0/29" })
    postgresql_servers = { primary = {} }
  }
  expect_failures = [var.postgresql_servers]
}

run "reject_postgresql_subnet_too_small" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { postgresql = "10.42.5.0/28" })
    postgresql_servers = {
      one   = { high_availability = { enabled = true } }
      two   = { sequence = "01", high_availability = { enabled = true } }
      three = { sequence = "02", high_availability = { enabled = true } }
    }
  }
  expect_failures = [var.postgresql_servers]
}

run "postgresql_subnet_exactly_full" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { postgresql = "10.42.5.0/28" })
    postgresql_servers = {
      one   = { high_availability = { enabled = true } }
      two   = { sequence = "01", high_availability = { enabled = true } }
      three = { sequence = "02" }
      four  = { sequence = "03" }
      five  = { sequence = "04" }
    }
  }
  assert {
    condition     = length(module.postgresql) == 5
    error_message = "A /28 has eleven usable addresses, enough for two HA servers (four each) and three non-HA servers (one each)."
  }
}

run "windows_function_app" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", os_type = "Windows", sku_name = "EP1" } }
    function_apps = {
      primary = {
        service_plan     = "functions"
        storage_sequence = "09"
        runtime          = { name = "dotnet-isolated", version = "8.0" }
      }
    }
  }
  assert {
    condition = (
      output.function_apps["primary"].os_type == "Windows" &&
      output.function_apps["primary"].hostname == "func-windows.azurewebsites.net" &&
      endswith(module.function_app["primary"].id, "/sites/func-windows") &&
      length(module.function_app_private_endpoint) == 1 &&
      output.virtual_machines["primary"].os_type == "Linux"
    )
    error_message = "The plan's os_type must select Windows Functions independently of VM OS and preserve the existing app ID/hostname and Private Endpoint wiring."
  }
}

run "windows_function_app_node" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", os_type = "Windows", sku_name = "EP1" } }
    function_apps = {
      primary = {
        service_plan     = "functions"
        storage_sequence = "09"
        runtime          = { name = "node", version = "22" }
      }
    }
  }
  assert {
    condition     = output.function_apps["primary"].os_type == "Windows" && output.function_apps["primary"].hostname == "func-windows.azurewebsites.net"
    error_message = "Windows Node must be selectable through a Windows plan."
  }
}

run "multiple_function_apps" {
  command = plan
  variables {
    app_service_plans = {
      functions = { sequence = "01", sku_name = "EP1" }
      jobs      = { sequence = "03", os_type = "Windows", sku_name = "EP2" }
    }
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09" }
      jobs = {
        service_plan     = "jobs"
        sequence         = "02"
        storage_sequence = "10"
        runtime          = { name = "node", version = "22" }
      }
    }
  }
  assert {
    condition = (
      length(module.app_service_plan) == 2 &&
      length(module.function_app) == 2 &&
      length(module.function_storage) == 2 &&
      length(module.function_app_private_endpoint) == 2 &&
      keys(module.function_storage_private_endpoints) == ["jobs", "primary"] &&
      output.function_apps["primary"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE" &&
      output.function_apps["jobs"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE-02" &&
      output.function_apps["primary"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-01" &&
      output.function_apps["jobs"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-03" &&
      local.resource_names.function_apps["jobs"].storage_account_name == "mazusoaitppaecmdevswe10" &&
      output.function_apps["jobs"].os_type == "Windows" &&
      output.function_apps["primary"].os_type == "Linux" &&
      keys(local.function_storage_private_endpoints["jobs"]) == [
        "function_storage/jobs/blob", "function_storage/jobs/file", "function_storage/jobs/queue", "function_storage/jobs/table"
      ] &&
      local.private_endpoint_names["function_storage/jobs/queue"].name == "mazusoaitppaecmdevswe10-queue" &&
      local.private_endpoint_names["function_app/jobs"].name == "M-AZU-FUN-IT-PPA-ECM-DEV-SWE-02-sites" &&
      keys(output.private_endpoint_ids.function_apps) == ["jobs", "primary"] &&
      keys(output.private_endpoint_ids.function_storage) == ["jobs", "primary"] &&
      length([for key in keys(local.subnets) : key if key == "function_integration"]) == 1
    )
    error_message = "Each function_apps entry must run on its selected plan with its own host storage and Private Endpoints, and every app must share the one integration subnet."
  }
}

run "function_apps_share_a_plan" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { function_integration = "10.42.4.0/28" })
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09" }
      jobs    = { service_plan = "functions", sequence = "02", storage_sequence = "10" }
    }
  }
  assert {
    condition = (
      length(module.app_service_plan) == 1 &&
      length(module.function_app) == 2 &&
      length(module.function_storage) == 2 &&
      output.function_apps["primary"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-01" &&
      output.function_apps["jobs"].service_plan_name == "M-AZU-ASP-IT-PPA-ECM-DEV-SWE-01" &&
      output.app_service_plans["functions"].function_apps == tolist(["jobs", "primary"])
    )
    error_message = "Several Function Apps must be able to share one Elastic Premium plan, each with its own host storage, and one plan must not require a /26 subnet."
  }
}

run "reject_two_function_apps_without_sequence" {
  command = plan
  variables {
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09" }
      jobs    = { service_plan = "functions", storage_sequence = "10" }
    }
  }
  expect_failures = [var.function_apps]
}

run "reject_duplicate_function_storage_sequence" {
  command = plan
  variables {
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09" }
      jobs    = { service_plan = "functions", sequence = "02", storage_sequence = "09" }
    }
  }
  expect_failures = [var.storage_accounts]
}

run "reject_function_app_on_basic_plan" {
  command = plan
  variables {
    app_service_plans = { functions = { sequence = "01", sku_name = "B1" } }
  }
  expect_failures = [var.function_apps]
}

run "reject_function_app_unknown_plan" {
  command = plan
  variables {
    function_apps = { primary = { service_plan = "missing", storage_sequence = "09" } }
  }
  expect_failures = [var.function_apps]
}

run "reject_invalid_function_app_key" {
  command = plan
  variables {
    function_apps = { "Bad_Key" = { service_plan = "functions", storage_sequence = "09" } }
  }
  expect_failures = [var.function_apps]
}

run "reject_function_apps_on_two_plans_below_26" {
  command = plan
  variables {
    subnet_cidrs = merge(var.subnet_cidrs, { function_integration = "10.42.4.0/27" })
    app_service_plans = {
      functions = { sequence = "01", sku_name = "EP1" }
      jobs      = { sequence = "03", sku_name = "EP1" }
    }
    function_apps = {
      primary = { service_plan = "functions", storage_sequence = "09" }
      jobs    = { service_plan = "jobs", sequence = "02", storage_sequence = "10" }
    }
  }
  expect_failures = [var.function_apps]
}

run "reject_web_and_function_plan_sequence_clash" {
  command = plan
  variables {
    app_service_plans = {
      functions = { sequence = "01", sku_name = "EP1" }
      web       = { sequence = "01" }
    }
    web_apps = { primary = { service_plan = "web" } }
  }
  expect_failures = [var.app_service_plans]
}
