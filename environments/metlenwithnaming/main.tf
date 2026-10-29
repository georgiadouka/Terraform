data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = local.resource_names.resource_group
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "../../modules/network"

  name                            = local.resource_names.virtual_network
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  address_space                   = var.address_space
  subnets                         = local.subnets
  planned_subnet_address_prefixes = local.planned_subnet_address_prefixes
  tags                            = local.common_tags
}

# Hub side first, so allow_gateway_transit exists before the spoke side sets
# use_remote_gateways.
module "hub_to_spoke_peering" {
  count  = local.hub_to_spoke_peering_enabled ? 1 : 0
  source = "../../modules/virtual-network-peering"

  providers = {
    azurerm = azurerm.hub
  }

  name                      = local.resource_names.virtual_network_peerings.hub_to_spoke
  resource_group_name       = local.hub_virtual_network.resource_group_name
  virtual_network_name      = local.hub_virtual_network.name
  remote_virtual_network_id = module.network.id
  allow_forwarded_traffic   = var.hub_peering.allow_forwarded_traffic
  allow_gateway_transit     = var.hub_peering.use_remote_gateways
  # Re-syncs the hub side when the spoke address space changes.
  triggers = {
    remote_address_space = join(",", var.address_space)
  }
}

module "spoke_to_hub_peering" {
  count  = var.hub_peering == null ? 0 : 1
  source = "../../modules/virtual-network-peering"

  name                      = local.resource_names.virtual_network_peerings.spoke_to_hub
  resource_group_name       = module.resource_group.name
  virtual_network_name      = module.network.name
  remote_virtual_network_id = var.hub_peering.hub_virtual_network_id
  allow_forwarded_traffic   = var.hub_peering.allow_forwarded_traffic
  use_remote_gateways       = var.hub_peering.use_remote_gateways

  depends_on = [module.hub_to_spoke_peering]
}

module "private_dns" {
  source = "../../modules/private-dns"

  resource_group_name        = module.resource_group.name
  virtual_network_id         = module.network.id
  zone_names                 = local.private_dns_zones
  virtual_network_link_names = local.private_dns_link_names
  tags                       = local.common_tags
}

module "virtual_machine" {
  for_each = var.virtual_machines
  source   = "../../modules/virtual-machine"

  name                   = local.resource_names.virtual_machines[each.key].name
  network_interface_name = local.resource_names.virtual_machines[each.key].network_interface_name
  os_disk_name           = local.resource_names.virtual_machines[each.key].os_disk_name
  data_disk_names        = local.resource_names.virtual_machines[each.key].data_disk_names
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  subnet_id              = module.network.subnet_ids["virtual_machines"]
  size                   = each.value.size
  admin_username         = each.value.admin_username
  os_type                = each.value.os_type
  source_image_reference = each.value.source_image_reference
  computer_name          = local.resource_names.virtual_machines[each.key].computer_name
  admin_password         = var.vm_admin_password
  os_disk                = each.value.os_disk
  data_disks             = each.value.data_disks
  load_balancer_backend_address_pool_ids = each.value.load_balancer == null ? {} : {
    (each.value.load_balancer) = module.load_balancer[each.value.load_balancer].backend_address_pool_id
  }
  tags = local.common_tags

  depends_on = [module.nat_gateway]
}

module "virtual_machine_scale_set" {
  for_each = var.virtual_machine_scale_sets
  source   = "../../modules/virtual-machine-scale-set"

  name                          = local.resource_names.virtual_machine_scale_sets[each.key].name
  autoscale_setting_name        = local.resource_names.virtual_machine_scale_sets[each.key].autoscale_setting_name
  network_interface_name        = local.resource_names.virtual_machine_scale_sets[each.key].network_interface_name
  computer_name_prefix          = local.resource_names.virtual_machine_scale_sets[each.key].computer_name_prefix
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  subnet_id                     = module.network.subnet_ids["virtual_machines"]
  size                          = each.value.size
  admin_username                = each.value.admin_username
  os_type                       = each.value.os_type
  source_image_reference        = each.value.source_image_reference
  admin_password                = var.vm_admin_password
  os_disk                       = each.value.os_disk
  data_disks                    = each.value.data_disks
  scaling                       = each.value.scaling
  zones                         = each.value.zones
  upgrade_mode                  = each.value.upgrade_mode
  enable_accelerated_networking = each.value.enable_accelerated_networking
  load_balancer_backend_address_pool_ids = setunion(
    each.value.load_balancer_backend_address_pool_ids,
    each.value.load_balancer == null ? [] : [module.load_balancer[each.value.load_balancer].backend_address_pool_id]
  )
  application_gateway_backend_address_pool_ids = each.value.application_gateway_backend_address_pool_ids
  tags                                         = local.common_tags

