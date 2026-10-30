locals {
  # Segments of /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>.
  hub_virtual_network_id_parts = var.hub_peering == null ? null : split("/", var.hub_peering.hub_virtual_network_id)
  hub_virtual_network = var.hub_peering == null ? null : {
    subscription_id     = local.hub_virtual_network_id_parts[2]
    resource_group_name = local.hub_virtual_network_id_parts[4]
    name                = local.hub_virtual_network_id_parts[8]
  }
  hub_to_spoke_peering_enabled = var.hub_peering == null ? false : var.hub_peering.create_hub_to_spoke_peering

  # VNets peered with the hub: hub_peering.virtual_networks, or every VNet.
  hub_peering_virtual_networks = var.hub_peering == null ? [] : (
    var.hub_peering.virtual_networks == null ? sort(keys(var.virtual_networks)) : var.hub_peering.virtual_networks
  )

  # Both sides of every virtual_network_peerings entry, keyed
  # <local VNet key>-to-<remote VNet key>.
  virtual_network_peering_sides = merge([
    for peering in values(var.virtual_network_peerings) : {
      for index, network_key in peering.virtual_networks :
      "${network_key}-to-${peering.virtual_networks[1 - index]}" => {
        virtual_network         = network_key
        remote_virtual_network  = peering.virtual_networks[1 - index]
        allow_forwarded_traffic = peering.allow_forwarded_traffic
      }
    }
  ]...)

  # First and last address of every address_space prefix as integers, for
  # the virtual_network_peerings overlap check.
  virtual_network_address_ranges = {
    for key, network in var.virtual_networks : key => try([
      for prefix in network.address_space : {
        start = sum([for index, octet in split(".", cidrhost(prefix, 0)) : tonumber(octet) * pow(256, 3 - index)])
        end = (
          sum([for index, octet in split(".", cidrhost(prefix, 0)) : tonumber(octet) * pow(256, 3 - index)]) +
          pow(2, 32 - tonumber(split("/", prefix)[1])) - 1
        )
      }
    ], [])
  }

  # The VNet of every resource that does not set virtual_network: the PRV
  # VNet, or the only VNet when there is just one (PUB).
  default_virtual_network = try(
    length(var.virtual_networks) == 1 ? one(keys(var.virtual_networks)) : one([for key, network in var.virtual_networks : key if network.classification == "PRV"]),
    null
  )

  # VNet of every networked resource, keyed by input variable and entry key.
  # Container Apps environments and Databricks workspaces live in the VNet
  # whose subnet_cidrs lists their key; NSGs and route tables are kept apart
  # because their validations read the subnet locals below.
  virtual_network_placement = {
    for type, resources in {
      virtual_machines           = var.virtual_machines
      virtual_machine_scale_sets = var.virtual_machine_scale_sets
      load_balancers             = var.load_balancers
      key_vaults                 = var.key_vaults
      container_registries       = var.container_registries
      storage_accounts           = var.storage_accounts
      premium_file_accounts      = var.premium_file_accounts
      azure_sql_servers          = var.azure_sql_servers
      cosmos_db_accounts         = var.cosmos_db_accounts
      sql_managed_instances      = var.sql_managed_instances
      postgresql_servers         = var.postgresql_servers
      mysql_servers              = var.mysql_servers
      function_apps              = var.function_apps
      web_apps                   = var.web_apps
    } :
    type => {
      for key, resource in resources :
      key => coalesce(resource.virtual_network, local.default_virtual_network)
    }
  }
  container_apps_environment_networks = {
    for key in keys(var.container_apps_environments) :
    key => try(one([for network_key, network in var.virtual_networks : network_key if contains(keys(network.subnet_cidrs.container_apps), key)]), null)
  }
  databricks_workspace_networks = {
    for key in keys(var.databricks_workspaces) :
    key => try(one([for network_key, network in var.virtual_networks : network_key if contains(keys(network.subnet_cidrs.databricks), key)]), null)
  }
  network_security_group_networks = {
    for key, nsg in var.network_security_groups :
    key => coalesce(nsg.virtual_network, local.default_virtual_network)
  }
  route_table_networks = {
    for key, route_table in var.route_tables :
    key => coalesce(route_table.virtual_network, local.default_virtual_network)
  }

  # <VNet key>/<subnet key> of every subnet whose outbound traffic leaves
  # through its VNet's NAT Gateway. Opt-in per subnet; a VNet without listed
  # subnets gets no NAT Gateway or Public IP. Every subnet is private (no
  # implicit default outbound access), so a subnet without a NAT Gateway or a
  # 0.0.0.0/0 route (for example to a hub firewall) has no internet egress.
  nat_gateway_subnet_keys = flatten([
    for network_key, nat_gateway in var.nat_gateways : [
      for subnet_key in nat_gateway.subnets : "${network_key}/${subnet_key}"
    ]
  ])
  nat_gateways_required = {
    for key, nat_gateway in var.nat_gateways : key => nat_gateway
    if length(nat_gateway.subnets) > 0
  }

  # <VNet key>/<subnet key> of every subnet with a 0.0.0.0/0 route, which
  # takes precedence over the NAT Gateway.
  default_route_subnet_keys = flatten([
    for key, route_table in var.route_tables : [
      for subnet_key in route_table.subnets : "${local.route_table_networks[key]}/${subnet_key}"
    ]
    if anytrue([for route in values(route_table.routes) : route.address_prefix == "0.0.0.0/0"])
  ])

  # Fixed subnet roles needed in each VNet.
  subnet_enabled = {
    for network_key in keys(var.virtual_networks) : network_key => {
      private_endpoints = anytrue([
        for endpoint in values(local.private_endpoint_catalog) : endpoint.enabled && endpoint.virtual_network == network_key
      ])
      virtual_machines = contains(concat(
        values(local.virtual_network_placement.virtual_machines),
        values(local.virtual_network_placement.virtual_machine_scale_sets)
      ), network_key)
      web_app_integration  = contains(values(local.virtual_network_placement.web_apps), network_key)
      function_integration = contains(values(local.virtual_network_placement.function_apps), network_key)
      postgresql           = contains(values(local.virtual_network_placement.postgresql_servers), network_key)
      mysql                = contains(values(local.virtual_network_placement.mysql_servers), network_key)
      sql_managed_instance = contains(values(local.virtual_network_placement.sql_managed_instances), network_key)
      load_balancers       = contains(values(local.virtual_network_placement.load_balancers), network_key)
    }
  }

  # Keys of every subnet the network module creates, per VNet. Built without
  # resource names so the nat_gateways, network_security_groups and
  # route_tables validations can use it without a dependency cycle.
  deployed_subnet_keys = {
    for network_key in keys(var.virtual_networks) : network_key => concat(
      [for subnet_key, enabled in local.subnet_enabled[network_key] : subnet_key if enabled],
      [for key, environment_network in local.container_apps_environment_networks : "container_apps/${key}" if environment_network == network_key],
      [for subnet_key, subnet in local.databricks_subnet_roles : subnet_key if local.databricks_workspace_networks[subnet.workspace_key] == network_key]
    )
  }

  # Host and container subnet of every Databricks workspace, keyed
  # databricks/<workspace key>/<host|container>. Built from variables only
  # (no resource names) for the same reason as deployed_subnet_keys.
  databricks_subnet_roles = merge([
    for workspace_key in keys(var.databricks_workspaces) : {
      for role in ["host", "container"] :
      "databricks/${workspace_key}/${role}" => {
        workspace_key = workspace_key
        role          = role
      }
    }
  ]...)

  subnet_definitions = {
    for network_key, network in var.virtual_networks : network_key => {
      private_endpoints = {
        name                              = local.resource_names.virtual_networks[network_key].subnets.private_endpoints
        address_prefixes                  = [network.subnet_cidrs.private_endpoints]
        private_endpoint_network_policies = "Disabled"
      }
      virtual_machines = {
        name             = local.resource_names.virtual_networks[network_key].subnets.virtual_machines
        address_prefixes = [network.subnet_cidrs.virtual_machines]
      }
      web_app_integration = {
        name             = local.resource_names.virtual_networks[network_key].subnets.web_app_integration
        address_prefixes = [network.subnet_cidrs.web_app_integration]
        delegation = {
          name    = local.resource_names.subnet_delegations.web_app_integration
          service = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
      function_integration = {
        name             = local.resource_names.virtual_networks[network_key].subnets.function_integration
        address_prefixes = [network.subnet_cidrs.function_integration]
        delegation = {
          name    = local.resource_names.subnet_delegations.function_integration
          service = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
      postgresql = {
        name              = local.resource_names.virtual_networks[network_key].subnets.postgresql
        address_prefixes  = [network.subnet_cidrs.postgresql]
        service_endpoints = ["Microsoft.Storage"]
        delegation = {
          name    = local.resource_names.subnet_delegations.postgresql
          service = "Microsoft.DBforPostgreSQL/flexibleServers"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
      mysql = {
        name             = local.resource_names.virtual_networks[network_key].subnets.mysql
        address_prefixes = [network.subnet_cidrs.mysql]
        delegation = {
          name    = local.resource_names.subnet_delegations.mysql
          service = "Microsoft.DBforMySQL/flexibleServers"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
      sql_managed_instance = {
        name             = local.resource_names.virtual_networks[network_key].subnets.sql_managed_instance
        address_prefixes = [network.subnet_cidrs.sql_managed_instance]
        delegation = {
          name    = local.resource_names.subnet_delegations.sql_managed_instance
          service = "Microsoft.Sql/managedInstances"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action",
            "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
            "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
          ]
        }
      }
      # Shared by every load balancer frontend IP in the VNet; no delegation
      # or NAT association.
      load_balancers = {
        name             = local.resource_names.virtual_networks[network_key].subnets.load_balancers
        address_prefixes = [network.subnet_cidrs.load_balancers]
      }
    }
  }

  # One dedicated subnet per Container Apps environment, keyed
  # container_apps/<environment key>, using the subnet_cidrs.container_apps
  # range with the same key in the environment's VNet.
  container_apps_subnets = {
    for environment_key, network_key in local.container_apps_environment_networks :
    "container_apps/${environment_key}" => {
      name             = local.resource_names.container_apps_environments[environment_key].subnet_name
      address_prefixes = [var.virtual_networks[network_key].subnet_cidrs.container_apps[environment_key]]
      delegation = {
        name    = local.resource_names.container_apps_environments[environment_key].subnet_delegation_name
        service = "Microsoft.App/environments"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }

  # Two dedicated subnets per Databricks workspace from the
  # subnet_cidrs.databricks entry with the same key in the workspace's VNet.
  # Azure Databricks needs both delegated to it and attached to an NSG (the
  # databricks-workspace module creates the NSG).
  databricks_subnets = {
    for subnet_key, subnet in local.databricks_subnet_roles : subnet_key => {
      name             = local.resource_names.databricks_workspaces[subnet.workspace_key]["${subnet.role}_subnet_name"]
      address_prefixes = [var.virtual_networks[local.databricks_workspace_networks[subnet.workspace_key]].subnet_cidrs.databricks[subnet.workspace_key][subnet.role]]
      delegation = {
        name    = local.resource_names.databricks_workspaces[subnet.workspace_key]["${subnet.role}_subnet_delegation_name"]
        service = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
        ]
      }
    }
  }

  # Subnets to create, per VNet, keyed by subnet key.
  subnets = {
    for network_key in keys(var.virtual_networks) : network_key => {
      for subnet_key, subnet in merge(
        {
          for subnet_key, subnet in local.subnet_definitions[network_key] :
          subnet_key => subnet
          if local.subnet_enabled[network_key][subnet_key]
        },
        {
          for environment_key, environment_network in local.container_apps_environment_networks :
          "container_apps/${environment_key}" => local.container_apps_subnets["container_apps/${environment_key}"]
          if environment_network == network_key
        },
        {
          for subnet_key, subnet in local.databricks_subnet_roles :
          subnet_key => local.databricks_subnets[subnet_key]
          if local.databricks_workspace_networks[subnet.workspace_key] == network_key
        }
      ) :
      subnet_key => merge(subnet, { default_outbound_access_enabled = false })
    }
  }

  # Every configured range of each VNet, including unused ones, so the network
  # module checks the whole address plan for overlap and containment.
  planned_subnet_address_prefixes = {
    for network_key, network in var.virtual_networks : network_key => merge(
      {
        for subnet_key in keys(local.subnet_numbers) :
        subnet_key => [network.subnet_cidrs[subnet_key]]
        if network.subnet_cidrs[subnet_key] != null
      },
      {
        for environment_key, cidr in network.subnet_cidrs.container_apps :
        "container_apps/${environment_key}" => [cidr]
      },
      merge([
        for workspace_key, cidrs in network.subnet_cidrs.databricks : {
          "databricks/${workspace_key}/host"      = [cidrs.host]
          "databricks/${workspace_key}/container" = [cidrs.container]
        }
      ]...)
    )
  }
}