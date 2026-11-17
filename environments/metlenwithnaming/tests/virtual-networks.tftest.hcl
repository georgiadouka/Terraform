# Locks in multi-VNet behaviour: names derived from the PUB/PRV intent,
# placement of resources (explicit and default), explicit per-VNet subnets
# with their NSG, route table and NAT Gateway settings, NSG and route table
# classification, peerings between VNets and the cross-variable checks.

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
      subnets = {
        private_endpoints    = { cidr = "10.42.0.0/24", number = 1 }
        virtual_machines     = { cidr = "10.42.1.0/24", number = 2 }
        web_app_integration  = { cidr = "10.42.8.0/26", number = 3 }
        function_integration = { cidr = "10.42.4.0/24", number = 4 }
        postgresql           = { cidr = "10.42.5.0/24", number = 5 }
        mysql                = { cidr = "10.42.6.0/24", number = 6 }
        sql_managed_instance = { cidr = "10.42.7.0/27", number = 7 }
      }
    }
    edge = {
      classification = "PUB"
      address_space  = ["10.43.0.0/22"]
      subnets = {
        private_endpoints   = { cidr = "10.43.0.0/26", number = 1 }
        web_app_integration = { cidr = "10.43.0.64/26", number = 3 }
        virtual_machines    = { cidr = "10.43.1.0/24", number = 2 }
        load_balancers      = { cidr = "10.43.2.0/28", number = 8 }
      }
    }
  }
  virtual_network_peerings    = {}
  virtual_machines            = {}
  virtual_machine_scale_sets  = {}
  load_balancers              = {}
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
  logic_apps                  = {}
  web_apps                    = {}
  hub_peering                 = null
  tags                        = {}
}

run "two_vnets_names_and_placement" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          virtual_machines = { cidr = "10.42.1.0/24", number = 2, network_security_group = "app", nat_gateway = true }
        })
      })
      edge = merge(var.virtual_networks.edge, {
        nat_gateway = { sequence = "01" }
        subnets = merge(var.virtual_networks.edge.subnets, {
          virtual_machines = { cidr = "10.43.1.0/24", number = 2, network_security_group = "dmz", route_table = "dmz", nat_gateway = true }
        })
      })
    }
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
    network_security_groups = {
      app = {}
      dmz = {}
    }
    route_tables = {
      dmz = {}
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
      local.virtual_network_placement.storage_accounts == { data = "edge" } &&
      local.private_endpoint_catalog["storage/data/blob"].virtual_network == "edge"
    )
    error_message = "Resources without virtual_network must land in the PRV VNet; the others in the VNet they name."
  }

  assert {
    condition = (
      toset(keys(local.subnets.main)) == toset(keys(var.virtual_networks.main.subnets)) &&
      toset(keys(local.subnets.edge)) == toset(keys(var.virtual_networks.edge.subnets)) &&
      local.subnets.main["virtual_machines"].name == "PPAECMDEVPRV02" &&
      local.subnets.main["virtual_machines"].address_prefixes == ["10.42.1.0/24"] &&
      local.subnets.edge["virtual_machines"].name == "PPAECMDEVPUB02" &&
      local.subnets.edge["virtual_machines"].address_prefixes == ["10.43.1.0/24"]
    )
    error_message = "Every listed subnet must be created, used or not, named with its VNet's classification and its number."
  }

  assert {
    condition = (
      length(module.nat_gateway) == 2 &&
      local.resource_names.nat_gateways["main"].name == "M-AZU-NGW-IT-PPA-ECM-PRV-DEV-SWE-00" &&
      local.resource_names.nat_gateways["main"].public_ip_name == "M-AZU-PIP-IT-PPA-ECM-PRV-DEV-SWE-00" &&
      local.resource_names.nat_gateways["edge"].name == "M-AZU-NGW-IT-PPA-ECM-PUB-DEV-SWE-01" &&
      local.resource_names.nat_gateways["edge"].public_ip_name == "M-AZU-PIP-IT-PPA-ECM-PUB-DEV-SWE-01" &&
      toset(local.nat_gateway_subnet_keys) == toset(["main/virtual_machines", "edge/virtual_machines"]) &&
      output.nat_gateways["edge"].subnets == tolist(["virtual_machines"])
    )
    error_message = "Each VNet with a nat_gateway subnet must get its own NAT Gateway and Public IP, named with the VNet's classification and its nat_gateway sequence."
  }

  assert {
    condition = (
      local.resource_names.network_security_groups["app"] == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE" &&
      local.resource_names.network_security_groups["dmz"] == "M-AZU-NSG-IT-PPA-ECM-PUB-DEV-SWE" &&
      local.resource_names.route_tables["dmz"] == "M-AZU-UDR-IT-PPA-ECM-PUB-DEV-SWE" &&
      output.network_security_groups["dmz"].virtual_network == "edge" &&
      output.network_security_groups["dmz"].subnets == tolist(["virtual_machines"]) &&
      output.route_tables["dmz"].virtual_network == "edge" &&
      output.network_security_groups["app"].virtual_network == "main"
    )
    error_message = "NSGs and route tables must take the classification of the VNet whose subnets use them."
  }

  assert {
    condition = local.resource_names.private_dns_links == {
      main = "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE"
      edge = "M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE"
    }
    error_message = "Every VNet must get a Private DNS zone link named after the VNet."
  }
}