  depends_on = [module.nat_gateway]
}

module "load_balancer" {
  for_each = var.load_balancers
  source   = "../../modules/load-balancer"

  name                           = local.resource_names.load_balancers[each.key].name
  frontend_ip_configuration_name = local.resource_names.load_balancers[each.key].frontend_ip_configuration_name
  backend_address_pool_name      = local.resource_names.load_balancers[each.key].backend_address_pool_name
  resource_group_name            = module.resource_group.name
  location                       = module.resource_group.location
  subnet_id                      = module.network.subnet_ids["load_balancers"]
  private_ip_address             = each.value.private_ip_address
  zones                          = each.value.zones
  probes = {
    for probe_key, probe in each.value.probes : probe_key => merge(
      probe,
      { name = local.resource_names.load_balancers[each.key].probes[probe_key] }
    )
  }
  rules = {
    for rule_key, rule in each.value.rules : rule_key => merge(
      rule,
      { name = local.resource_names.load_balancers[each.key].rules[rule_key] }
    )
  }
  tags = local.common_tags
}

module "nat_gateway" {
  count  = local.nat_gateway_required ? 1 : 0
  source = "../../modules/nat-gateway"

  name                = local.resource_names.nat_gateway
  public_ip_name      = local.resource_names.nat_public_ip
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_ids = {
    for subnet_key in local.nat_gateway_subnet_keys :
    subnet_key => module.network.subnet_ids[subnet_key]
  }
  idle_timeout_in_minutes = var.nat_gateway.idle_timeout_in_minutes
  tags                    = local.common_tags
}

# A 0.0.0.0/0 user-defined route takes precedence over the NAT Gateway
# (warning only).
check "nat_gateway_bypassed" {
  assert {
    condition     = length(setintersection(toset(local.nat_gateway_subnet_keys), toset(local.default_route_subnet_keys))) == 0
    error_message = "These nat_gateway.subnets entries also have a route table with a 0.0.0.0/0 route, which takes precedence, so the NAT Gateway is not used for them (but is still billed): ${join(", ", setintersection(toset(local.nat_gateway_subnet_keys), toset(local.default_route_subnet_keys)))}."
  }
}

module "network_security_group" {
  for_each = var.network_security_groups
  source   = "../../modules/network-security-group"

  name                = local.resource_names.network_security_groups[each.key]
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  security_rules      = each.value.security_rules
  subnet_ids = {
    for subnet_key in each.value.subnets :
    subnet_key => module.network.subnet_ids[subnet_key]
  }
  tags = local.common_tags
}

module "route_table" {
  for_each = var.route_tables
  source   = "../../modules/route-table"

  name                          = local.resource_names.route_tables[each.key]
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  bgp_route_propagation_enabled = each.value.bgp_route_propagation_enabled
  routes                        = each.value.routes
  subnet_ids = {
    for subnet_key in each.value.subnets :
    subnet_key => module.network.subnet_ids[subnet_key]
  }
  tags = local.common_tags
}

module "key_vault" {
  for_each = var.key_vaults
  source   = "../../modules/key-vault"

  name                     = local.resource_names.key_vaults[each.key]
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = each.value.sku_name
  purge_protection_enabled = each.value.purge_protection_enabled
  tags                     = local.common_tags
}

module "container_registry" {
  for_each = var.container_registries
  source   = "../../modules/container-registry"

  name                = local.resource_names.container_registries[each.key]
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.common_tags
}

module "storage" {
  for_each = var.storage_accounts
  source   = "../../modules/storage-account"

