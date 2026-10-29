locals {
  # Segments of /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>.
  hub_virtual_network_id_parts = var.hub_peering == null ? null : split("/", var.hub_peering.hub_virtual_network_id)
  hub_virtual_network = var.hub_peering == null ? null : {
    subscription_id     = local.hub_virtual_network_id_parts[2]
    resource_group_name = local.hub_virtual_network_id_parts[4]
    name                = local.hub_virtual_network_id_parts[8]
  }
  hub_to_spoke_peering_enabled = var.hub_peering == null ? false : var.hub_peering.create_hub_to_spoke_peering

  private_endpoints_required = anytrue([
    for endpoint in values(local.private_endpoint_catalog) : endpoint.enabled
  ])

  virtual_machine_subnet_required = length(var.virtual_machines) > 0 || length(var.virtual_machine_scale_sets) > 0

  # Subnets whose outbound traffic leaves through the NAT Gateway. Opt-in per
  # subnet; with none listed no NAT Gateway or Public IP is created. Every
  # subnet is private (no implicit default outbound access), so a subnet
  # without a NAT Gateway or a 0.0.0.0/0 route (for example to a hub firewall)
  # has no internet egress.
  nat_gateway_subnet_keys = var.nat_gateway.subnets
  nat_gateway_required    = length(local.nat_gateway_subnet_keys) > 0

  # Subnets with a 0.0.0.0/0 route, which takes precedence over the NAT Gateway.
  default_route_subnet_keys = flatten([
    for route_table in values(var.route_tables) : route_table.subnets
    if anytrue([for route in values(route_table.routes) : route.address_prefix == "0.0.0.0/0"])
  ])

  subnet_enabled = {
    private_endpoints    = local.private_endpoints_required
    virtual_machines     = local.virtual_machine_subnet_required
    web_app_integration  = length(var.web_apps) > 0
    function_integration = length(var.function_apps) > 0
    postgresql           = length(var.postgresql_servers) > 0
    mysql                = length(var.mysql_servers) > 0
    sql_managed_instance = length(var.sql_managed_instances) > 0
    load_balancers       = length(var.load_balancers) > 0
  }

  # Keys of every subnet the network module creates. Built without resource
  # names so the network_security_groups and route_tables validations can use
  # it without a dependency cycle.
  deployed_subnet_keys = concat(
    [for subnet_key, enabled in local.subnet_enabled : subnet_key if enabled],
    [for environment_key in keys(var.container_apps_environments) : "container_apps/${environment_key}"],
    keys(local.databricks_subnet_roles)
  )

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
    private_endpoints = {
      name                              = local.resource_names.subnets.private_endpoints
      address_prefixes                  = [var.subnet_cidrs.private_endpoints]
      private_endpoint_network_policies = "Disabled"
    }
    virtual_machines = {
      name             = local.resource_names.subnets.virtual_machines
      address_prefixes = [var.subnet_cidrs.virtual_machines]
    }
    web_app_integration = {
      name             = local.resource_names.subnets.web_app_integration
      address_prefixes = [var.subnet_cidrs.web_app_integration]
      delegation = {
        name    = local.resource_names.subnet_delegations.web_app_integration
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
    function_integration = {
      name             = local.resource_names.subnets.function_integration
      address_prefixes = [var.subnet_cidrs.function_integration]
      delegation = {
        name    = local.resource_names.subnet_delegations.function_integration
        service = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
    postgresql = {
      name              = local.resource_names.subnets.postgresql
      address_prefixes  = [var.subnet_cidrs.postgresql]
      service_endpoints = ["Microsoft.Storage"]
      delegation = {
        name    = local.resource_names.subnet_delegations.postgresql
        service = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    mysql = {
      name             = local.resource_names.subnets.mysql
      address_prefixes = [var.subnet_cidrs.mysql]
      delegation = {
        name    = local.resource_names.subnet_delegations.mysql
        service = "Microsoft.DBforMySQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    sql_managed_instance = {
      name             = local.resource_names.subnets.sql_managed_instance
      address_prefixes = [var.subnet_cidrs.sql_managed_instance]
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
    # Shared by every load balancer frontend IP; no delegation or NAT association.
    load_balancers = {
      name             = local.resource_names.subnets.load_balancers
      address_prefixes = [var.subnet_cidrs.load_balancers]
    }
  }

  # One dedicated subnet per Container Apps environment, keyed
  # container_apps/<environment key>, using the subnet_cidrs.container_apps
  # range with the same key.
  container_apps_subnets = {
    for environment_key in keys(var.container_apps_environments) :
    "container_apps/${environment_key}" => {
      name             = local.resource_names.container_apps_environments[environment_key].subnet_name
      address_prefixes = [var.subnet_cidrs.container_apps[environment_key]]
      delegation = {
        name    = local.resource_names.container_apps_environments[environment_key].subnet_delegation_name
        service = "Microsoft.App/environments"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }

  # Two dedicated subnets per Databricks workspace from the
  # subnet_cidrs.databricks entry with the same key. Azure Databricks needs
  # both delegated to it and attached to an NSG (the databricks-workspace
  # module creates the NSG).
  databricks_subnets = {
    for subnet_key, subnet in local.databricks_subnet_roles : subnet_key => {
      name             = local.resource_names.databricks_workspaces[subnet.workspace_key]["${subnet.role}_subnet_name"]
      address_prefixes = [var.subnet_cidrs.databricks[subnet.workspace_key][subnet.role]]
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

  subnets = {
    for subnet_key, subnet in merge(
      {
        for subnet_key, subnet in local.subnet_definitions :
        subnet_key => subnet
        if local.subnet_enabled[subnet_key]
      },
      local.container_apps_subnets,
      local.databricks_subnets
    ) :
    subnet_key => merge(subnet, { default_outbound_access_enabled = false })
  }

  # Every configured range, including unused ones, so the network module checks
  # the whole address plan for overlap and containment.
  planned_subnet_address_prefixes = merge(
    {
      for subnet_key, subnet in local.subnet_definitions :
      subnet_key => subnet.address_prefixes
      if subnet.address_prefixes[0] != null
    },
    {
      for environment_key, cidr in var.subnet_cidrs.container_apps :
      "container_apps/${environment_key}" => [cidr]
    },
    merge([
      for workspace_key, cidrs in var.subnet_cidrs.databricks : {
        "databricks/${workspace_key}/host"      = [cidrs.host]
        "databricks/${workspace_key}/container" = [cidrs.container]
      }
    ]...)
  )
}