# Subnets are independent of workloads: with nothing deployed every listed
# subnet still exists, so removing a workload never removes its subnet.
run "subnets_exist_without_workloads" {
  command = plan

  variables {
    network_security_groups = { spare = { sequence = "01" } }
  }

  assert {
    condition = (
      length(local.subnets.main) == 7 &&
      length(local.subnets.edge) == 4 &&
      length(module.nat_gateway) == 0 &&
      output.network_security_groups["spare"].virtual_network == null &&
      length(output.network_security_groups["spare"].subnets) == 0 &&
      local.resource_names.network_security_groups["spare"] == "M-AZU-NSG-IT-PPA-ECM-PRV-DEV-SWE-01"
    )
    error_message = "Listed subnets must be created without workloads, no NAT Gateway without nat_gateway subnets, and an NSG no subnet uses must take the default VNet's classification."
  }
}

run "subnet_roles_set_delegations" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          "container_apps/jobs" = { cidr = "10.42.2.0/27", number = 9 }
        })
      })
    }
  }

  assert {
    condition = (
      local.subnets.main["private_endpoints"].private_endpoint_network_policies == "Disabled" &&
      local.subnets.main["private_endpoints"].delegation == null &&
      local.subnets.main["virtual_machines"].private_endpoint_network_policies == "Enabled" &&
      local.subnets.main["postgresql"].service_endpoints == tolist(["Microsoft.Storage"]) &&
      local.subnets.main["postgresql"].delegation.service == "Microsoft.DBforPostgreSQL/flexibleServers" &&
      local.subnets.main["postgresql"].delegation.name == "dlg-postgresql-metlen-lab-test1" &&
      local.subnets.main["web_app_integration"].delegation.name == "dlg-web-app-integration-metlen-lab-test1" &&
      local.subnets.main["sql_managed_instance"].delegation.service == "Microsoft.Sql/managedInstances" &&
      local.subnets.main["container_apps/jobs"].delegation.service == "Microsoft.App/environments" &&
      local.subnets.main["container_apps/jobs"].delegation.name == "dlg-container-apps-jobs-metlen-lab-test1" &&
      alltrue([for subnet in values(local.subnets.main) : subnet.default_outbound_access_enabled == false])
    )
    error_message = "The subnet key must select the delegation, endpoint policies and service endpoints, and every subnet must be private."
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
        subnets        = { virtual_machines = { cidr = "10.43.1.0/24", number = 2 } }
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
run "container_apps_and_databricks_follow_their_subnets" {
  command = plan

  variables {
    virtual_networks = {
      main = var.virtual_networks.main
      edge = {
        classification = "PUB"
        address_space  = ["10.43.0.0/22"]
        subnets = {
          "container_apps/jobs"       = { cidr = "10.43.1.0/27", number = 2 }
          "databricks/lake/host"      = { cidr = "10.43.2.0/26", number = 10, nat_gateway = true }
          "databricks/lake/container" = { cidr = "10.43.2.64/26", number = 11, nat_gateway = true }
        }
      }
    }
    virtual_machines            = { app = {} }
    container_apps_environments = { jobs = {} }
    databricks_workspaces       = { lake = { network_access = "public" } }
  }

  assert {
    condition = (
      local.container_apps_environment_networks == { jobs = "edge" } &&
      local.databricks_workspace_networks == { lake = "edge" } &&
      local.subnets.edge["container_apps/jobs"].name == "PPAECMDEVPUB02" &&
      local.subnets.edge["container_apps/jobs"].address_prefixes == ["10.43.1.0/27"] &&
      local.subnets.edge["databricks/lake/host"].name == "PPAECMDEVPUB10" &&
      local.subnets.edge["databricks/lake/container"].delegation.name == "dlg-databricks-lake-container-metlen-lab-test1" &&
      local.subnets.main["virtual_machines"].name == "PPAECMDEVPRV02" &&
      !contains(keys(local.subnets.main), "container_apps/jobs") &&
      local.resource_names.databricks_workspaces["lake"].network_security_group_name == "M-AZU-NSG-IT-PPA-ECM-PUB-DEV-SWE-00" &&
      output.container_apps_environments["jobs"].virtual_network == "edge"
    )
    error_message = "Container Apps environments and Databricks workspaces must be placed in the VNet that lists their subnets and take its classification."
  }
}

# A subnet left behind by a removed environment or workspace stays until it
# is removed from virtual_networks.
run "container_apps_subnet_without_environment" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          "container_apps/old" = { cidr = "10.42.2.0/27", number = 9 }
        })
      })
    }
  }

  assert {
    condition = (
      local.subnets.main["container_apps/old"].name == "PPAECMDEVPRV09" &&
      length(module.container_apps) == 0
    )
    error_message = "A container_apps/<key> subnet must be created even when no environment uses it."
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
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { "container_apps/jobs" = { cidr = "10.42.2.0/27", number = 9 } }) })
      edge = merge(var.virtual_networks.edge, { subnets = merge(var.virtual_networks.edge.subnets, { "container_apps/jobs" = { cidr = "10.43.3.0/27", number = 9 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_unknown_subnet_key" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { frontend = { cidr = "10.42.9.0/26", number = 9 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_duplicate_subnet_number_in_one_vnet" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { load_balancers = { cidr = "10.42.9.0/26", number = 2 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_subnet_number_above_99" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { load_balancers = { cidr = "10.42.9.0/26", number = 100 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_subnet_smaller_than_its_role_allows" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { sql_managed_instance = { cidr = "10.42.7.0/28", number = 7 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_subnet_smaller_than_29" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { load_balancers = { cidr = "10.42.9.0/30", number = 8 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_databricks_host_without_container" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { "databricks/lake/host" = { cidr = "10.42.10.0/26", number = 10 } }) })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_nsg_on_sql_managed_instance_subnet" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { sql_managed_instance = { cidr = "10.42.7.0/27", number = 7, network_security_group = "app" } }) })
    }
    network_security_groups = { app = {} }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_nsg_on_databricks_subnet" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, {
        subnets = merge(var.virtual_networks.main.subnets, {
          "databricks/lake/host"      = { cidr = "10.42.10.0/26", number = 10, network_security_group = "app" }
          "databricks/lake/container" = { cidr = "10.42.10.64/26", number = 11 }
        })
      })
    }
    network_security_groups = { app = {} }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_invalid_nat_gateway_sequence" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { nat_gateway = { sequence = "1" } })
    }
  }

  expect_failures = [var.virtual_networks]
}