  name                        = local.resource_names.storage_accounts[each.key]
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  replication_type            = each.value.replication_type
  shared_access_key_enabled   = each.value.shared_access_key_enabled
  containers                  = local.resource_names.storage_containers[each.key]
  file_share_names            = local.resource_names.storage_file_shares[each.key]
  file_shares                 = each.value.file_shares
  data_plane_role_assignments = each.value.data_plane_role_assignments
  tags                        = local.common_tags
}

module "premium_files" {
  for_each = var.premium_file_accounts
  source   = "../../modules/premium-files"

  name                = local.resource_names.premium_file_accounts[each.key]
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  replication_type    = each.value.replication_type
  file_share_names    = local.resource_names.premium_file_shares[each.key]
  file_shares         = each.value.file_shares
  tags                = local.common_tags
}

module "azure_sql" {
  for_each = var.azure_sql_servers
  source   = "../../modules/azure-sql"

  server_name       = local.resource_names.azure_sql_servers[each.key].server_name
  database_name     = local.resource_names.azure_sql_servers[each.key].database_name
  database_sku_name = each.value.database_sku_name
  max_size_gb       = each.value.max_size_gb
  elastic_pool = merge(
    each.value.elastic_pool,
    { name = local.resource_names.azure_sql_servers[each.key].elastic_pool_name }
  )
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  azuread_administrator = {
    login_username = "Terraform SQL Admin"
    object_id      = data.azurerm_client_config.current.object_id
    tenant_id      = data.azurerm_client_config.current.tenant_id
  }
  tags = local.common_tags
}

module "sql_managed_instance" {
  for_each = var.sql_managed_instances
  source   = "../../modules/sql-managed-instance"

  name                        = local.resource_names.sql_managed_instances[each.key].name
  network_security_group_name = local.resource_names.sql_managed_instances[each.key].network_security_group_name
  route_table_name            = local.resource_names.sql_managed_instances[each.key].route_table_name
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  subnet_id                   = module.network.subnet_ids["sql_managed_instance"]
  sku_name                    = each.value.sku_name
  vcores                      = each.value.vcores
  storage_size_in_gb          = each.value.storage_size_in_gb
  license_type                = each.value.license_type
  azuread_administrator = {
    login_username = each.value.azuread_administrator_login
    object_id      = data.azurerm_client_config.current.object_id
    principal_type = each.value.azuread_administrator_type
    tenant_id      = data.azurerm_client_config.current.tenant_id
  }
  tags = local.common_tags
}

module "postgresql" {
  for_each = var.postgresql_servers
  source   = "../../modules/postgresql-flexible"

  name                   = local.resource_names.postgresql_servers[each.key].server_name
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  delegated_subnet_id    = module.network.subnet_ids["postgresql"]
  private_dns_zone_id    = module.private_dns.zone_ids["privatelink.postgres.database.azure.com"]
  administrator_password = var.database_admin_password
  database_name          = local.resource_names.postgresql_servers[each.key].database_name
  administrator_login    = each.value.administrator_login
  sku_name               = each.value.sku_name
  version_number         = each.value.version_number
  storage_mb             = each.value.storage_mb
  zone                   = each.value.zone
  high_availability      = each.value.high_availability
  tags                   = local.common_tags

  depends_on = [module.private_dns]
}

module "mysql" {
  for_each = var.mysql_servers
  source   = "../../modules/mysql-flexible"

  name                   = local.resource_names.mysql_servers[each.key].server_name
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  delegated_subnet_id    = module.network.subnet_ids["mysql"]
  private_dns_zone_id    = module.private_dns.zone_ids["privatelink.mysql.database.azure.com"]
  administrator_password = var.database_admin_password
  database_name          = local.resource_names.mysql_servers[each.key].database_name
  administrator_login    = each.value.administrator_login
  sku_name               = each.value.sku_name
  version_number         = each.value.version_number
  zone                   = each.value.zone
  high_availability      = each.value.high_availability
  tags                   = local.common_tags

  depends_on = [module.private_dns]
}

