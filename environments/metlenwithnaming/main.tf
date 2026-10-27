data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# Azure requires three of four character classes; the provider does not count
# "_" as a special character, so every class is guaranteed explicitly.
resource "random_password" "postgresql" {
  for_each = var.postgresql_servers

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-=+"
}

resource "random_password" "mysql" {
  for_each = var.mysql_servers

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-=+"
}

resource "tls_private_key" "vm" {
  for_each = {
    for key, vm in var.virtual_machines : key => vm
    if vm.os_type == "Linux"
  }

  algorithm = "ED25519"
}

resource "random_password" "vm_windows" {
  for_each = {
    for key, vm in var.virtual_machines : key => vm
    if vm.os_type == "Windows"
  }

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+"
}

resource "tls_private_key" "vmss" {
  for_each = {
    for key, scale_set in var.virtual_machine_scale_sets : key => scale_set
    if scale_set.os_type == "Linux"
  }

  algorithm = "ED25519"
}

resource "random_password" "vmss_windows" {
  for_each = {
    for key, scale_set in var.virtual_machine_scale_sets : key => scale_set
    if scale_set.os_type == "Windows"
  }

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+"
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
  admin_ssh_public_key   = each.value.os_type == "Linux" ? tls_private_key.vm[each.key].public_key_openssh : null
  admin_password         = each.value.os_type == "Windows" ? random_password.vm_windows[each.key].result : null
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
  admin_ssh_public_key          = each.value.os_type == "Linux" ? tls_private_key.vmss[each.key].public_key_openssh : null
  admin_password                = each.value.os_type == "Windows" ? random_password.vmss_windows[each.key].result : null
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
  count  = var.services.sql_managed_instance ? 1 : 0
  source = "../../modules/sql-managed-instance"

  name                        = local.resource_names.sql_managed_instance
  network_security_group_name = local.resource_names.sql_mi_nsg
  route_table_name            = local.resource_names.sql_mi_route_table
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  subnet_id                   = module.network.subnet_ids["sql_managed_instance"]
  sku_name                    = var.sql_managed_instance.sku_name
  vcores                      = var.sql_managed_instance.vcores
  storage_size_in_gb          = var.sql_managed_instance.storage_size_in_gb
  license_type                = var.sql_managed_instance.license_type
  azuread_administrator = {
    login_username = var.sql_managed_instance.azuread_administrator_login
    object_id      = data.azurerm_client_config.current.object_id
    principal_type = var.sql_managed_instance.azuread_administrator_type
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
  administrator_password = random_password.postgresql[each.key].result
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
  administrator_password = random_password.mysql[each.key].result
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

# One workspace shared by every Container Apps environment.
module "log_analytics" {
  count  = length(var.container_apps_environments) > 0 ? 1 : 0
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

module "web_app" {
  count  = var.services.web_app ? 1 : 0
  source = "../../modules/web-app"

  name                      = local.resource_names.web_app
  service_plan_name         = local.resource_names.web_app_service_plan
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  virtual_network_subnet_id = module.network.subnet_ids["web_app_integration"]
  mode                      = var.web_app.mode
  service_plan_sku_name     = var.web_app.service_plan_sku_name
  runtime                   = var.web_app.runtime
  container                 = var.web_app.container
  app_settings              = var.web_app.app_settings
  tags                      = local.common_tags
}

module "function_storage" {
  count  = var.services.function_app ? 1 : 0
  source = "../../modules/storage-account"

  name                      = local.resource_names.function_storage_account
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  shared_access_key_enabled = true
  file_share_names = {
    "function-content" = local.resource_names.function_content_share
  }
  file_shares = {
    "function-content" = {
      quota_gb = 1
    }
  }
  tags = local.common_tags
}

module "function_storage_private_endpoints" {
  count  = var.services.function_app ? 1 : 0
  source = "../../modules/storage-account-private-endpoints"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.network.subnet_ids["private_endpoints"]
  storage_account_id  = module.function_storage[0].id
  endpoints = {
    for key, endpoint in local.function_storage_private_endpoints : endpoint.subresource => {
      name                            = local.private_endpoint_names[key].name
      private_service_connection_name = local.private_endpoint_names[key].private_service_connection_name
      private_dns_zone_group_name     = local.private_endpoint_names[key].private_dns_zone_group_name
      private_dns_zone_ids            = [module.private_dns.zone_ids[endpoint.dns_zone]]
    }
  }
  tags = local.common_tags
}

module "function_app" {
  count  = var.services.function_app ? 1 : 0
  source = "../../modules/function-app"

  name                       = local.resource_names.function_app
  service_plan_name          = local.resource_names.app_service_plan
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  storage_account_name       = module.function_storage[0].name
  storage_account_access_key = module.function_storage[0].primary_access_key
  content_share_name         = local.resource_names.function_content_share
  virtual_network_subnet_id  = module.network.subnet_ids["function_integration"]
  service_plan_sku_name      = var.function_app.service_plan_sku_name
  os_type                    = var.function_app.os_type
  runtime                    = var.function_app.runtime
  tags                       = local.common_tags

  depends_on = [module.function_storage_private_endpoints]
}

module "function_app_private_endpoint" {
  count  = var.services.function_app ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.private_endpoint_names["function_app"].name
  private_service_connection_name = local.private_endpoint_names["function_app"].private_service_connection_name
  private_dns_zone_group_name     = local.private_endpoint_names["function_app"].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.function_app[0].id
  subresource_names               = [local.private_endpoint_catalog["function_app"].subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[local.private_endpoint_catalog["function_app"].dns_zone]]
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
