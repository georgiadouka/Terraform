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
  # Container Apps environments and Databricks workspaces are placed through
  # their subnets instead (below).
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
      logic_apps                 = var.logic_apps
      web_apps                   = var.web_apps
    } :
    type => {
      for key, resource in resources :
      key => coalesce(resource.virtual_network, local.default_virtual_network)
    }
  }

  # A Container Apps environment lives in the VNet that lists its
  # container_apps/<key> subnet, a Databricks workspace in the VNet that lists
  # its databricks/<key>/host subnet (null when none does; the variable
  # validations report it).
  container_apps_environment_networks = {
    for key in keys(var.container_apps_environments) :
    key => try(one([for network_key, network in var.virtual_networks : network_key if contains(keys(network.subnets), "container_apps/${key}")]), null)
  }
  databricks_workspace_networks = {
    for key in keys(var.databricks_workspaces) :
    key => try(one([for network_key, network in var.virtual_networks : network_key if contains(keys(network.subnets), "databricks/${key}/host")]), null)
  }

  # Every subnet listed in virtual_networks is created; nothing else is.
  # The subnet key sets its role: a fixed role (private_endpoints,
  # virtual_machines, ...), container_apps for container_apps/<environment key>,
  # or databricks_host and databricks_container for
  # databricks/<workspace key>/<host|container>. The role selects the
  # delegation and the minimum size.
  subnet_roles = {
    for network_key, network in var.virtual_networks : network_key => {
      for subnet_key in keys(network.subnets) : subnet_key => (
        startswith(subnet_key, "container_apps/") ? "container_apps" :
        startswith(subnet_key, "databricks/") ? "databricks_${element(split("/", subnet_key), 2)}" :
        subnet_key
      )
    }
  }

  # Largest prefix length (smallest subnet) each role accepts; /29 is the
  # Azure minimum. SQL Managed Instance needs /27, a Container Apps workload
  # profiles environment /27 (the /23 minimum applies only to
  # Consumption-only environments, which this lab doesn't create), and
  # Azure Databricks /28 (/26 or larger recommended: every cluster node takes
  # one address in each subnet).
  subnet_maximum_prefix_lengths = {
    sql_managed_instance = 27
    container_apps       = 27
    databricks_host      = 28
    databricks_container = 28
  }

  # Delegation of each subnet role that needs one; the name comes from
  # resource_names.subnet_delegations.
  subnet_delegation_services = {
    web_app_integration   = { service = "Microsoft.Web/serverFarms", actions = ["Microsoft.Network/virtualNetworks/subnets/action"] }
    function_integration  = { service = "Microsoft.Web/serverFarms", actions = ["Microsoft.Network/virtualNetworks/subnets/action"] }
    logic_app_integration = { service = "Microsoft.Web/serverFarms", actions = ["Microsoft.Network/virtualNetworks/subnets/action"] }
    postgresql            = { service = "Microsoft.DBforPostgreSQL/flexibleServers", actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"] }
    mysql                 = { service = "Microsoft.DBforMySQL/flexibleServers", actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"] }
    container_apps        = { service = "Microsoft.App/environments", actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"] }
    sql_managed_instance = {
      service = "Microsoft.Sql/managedInstances"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
    # Azure Databricks needs both workspace subnets delegated to it and
    # attached to an NSG (the databricks-workspace module creates the NSG).
    databricks_host = {
      service = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
    databricks_container = {
      service = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }

  # Subnets to create, per VNet, keyed by subnet key. Every subnet is private
  # (no implicit default outbound access), so a subnet without a NAT Gateway
  # or a 0.0.0.0/0 route (for example to a hub firewall) has no internet
  # egress. The PostgreSQL subnet keeps its Microsoft.Storage service endpoint.
  subnets = {
    for network_key, network in var.virtual_networks : network_key => {
      for subnet_key, subnet in network.subnets : subnet_key => {
        name                              = local.resource_names.virtual_networks[network_key].subnets[subnet_key]
        address_prefixes                  = [subnet.cidr]
        private_endpoint_network_policies = local.subnet_roles[network_key][subnet_key] == "private_endpoints" ? "Disabled" : "Enabled"
        service_endpoints                 = local.subnet_roles[network_key][subnet_key] == "postgresql" ? ["Microsoft.Storage"] : []
        default_outbound_access_enabled   = false
        delegation = (
          contains(keys(local.subnet_delegation_services), local.subnet_roles[network_key][subnet_key])
          ? merge(local.subnet_delegation_services[local.subnet_roles[network_key][subnet_key]], { name = local.resource_names.subnet_delegations[subnet_key] })
          : null
        )
      }
    }
  }

  # The NAT Gateway of a VNet serves the subnets that set nat_gateway = true;
  # a VNet without such subnets gets no NAT Gateway or Public IP. Azure
  # attaches a NAT Gateway to subnets of one VNet only.
  nat_gateways_required = {
    for network_key, network in var.virtual_networks : network_key => merge(network.nat_gateway, {
      subnets = sort([for subnet_key, subnet in network.subnets : subnet_key if subnet.nat_gateway])
    })
    if anytrue([for subnet in values(network.subnets) : subnet.nat_gateway])
  }
  # <VNet key>/<subnet key> of every subnet that uses its VNet's NAT Gateway.
  nat_gateway_subnet_keys = flatten([
    for network_key, nat_gateway in local.nat_gateways_required : [
      for subnet_key in nat_gateway.subnets : "${network_key}/${subnet_key}"
    ]
  ])

  # Subnets that use each NSG and route table, and the VNets they are in,
  # keyed by the NSG or route table key the subnets name. Built from
  # virtual_networks only, so the network_security_groups and route_tables
  # validations can use them without a dependency cycle; a key no subnet
  # names is absent. Validations allow one VNet per group or table, because
  # its name carries that VNet's PUB/PRV classification.
  network_security_group_subnets = {
    for key in distinct(compact(flatten([for network in values(var.virtual_networks) : [for subnet in values(network.subnets) : subnet.network_security_group]]))) :
    key => flatten([
      for network_key, network in var.virtual_networks : [
        for subnet_key, subnet in network.subnets : { virtual_network = network_key, subnet = subnet_key }
        if subnet.network_security_group == key
      ]
    ])
  }
  route_table_subnets = {
    for key in distinct(compact(flatten([for network in values(var.virtual_networks) : [for subnet in values(network.subnets) : subnet.route_table]]))) :
    key => flatten([
      for network_key, network in var.virtual_networks : [
        for subnet_key, subnet in network.subnets : { virtual_network = network_key, subnet = subnet_key }
        if subnet.route_table == key
      ]
    ])
  }
  network_security_group_networks = {
    for key, subnets in local.network_security_group_subnets : key => distinct([for subnet in subnets : subnet.virtual_network])
  }
  route_table_networks = {
    for key, subnets in local.route_table_subnets : key => distinct([for subnet in subnets : subnet.virtual_network])
  }

  # PUB or PRV in NSG and route table names: the classification set on the
  # entry, else that of the VNet whose subnets use it, else that of the
  # default VNet (for a group or table no subnet uses yet).
  network_security_group_classifications = {
    for key, nsg in var.network_security_groups : key => coalesce(
      nsg.classification,
      try(var.virtual_networks[one(local.network_security_group_networks[key])].classification, null),
      try(var.virtual_networks[local.default_virtual_network].classification, null),
      "PRV"
    )
  }
  route_table_classifications = {
    for key, route_table in var.route_tables : key => coalesce(
      route_table.classification,
      try(var.virtual_networks[one(local.route_table_networks[key])].classification, null),
      try(var.virtual_networks[local.default_virtual_network].classification, null),
      "PRV"
    )
  }

  # <VNet key>/<subnet key> of every subnet with a 0.0.0.0/0 route, which
  # takes precedence over the NAT Gateway.
  default_route_subnet_keys = flatten([
    for key, route_table in var.route_tables : [
      for subnet in lookup(local.route_table_subnets, key, []) : "${subnet.virtual_network}/${subnet.subnet}"
    ]
    if anytrue([for route in values(route_table.routes) : route.address_prefix == "0.0.0.0/0"])
  ])
}