module "cosmos_db" {
  for_each = var.cosmos_db_accounts
  source   = "../../modules/cosmos-db"

  name                          = local.resource_names.cosmos_db_accounts[each.key]
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  api_type                      = each.value.api_type
  database_name                 = local.resource_names.cosmos_db_databases[each.key]
  container_name                = local.resource_names.cosmos_db_containers[each.key]
  throughput                    = each.value.throughput
  consistency_level             = each.value.consistency_level
  local_authentication_disabled = each.value.local_authentication_disabled
  nosql_partition_key_paths     = each.value.nosql_partition_key_paths
  mongodb                       = each.value.mongodb
  cassandra_schema              = each.value.cassandra_schema
  gremlin_partition_key_path    = each.value.gremlin_partition_key_path
  tags                          = local.common_tags
}

# One workspace shared by every Container Apps environment and by the
# Databricks diagnostic settings.
module "log_analytics" {
  count  = length(var.container_apps_environments) > 0 || length(local.databricks_diagnostics_keys) > 0 ? 1 : 0
  source = "../../modules/log-analytics-workspace"

  name                = local.resource_names.log_analytics_workspace
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.common_tags
}

module "container_apps" {
  for_each = var.container_apps_environments
  source   = "../../modules/container-apps"

  environment_name           = local.resource_names.container_apps_environments[each.key].name
  log_analytics_workspace_id = module.log_analytics[0].id
  private_dns_link_name      = local.resource_names.container_apps_environments[each.key].private_dns_link_name
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  infrastructure_subnet_id   = module.network.subnet_ids["container_apps/${each.key}"]
  virtual_network_id         = module.network.id
  dedicated_workload_profiles = {
    for profile_key, profile in each.value.dedicated_workload_profiles : profile_key => merge(
      profile,
      { name = local.resource_names.container_apps_environments[each.key].workload_profiles[profile_key] }
    )
  }
  apps = {
    for app_key, app in each.value.apps : app_key => merge(
      app,
      {
        name           = local.resource_names.container_apps_environments[each.key].apps[app_key]
        container_name = local.resource_names.container_app_container
      }
    )
  }
  tags = local.common_tags

  depends_on = [module.nat_gateway]
}

locals {
  databricks_diagnostics_keys = [
    for key, workspace in var.databricks_workspaces : key if workspace.diagnostics.enabled
  ]

  # Workspaces whose host or container subnet has neither the NAT Gateway nor
  # a 0.0.0.0/0 route: their clusters have no outbound internet access. The
  # browser authentication workspace runs no clusters.
  databricks_workspaces_without_egress = sort([
    for key, workspace in var.databricks_workspaces : key
    if !workspace.browser_authentication_workspace && anytrue([
      for role in ["host", "container"] :
      !contains(concat(local.nat_gateway_subnet_keys, local.default_route_subnet_keys), "databricks/${key}/${role}")
    ])
  ])

  databricks_private_workspace_keys = sort([
    for key, workspace in var.databricks_workspaces : key
    if workspace.network_access == "private" && !workspace.browser_authentication_workspace
  ])
}

# A warning rather than a validation error: the workspace deploys, but cluster
# creation fails without egress.
check "databricks_egress" {
  assert {
    condition     = length(local.databricks_workspaces_without_egress) == 0
    error_message = "These databricks_workspaces have a host or container subnet without outbound internet access, so clusters cannot start: ${join(", ", local.databricks_workspaces_without_egress)}. List both databricks/<key>/host and databricks/<key>/container in nat_gateway.subnets, or give them a route_tables entry with 0.0.0.0/0 to a firewall."
  }
}

# A warning: a hub may already provide the region's browser_authentication
# endpoint in a shared privatelink.azuredatabricks.net zone.
check "databricks_browser_authentication" {
  assert {
    condition     = length(local.databricks_private_workspace_keys) == 0 || length(local.databricks_browser_authentication_keys) > 0
    error_message = "These private databricks_workspaces have no browser_authentication endpoint in this configuration, so browser sign-in works only if a hub already provides one: ${join(", ", local.databricks_private_workspace_keys)}. Add a dedicated entry with browser_authentication_workspace = true."
  }
}