run "reject_unknown_network_security_group" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { virtual_machines = { cidr = "10.42.1.0/24", number = 2, network_security_group = "missing" } }) })
    }
  }

  expect_failures = [var.network_security_groups]
}

run "reject_unknown_route_table" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { virtual_machines = { cidr = "10.42.1.0/24", number = 2, route_table = "missing" } }) })
    }
  }

  expect_failures = [var.route_tables]
}

run "reject_nsg_used_in_two_vnets" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { virtual_machines = { cidr = "10.42.1.0/24", number = 2, network_security_group = "shared" } }) })
      edge = merge(var.virtual_networks.edge, { subnets = merge(var.virtual_networks.edge.subnets, { virtual_machines = { cidr = "10.43.1.0/24", number = 2, network_security_group = "shared" } }) })
    }
    network_security_groups = { shared = {} }
  }

  expect_failures = [var.network_security_groups]
}

run "reject_route_table_used_in_two_vnets" {
  command = plan

  variables {
    virtual_networks = {
      main = merge(var.virtual_networks.main, { subnets = merge(var.virtual_networks.main.subnets, { virtual_machines = { cidr = "10.42.1.0/24", number = 2, route_table = "shared" } }) })
      edge = merge(var.virtual_networks.edge, { subnets = merge(var.virtual_networks.edge.subnets, { virtual_machines = { cidr = "10.43.1.0/24", number = 2, route_table = "shared" } }) })
    }
    route_tables = { shared = {} }
  }

  expect_failures = [var.route_tables]
}

run "reject_nsg_classification_of_another_vnet" {
  command = plan

  variables {
    virtual_networks = {
      edge = merge(var.virtual_networks.edge, { subnets = merge(var.virtual_networks.edge.subnets, { virtual_machines = { cidr = "10.43.1.0/24", number = 2, network_security_group = "dmz" } }) })
    }
    network_security_groups = { dmz = { classification = "PRV" } }
  }

  expect_failures = [var.network_security_groups]
}

run "reject_unknown_virtual_network" {
  command = plan

  variables {
    virtual_machines = { app = { virtual_network = "missing" } }
  }

  expect_failures = [var.virtual_machines]
}

run "reject_vnet_without_the_needed_subnet" {
  command = plan

  variables {
    postgresql_servers = { main = { virtual_network = "edge" } }
  }

  expect_failures = [var.postgresql_servers]
}

run "reject_container_apps_environment_without_subnet" {
  command = plan

  variables {
    container_apps_environments = { jobs = {} }
  }

  expect_failures = [var.container_apps_environments]
}

run "reject_databricks_workspace_without_subnets" {
  command = plan

  variables {
    databricks_workspaces = { lake = { network_access = "public" } }
  }

  expect_failures = [var.databricks_workspaces]
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
