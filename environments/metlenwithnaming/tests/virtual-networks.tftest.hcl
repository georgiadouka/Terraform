# Locks in multi-VNet behaviour: names derived from the PUB/PRV intent,
# placement of resources (explicit and default), per-VNet subnets, NAT
# Gateways, NSG and route table classification, peerings between VNets and
# the cross-variable checks.

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
}

override_module {
  target = module.network
  outputs = {
    id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    name = "vnet-test"
    subnet_ids = {
      private_endpoints           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/pe"
      virtual_machines            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vm"
      web_app_integration         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web"
      load_balancers              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/lb"
      "container_apps/jobs"       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/aca"
      "databricks/lake/host"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/dbr-host"
      "databricks/lake/container" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/dbr-container"
    }
  }
}

# Every lab input is pinned here so results never depend on a local
# terraform.tfvars or *.auto.tfvars, which terraform test loads automatically.
variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  storage_use_azuread     = true
  location                = "swedencentral"
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
      subnet_cidrs = {
        private_endpoints    = "10.42.0.0/24"
        virtual_machines     = "10.42.1.0/24"
        web_app_integration  = "10.42.8.0/26"
        function_integration = "10.42.4.0/24"
        postgresql           = "10.42.5.0/24"
        mysql                = "10.42.6.0/24"
        sql_managed_instance = "10.42.7.0/27"
      }
    }
    edge = {
      classification = "PUB"
      address_space  = ["10.43.0.0/22"]
      subnet_cidrs = {
        private_endpoints   = "10.43.0.0/26"
        web_app_integration = "10.43.0.64/26"
        virtual_machines    = "10.43.1.0/24"
        load_balancers      = "10.43.2.0/28"
      }
    }
  }
  virtual_network_peerings    = {}
  virtual_machines            = {}
  virtual_machine_scale_sets  = {}
  load_balancers              = {}
  nat_gateways                = {}
  network_security_groups     = {}
  route_tables                = {}
  log_analytics_workspace     = {}
  application_insights        = { enabled = false }
  key_vaults                  = {}
  container_registries        = {}
  storage_accounts            = {}
  premium_file_accounts       = {}
  azure_sql_servers           = {}
  container_apps_environments = {}
  cosmos_db_accounts          = {}
  databricks_workspaces       = {}
  sql_managed_instances       = {}
  postgresql_servers          = {}
  mysql_servers               = {}
  app_service_plans           = {}
  function_apps               = {}
  web_apps                    = {}
  hub_peering                 = null
  tags                        = {}
}