# The NSG association comes first (inside the module) and the NAT Gateway
# before the workspace, so clusters can reach the control plane as soon as
# the workspace exists.
module "databricks" {
  for_each = var.databricks_workspaces
  source   = "../../modules/databricks-workspace"

  name                        = local.resource_names.databricks_workspaces[each.key].name
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  sku                         = each.value.sku
  managed_resource_group_name = local.resource_names.databricks_workspaces[each.key].managed_resource_group_name
  root_storage_account_name   = local.resource_names.databricks_workspaces[each.key].root_storage_account_name
  virtual_network_id          = module.network.id
  host_subnet = {
    name = local.resource_names.databricks_workspaces[each.key].host_subnet_name
    id   = module.network.subnet_ids["databricks/${each.key}/host"]
  }
  container_subnet = {
    name = local.resource_names.databricks_workspaces[each.key].container_subnet_name
    id   = module.network.subnet_ids["databricks/${each.key}/container"]
  }
  network_security_group_name = local.resource_names.databricks_workspaces[each.key].network_security_group_name
  network_access              = each.value.network_access
  access_connector_name       = each.value.access_connector.enabled && !each.value.browser_authentication_workspace ? local.resource_names.databricks_workspaces[each.key].access_connector_name : null
  access_connector_storage_account_ids = {
    for account_key in each.value.access_connector.storage_accounts :
    account_key => module.storage[account_key].id
  }
  diagnostics = each.value.diagnostics.enabled ? {
    name                       = local.resource_names.log_analytics_workspace
    log_analytics_workspace_id = module.log_analytics[0].id
    categories                 = each.value.diagnostics.categories
  } : null
  tags = local.common_tags

  depends_on = [module.nat_gateway, module.route_table]
}

module "app_service_plan" {
  for_each = var.app_service_plans
  source   = "../../modules/app-service-plan"

  name                = local.resource_names.app_service_plans[each.key]
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  os_type             = each.value.os_type
  sku_name            = each.value.sku_name
  tags                = local.common_tags
}

# A warning rather than a validation error: an empty plan is valid, for
# example when it is created ahead of its apps, but it is still billed.
locals {
  unused_app_service_plans = sort([
    for key in keys(var.app_service_plans) : key
    if !contains(concat(
      [for app in values(var.web_apps) : app.service_plan],
      [for app in values(var.function_apps) : app.service_plan]
    ), key)
  ])
}

check "unused_app_service_plans" {
  assert {
    condition     = length(local.unused_app_service_plans) == 0
    error_message = "These app_service_plans entries have no web_apps or function_apps and are billed while empty: ${join(", ", local.unused_app_service_plans)}."
  }
}

module "web_app" {
  for_each = var.web_apps
  source   = "../../modules/web-app"

  name                      = local.resource_names.web_apps[each.key].name
  service_plan_id           = module.app_service_plan[each.value.service_plan].id
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  virtual_network_subnet_id = module.network.subnet_ids["web_app_integration"]
  mode                      = each.value.mode
  runtime                   = each.value.runtime
  container                 = each.value.container
  app_settings              = each.value.app_settings
  tags                      = local.common_tags
}

module "function_storage" {
  for_each = var.function_apps
  source   = "../../modules/storage-account"

  name                      = local.resource_names.function_apps[each.key].storage_account_name
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  shared_access_key_enabled = true
  file_share_names = {
    "function-content" = local.resource_names.function_apps[each.key].content_share_name
  }
  file_shares = {
    "function-content" = {
      quota_gb = 1
    }
  }
  tags = local.common_tags
}

module "function_storage_private_endpoints" {
  for_each = local.function_storage_private_endpoints
  source   = "../../modules/storage-account-private-endpoints"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.network.subnet_ids["private_endpoints"]
  storage_account_id  = module.function_storage[each.key].id
  endpoints = {
    for key, endpoint in each.value : endpoint.subresource => {
      name                            = local.private_endpoint_names[key].name
      private_service_connection_name = local.private_endpoint_names[key].private_service_connection_name
      private_dns_zone_group_name     = local.private_endpoint_names[key].private_dns_zone_group_name
      private_dns_zone_ids            = [module.private_dns.zone_ids[endpoint.dns_zone]]
    }
  }
  tags = local.common_tags
}