run "two_vnets_names_and_placement" {
  command = plan

  variables {
    virtual_machines = {
      app = {}
      dmz = { virtual_network = "edge" }
    }
    virtual_machine_scale_sets = {
      web = { virtual_network = "edge" }
    }
    storage_accounts = {
      data = { virtual_network = "edge" }
    }
    nat_gateways = {
      main = { subnets = ["virtual_machines"] }
      edge = { subnets = ["virtual_machines"] }
    }
    network_security_groups = {
      app = { subnets = ["virtual_machines"] }
      dmz = { virtual_network = "edge", subnets = ["virtual_machines"] }
    }
    route_tables = {
      dmz = { virtual_network = "edge", subnets = ["virtual_machines"] }
    }
  }

  assert {
    condition = (
      local.resource_names.virtual_networks["main"].name == "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE" &&
      local.resource_names.virtual_networks["edge"].name == "M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE" &&
      output.virtual_networks["edge"].classification == "PUB"
    )
    error_message = "VNet names must carry the classification (network intent) of each VNet."
  }

  assert {
    condition = (
      local.default_virtual_network == "main" &&
      local.virtual_network_placement.virtual_machines == { app = "main", dmz = "edge" } &&
      local.virtual_network_placement.virtual_machine_scale_sets == { web = "edge" } &&
      local.virtual_network_placement.storage_accounts == { data = "edge" }
    )
    error_message = "Resources without virtual_network must land in the PRV VNet; the others in the VNet they name."
  }

  assert {
    condition = (
      local.subnets.main["virtual_machines"].name == "PPAECMDEVPRV02" &&
      local.subnets.main["virtual_machines"].address_prefixes == ["10.42.1.0/24"] &&
      local.subnets.edge["virtual_machines"].name == "PPAECMDEVPUB02" &&
      local.subnets.edge["virtual_machines"].address_prefixes == ["10.43.1.0/24"] &&
      local.subnet_enabled.edge.private_endpoints &&
      !local.subnet_enabled.main.private_endpoints &&
      local.private_endpoint_catalog["storage/data/blob"].virtual_network == "edge" &&
      !contains(keys(local.subnets.edge), "web_app_integration")
    )
    error_message = "Each VNet must get only the subnets its resources need, named with the VNet's classification and the role's fixed NN."
  }

  assert {
    condition = (
      length(module.nat_gateway) == 2 &&
      local.resource_names.nat_gateways["main"].name == "M-AZU-NGW-IT-PPA-ECM-PRV-DEV-SWE-00" &&
      local.resource_names.nat_gateways["main"].public_ip_name == "M-AZU-PIP-IT-PPA-ECM-PRV-DEV-SWE-00" &&
      local.resource_names.nat_gateways["edge"].name == "M-AZU-NGW-IT-PPA-ECM-PUB-DEV-SWE-00" &&
      local.resource_names.nat_gateways["edge"].public_ip_name == "M-AZU-PIP-IT-PPA-ECM-PUB-DEV-SWE-00" &&
      toset(local.nat_gateway_subnet_keys) == toset(["main/virtual_machines", "edge/virtual_machines"])
    )
    error_message = "Each VNet must get its own NAT Gateway and Public IP, named with the VNet's classification."
  }

  assert {
    condition = (
      local.resource_names.network_security_groups["app"] == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE" &&
      local.resource_names.network_security_groups["dmz"] == "M-AZU-NSG-IT-PPA-ECM-PUB-DEV-SWE" &&
      local.resource_names.route_tables["dmz"] == "M-AZU-UDR-IT-PPA-ECM-PUB-DEV-SWE" &&
      output.network_security_groups["dmz"].virtual_network == "edge"
    )
    error_message = "NSGs and route tables must default to the classification of their VNet."
  }

  assert {
    condition = local.resource_names.private_dns_links == {
      main = "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE"
      edge = "M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE"
    }
    error_message = "Every VNet must get a Private DNS zone link named after the VNet."
  }
}

run "peering_between_vnets" {
  command = plan

  variables {
    virtual_network_peerings = {
      main-edge = { virtual_networks = ["main", "edge"] }
    }
  }

  assert {
    condition = (
      length(module.virtual_network_peering) == 2 &&
      module.virtual_network_peering["main-to-edge"].name == "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE-to-M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE" &&
      module.virtual_network_peering["edge-to-main"].name == "M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE-to-M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE" &&
      length(module.spoke_to_hub_peering) == 0
    )
    error_message = "A virtual_network_peerings entry must create both sides, each named <local VNet name>-to-<remote VNet name>."
  }
}

run "single_pub_vnet_is_the_default" {
  command = plan

  variables {
    virtual_networks = {
      edge = {
        classification = "PUB"
        address_space  = ["10.43.0.0/22"]
        subnet_cidrs   = { virtual_machines = "10.43.1.0/24" }
      }
    }
    virtual_machines = { dmz = {} }
  }

  assert {
    condition = (
      local.default_virtual_network == "edge" &&
      local.subnets.edge["virtual_machines"].name == "PPAECMDEVPUB02"
    )
    error_message = "With a single VNet, resources without virtual_network must land in it, whatever its classification."
  }
}

# Subnet names are scoped to their VNet, so numbers only need to be unique
# within one VNet: the jobs environment can reuse 02 in the PUB VNet while
# the PRV VNet holds the VM subnet 02.
run "container_apps_and_databricks_follow_their_vnet" {
  command = plan

  variables {
    virtual_networks = {
      main = var.virtual_networks.main
      edge = {
        classification = "PUB"
        address_space  = ["10.43.0.0/22"]
        subnet_cidrs = {
          container_apps = { jobs = "10.43.1.0/27" }
          databricks     = { lake = { host = "10.43.2.0/26", container = "10.43.2.64/26" } }
        }
      }
    }
    virtual_machines            = { app = {} }
    container_apps_environments = { jobs = { subnet_number = 2 } }
    databricks_workspaces       = { lake = { network_access = "public" } }
    nat_gateways = {
      edge = { subnets = ["databricks/lake/host", "databricks/lake/container"] }
    }
  }

  assert {
    condition = (
      local.container_apps_environment_networks == { jobs = "edge" } &&
      local.databricks_workspace_networks == { lake = "edge" } &&
      local.subnets.edge["container_apps/jobs"].name == "PPAECMDEVPUB02" &&
      local.subnets.edge["container_apps/jobs"].address_prefixes == ["10.43.1.0/27"] &&
      local.subnets.edge["databricks/lake/host"].name == "PPAECMDEVPUB10" &&
      local.subnets.main["virtual_machines"].name == "PPAECMDEVPRV02" &&
      !contains(keys(local.subnets.main), "container_apps/jobs") &&
      local.resource_names.databricks_workspaces["lake"].network_security_group_name == "M-AZU-NSG-IT-PPA-ECM-PUB-DEV-SWE-00" &&
      output.container_apps_environments["jobs"].virtual_network == "edge"
    )
    error_message = "Container Apps environments and Databricks workspaces must be placed in the VNet whose subnet_cidrs lists their key and take its classification."
  }
}

run "reject_two_vnets_with_the_same_classification" {
  command = plan

  variables {
    virtual_networks = {
      main  = var.virtual_networks.main
      other = { address_space = ["10.44.0.0/22"] }
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_container_apps_key_in_two_vnets" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnet_cidrs = merge(var.virtual_networks.main.subnet_cidrs, { container_apps = { jobs = "10.42.2.0/27" } }) })
      edge = merge(var.virtual_networks.edge, { subnet_cidrs = merge(var.virtual_networks.edge.subnet_cidrs, { container_apps = { jobs = "10.43.3.0/27" } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_unknown_virtual_network" {
  command = plan

  variables {
    virtual_machines = { app = { virtual_network = "missing" } }
  }

  expect_failures = [var.virtual_machines]
}

run "reject_vnet_without_the_needed_subnet_range" {
  command = plan

  variables {
    postgresql_servers = { main = { virtual_network = "edge" } }
  }

  expect_failures = [var.postgresql_servers]
}

run "reject_load_balancer_in_another_vnet" {
  command = plan

  variables {
    load_balancers   = { web = { virtual_network = "edge" } }
    virtual_machines = { app = { load_balancer = "web" } }
  }

  expect_failures = [var.virtual_machines]
}

run "reject_apps_on_one_plan_in_two_vnets" {
  command = plan

  variables {
    app_service_plans = { web = {} }
    web_apps = {
      one = { service_plan = "web" }
      two = { service_plan = "web", sequence = "01", virtual_network = "edge" }
    }
  }

  expect_failures = [var.web_apps]
}

run "reject_nat_gateway_for_unknown_vnet" {
  command = plan

  variables {
    nat_gateways = { missing = { subnets = [] } }
  }

  expect_failures = [var.nat_gateways]
}

# The VM subnet exists in main only, so edge cannot list it.
run "reject_nat_gateway_subnet_of_another_vnet" {
  command = plan

  variables {
    virtual_machines = { app = {} }
    nat_gateways     = { edge = { subnets = ["virtual_machines"] } }
  }

  expect_failures = [var.nat_gateways]
}

run "reject_nsg_subnet_of_another_vnet" {
  command = plan

  variables {
    virtual_machines        = { app = {} }
    network_security_groups = { dmz = { virtual_network = "edge", subnets = ["virtual_machines"] } }
  }

  expect_failures = [var.network_security_groups]
}

run "reject_peering_a_vnet_with_itself" {
  command = plan

  variables {
    virtual_network_peerings = { loop = { virtual_networks = ["main", "main"] } }
  }

  expect_failures = [var.virtual_network_peerings]
}

run "reject_peering_overlapping_vnets" {
  command = plan

  variables {
    virtual_networks = {
      main = var.virtual_networks.main
      edge = { classification = "PUB", address_space = ["10.42.8.0/22"] }
    }
    virtual_network_peerings = { main-edge = { virtual_networks = ["main", "edge"] } }
  }

  expect_failures = [var.virtual_network_peerings]
}