# Each app reaches its host storage only through the Private Endpoints, so the
# apps wait for them. depends_on applies to the whole call, so every app waits
# for every Function host storage endpoint.
module "function_app" {
  for_each = var.function_apps
  source   = "../../modules/function-app"

  name                       = local.resource_names.function_apps[each.key].name
  service_plan_id            = module.app_service_plan[each.value.service_plan].id
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  storage_account_name       = module.function_storage[each.key].name
  storage_account_access_key = module.function_storage[each.key].primary_access_key
  content_share_name         = local.resource_names.function_apps[each.key].content_share_name
  virtual_network_subnet_id  = module.network.subnet_ids["function_integration"]
  os_type                    = var.app_service_plans[each.value.service_plan].os_type
  runtime                    = each.value.runtime
  tags                       = local.common_tags

  depends_on = [module.function_storage_private_endpoints]
}

module "function_app_private_endpoint" {
  for_each = var.function_apps
  source   = "../../modules/private-endpoint"

  name                            = local.private_endpoint_names["function_app/${each.key}"].name
  private_service_connection_name = local.private_endpoint_names["function_app/${each.key}"].private_service_connection_name
  private_dns_zone_group_name     = local.private_endpoint_names["function_app/${each.key}"].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.function_app[each.key].id
  subresource_names               = [local.private_endpoint_catalog["function_app/${each.key}"].subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[local.private_endpoint_catalog["function_app/${each.key}"].dns_zone]]
  tags                            = local.common_tags
}

module "storage_private_endpoints" {
  for_each = local.storage_private_endpoints
  source   = "../../modules/storage-account-private-endpoints"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.network.subnet_ids["private_endpoints"]
  storage_account_id  = module.storage[each.key].id
  endpoints = {
    for key, endpoint in each.value : endpoint.subresource => {
      name                            = local.private_endpoint_names[key].name
      private_service_connection_name = local.private_endpoint_names[key].private_service_connection_name
      private_dns_zone_group_name     = local.private_endpoint_names[key].private_dns_zone_group_name
      private_dns_zone_ids            = [module.private_dns.zone_ids[endpoint.dns_zone]]
    }
  }
  tags = local.common_tags
}

module "private_endpoints" {
  for_each = local.service_private_endpoints
  source   = "../../modules/private-endpoint"

  name                            = local.private_endpoint_names[each.key].name
  private_service_connection_name = local.private_endpoint_names[each.key].private_service_connection_name
  private_dns_zone_group_name     = local.private_endpoint_names[each.key].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = local.private_endpoint_target_ids[each.value.target]
  subresource_names               = [each.value.subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[each.value.dns_zone]]
  tags                            = local.common_tags
}

module "databricks_browser_authentication_private_endpoint" {
  for_each = local.databricks_browser_authentication_private_endpoints
  source   = "../../modules/private-endpoint"

  name                            = local.private_endpoint_names[each.key].name
  private_service_connection_name = local.private_endpoint_names[each.key].private_service_connection_name
  private_dns_zone_group_name     = local.private_endpoint_names[each.key].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = local.private_endpoint_target_ids[each.value.target]
  subresource_names               = [each.value.subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[each.value.dns_zone]]
  tags                            = local.common_tags

  depends_on = [module.private_endpoints]
}

# Deleting the browser authentication workspace breaks browser sign-in to
# every private workspace in the region. The lock waits for the endpoint (a
# CanNotDelete lock also blocks deleting its connection), so terraform destroy
# removes the lock first.
resource "azurerm_management_lock" "databricks_browser_authentication" {
  for_each = toset([
    for key in local.databricks_browser_authentication_keys : key
    if var.databricks_workspaces[key].delete_lock
  ])

  name       = "do-not-delete-browser-authentication"
  scope      = module.databricks[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Hosts the browser_authentication Private Endpoint that browser sign-in to every private Azure Databricks workspace in the region uses."

  depends_on = [module.databricks_browser_authentication_private_endpoint]
}
