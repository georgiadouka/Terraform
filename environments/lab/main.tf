data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "random_password" "postgresql" {
  count = var.services.postgresql ? 1 : 0

  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "random_password" "mysql" {
  count = var.services.mysql ? 1 : 0

  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "tls_private_key" "vm" {
  count = var.services.virtual_machine && var.virtual_machine.os_type == "Linux" ? 1 : 0

  algorithm = "ED25519"
}

resource "random_password" "vm_windows" {
  count = var.services.virtual_machine && var.virtual_machine.os_type == "Windows" ? 1 : 0

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+"
}

resource "tls_private_key" "vmss" {
  count = var.services.virtual_machine_scale_set && var.virtual_machine_scale_set.os_type == "Linux" ? 1 : 0

  algorithm = "ED25519"
}

resource "random_password" "vmss_windows" {
  count = var.services.virtual_machine_scale_set && var.virtual_machine_scale_set.os_type == "Windows" ? 1 : 0

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+"
}

locals {
  naming_suffix       = coalesce(var.naming.unique_suffix, random_string.suffix.result)
  name_stem           = "${var.project_name}-${var.environment}-${local.naming_suffix}"
  compact_project     = replace(var.project_name, "-", "")
  compact_environment = replace(var.environment, "-", "")
  naming_prefixes     = var.naming.prefixes

  resource_names = {
    resource_group  = "${local.naming_prefixes.resource_group}-${local.name_stem}"
    virtual_network = "${local.naming_prefixes.virtual_network}-${local.name_stem}"

    subnets = {
      private_endpoints    = "${local.naming_prefixes.subnet}-pe-${local.name_stem}"
      virtual_machines     = "${local.naming_prefixes.subnet}-vm-${local.name_stem}"
      container_apps       = "${local.naming_prefixes.subnet}-aca-${local.name_stem}"
      web_app_integration  = "${local.naming_prefixes.subnet}-app-${local.name_stem}"
      function_integration = "${local.naming_prefixes.subnet}-func-${local.name_stem}"
      postgresql           = "${local.naming_prefixes.subnet}-psql-${local.name_stem}"
      mysql                = "${local.naming_prefixes.subnet}-mysql-${local.name_stem}"
      sql_managed_instance = "${local.naming_prefixes.subnet}-sqlmi-${local.name_stem}"
    }

    subnet_delegations = {
      container_apps       = "${local.naming_prefixes.subnet_delegation}-container-apps-${local.name_stem}"
      web_app_integration  = "${local.naming_prefixes.subnet_delegation}-web-app-integration-${local.name_stem}"
      function_integration = "${local.naming_prefixes.subnet_delegation}-function-integration-${local.name_stem}"
      postgresql           = "${local.naming_prefixes.subnet_delegation}-postgresql-${local.name_stem}"
      mysql                = "${local.naming_prefixes.subnet_delegation}-mysql-${local.name_stem}"
      sql_managed_instance = "${local.naming_prefixes.subnet_delegation}-sql-managed-instance-${local.name_stem}"
    }

    virtual_machine           = "${local.naming_prefixes.virtual_machine}-${local.name_stem}"
    virtual_machine_scale_set = "${local.naming_prefixes.virtual_machine_scale_set}-${local.name_stem}"
    network_interface         = "${local.naming_prefixes.network_interface}-${local.name_stem}"
    vmss_network_interface    = "${local.naming_prefixes.network_interface}-vmss-${local.name_stem}"
    vmss_autoscale_setting    = "${local.naming_prefixes.autoscale_setting}-${local.name_stem}"
    os_disk                   = "${local.naming_prefixes.os_disk}-${local.name_stem}"
    nat_gateway               = "${local.naming_prefixes.nat_gateway}-${local.name_stem}"
    nat_public_ip             = "${local.naming_prefixes.public_ip}-nat-${local.name_stem}"
    data_disks = {
      for label in keys(var.virtual_machine.data_disks) :
      label => "${local.naming_prefixes.data_disk}-${label}-${local.name_stem}"
    }

    key_vault = format(
      "%s-%s",
      substr("${local.naming_prefixes.key_vault}-${local.compact_project}${local.compact_environment}", 0, 23 - length(local.naming_suffix)),
      local.naming_suffix
    )

    container_registry = "${local.naming_prefixes.container_registry}${local.compact_project}${local.compact_environment}${local.naming_suffix}"

    storage_account = format(
      "%s%s",
      substr("${local.naming_prefixes.storage_account}${local.compact_project}${local.compact_environment}", 0, 24 - length(local.naming_suffix)),
      local.naming_suffix
    )
    premium_files_account = format(
      "%s%s",
      substr("${local.naming_prefixes.premium_files_account}${local.compact_project}${local.compact_environment}", 0, 24 - length(local.naming_suffix)),
      local.naming_suffix
    )
    function_storage_account = format(
      "%s%s",
      substr("${local.naming_prefixes.function_storage_account}${local.compact_project}${local.compact_environment}", 0, 24 - length(local.naming_suffix)),
      local.naming_suffix
    )

    storage_containers = {
      for label in var.storage.containers :
      label => "${local.naming_prefixes.storage_container}-${label}-${local.name_stem}"
    }
    storage_file_shares = {
      for label in keys(var.storage.file_shares) :
      label => "${local.naming_prefixes.file_share}-${label}-${local.name_stem}"
    }
    premium_file_shares = {
      for label in keys(var.premium_files.file_shares) :
      label => "${local.naming_prefixes.file_share}-${label}-${local.name_stem}"
    }
    function_content_share = "${local.naming_prefixes.file_share}-function-content-${local.name_stem}"

    azure_sql_server       = "${local.naming_prefixes.azure_sql_server}-${local.name_stem}"
    azure_sql_database     = "${local.naming_prefixes.azure_sql_database}-${local.name_stem}"
    azure_sql_elastic_pool = "${local.naming_prefixes.azure_sql_elastic_pool}-${local.name_stem}"

    sql_managed_instance = "${local.naming_prefixes.sql_managed_instance}-${local.name_stem}"
    sql_mi_nsg           = "${local.naming_prefixes.network_security_group}-sql-managed-instance-${local.name_stem}"
    sql_mi_route_table   = "${local.naming_prefixes.route_table}-sql-managed-instance-${local.name_stem}"

    postgresql_server   = "${local.naming_prefixes.postgresql_server}-${local.name_stem}"
    postgresql_database = "${local.naming_prefixes.postgresql_database}-${local.name_stem}"
    mysql_server        = "${local.naming_prefixes.mysql_server}-${local.name_stem}"
    mysql_database      = "${local.naming_prefixes.mysql_database}-${local.name_stem}"

    cosmos_db_account = "${local.naming_prefixes.cosmos_db_account}-${local.name_stem}"
    cosmos_db_database = substr(
      "${local.naming_prefixes.cosmos_db_database}${local.compact_project}${local.compact_environment}${local.naming_suffix}",
      0,
      48
    )
    cosmos_db_container = substr(
      "${local.naming_prefixes.cosmos_db_container}${local.compact_project}${local.compact_environment}${local.naming_suffix}",
      0,
      48
    )

    container_apps_environment = "${local.naming_prefixes.container_apps_environment}-${local.name_stem}"
    container_app              = "${local.naming_prefixes.container_app}-${local.name_stem}"
    container_app_container    = "${local.naming_prefixes.container_app_container}-${local.name_stem}"
    container_apps_profile = (
      length("${local.naming_prefixes.container_apps_profile}-legacy01") <= 15
      ? "${local.naming_prefixes.container_apps_profile}-legacy01"
      : format("%s-legacy01", substr(local.naming_prefixes.container_apps_profile, 0, 3))
    )
    container_apps_profiles = {
      for key in keys(var.container_apps.dedicated_workload_profiles) : key => (
        length("${local.naming_prefixes.container_apps_profile}-${key}01") <= 15
        ? "${local.naming_prefixes.container_apps_profile}-${key}01"
        : format(
          "%s-%s01",
          substr(local.naming_prefixes.container_apps_profile, 0, 3),
          substr(sha1(key), 0, 8)
        )
      )
    }
    log_analytics_workspace = "${local.naming_prefixes.log_analytics_workspace}-${local.name_stem}"
    container_apps_dns_link = "${local.naming_prefixes.private_dns_link}-container-apps-${local.name_stem}"

    web_app              = "${local.naming_prefixes.web_app}-${local.name_stem}"
    web_app_service_plan = "${local.naming_prefixes.web_app_service_plan}-${local.name_stem}"
    function_app         = "${local.naming_prefixes.function_app}-${local.name_stem}"
    app_service_plan     = "${local.naming_prefixes.app_service_plan}-${local.name_stem}"

    private_endpoints = {
      key_vault          = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.key_vault}-${local.name_stem}"
      container_registry = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.container_registry}-${local.name_stem}"
      premium_files      = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.premium_files_account}-file-${local.name_stem}"
      azure_sql          = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.azure_sql_server}-${local.name_stem}"
      cosmos_db          = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.cosmos_db_account}-${local.name_stem}"
      web_app            = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.web_app}-${local.name_stem}"
      function_app       = "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.function_app}-${local.name_stem}"
      storage = {
        for subresource in ["blob", "file"] :
        subresource => "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.storage_account}-${subresource}-${local.name_stem}"
      }
      function_storage = {
        for subresource in ["blob", "file", "queue", "table"] :
        subresource => "${local.naming_prefixes.private_endpoint}-${local.naming_prefixes.function_storage_account}-${subresource}-${local.name_stem}"
      }
    }

    private_service_connections = {
      key_vault          = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.key_vault}-${local.name_stem}"
      container_registry = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.container_registry}-${local.name_stem}"
      premium_files      = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.premium_files_account}-file-${local.name_stem}"
      azure_sql          = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.azure_sql_server}-${local.name_stem}"
      cosmos_db          = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.cosmos_db_account}-${local.name_stem}"
      web_app            = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.web_app}-${local.name_stem}"
      function_app       = "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.function_app}-${local.name_stem}"
      storage = {
        for subresource in ["blob", "file"] :
        subresource => "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.storage_account}-${subresource}-${local.name_stem}"
      }
      function_storage = {
        for subresource in ["blob", "file", "queue", "table"] :
        subresource => "${local.naming_prefixes.private_service_connection}-${local.naming_prefixes.function_storage_account}-${subresource}-${local.name_stem}"
      }
    }

    private_dns_zone_groups = {
      key_vault          = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.key_vault}-${local.name_stem}"
      container_registry = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.container_registry}-${local.name_stem}"
      premium_files      = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.premium_files_account}-file-${local.name_stem}"
      azure_sql          = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.azure_sql_server}-${local.name_stem}"
      cosmos_db          = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.cosmos_db_account}-${local.name_stem}"
      web_app            = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.web_app}-${local.name_stem}"
      function_app       = "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.function_app}-${local.name_stem}"
      storage = {
        for subresource in ["blob", "file"] :
        subresource => "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.storage_account}-${subresource}-${local.name_stem}"
      }
      function_storage = {
        for subresource in ["blob", "file", "queue", "table"] :
        subresource => "${local.naming_prefixes.private_dns_zone_group}-${local.naming_prefixes.function_storage_account}-${subresource}-${local.name_stem}"
      }
    }
  }

  cosmos_private_dns_zone_by_api = {
    NoSQL     = "privatelink.documents.azure.com"
    MongoDB   = "privatelink.mongo.cosmos.azure.com"
    Cassandra = "privatelink.cassandra.cosmos.azure.com"
    Gremlin   = "privatelink.gremlin.cosmos.azure.com"
    Table     = "privatelink.table.cosmos.azure.com"
  }

  cosmos_private_endpoint_subresource_by_api = {
    NoSQL     = "Sql"
    MongoDB   = "MongoDB"
    Cassandra = "Cassandra"
    Gremlin   = "Gremlin"
    Table     = "Table"
  }

  common_tags = merge(
    {
      environment = var.environment
      managedBy   = "terraform"
      project     = var.project_name
      lifecycle   = "ephemeral"
    },
    var.tags
  )

  private_endpoints_required = anytrue([
    var.services.key_vault,
    var.services.container_registry,
    var.services.storage,
    var.services.premium_files,
    var.services.azure_sql,
    var.services.cosmos_db,
    var.services.web_app,
    var.services.function_app
  ])

  nat_gateway_required = anytrue([
    var.services.virtual_machine,
    var.services.virtual_machine_scale_set,
    var.services.container_apps
  ])

  subnet_enabled = {
    private_endpoints    = local.private_endpoints_required
    virtual_machines     = var.services.virtual_machine || var.services.virtual_machine_scale_set
    container_apps       = var.services.container_apps
    web_app_integration  = var.services.web_app
    function_integration = var.services.function_app
    postgresql           = var.services.postgresql
    mysql                = var.services.mysql
    sql_managed_instance = var.services.sql_managed_instance
  }

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
    container_apps = {
      name             = local.resource_names.subnets.container_apps
      address_prefixes = [var.subnet_cidrs.container_apps]
      delegation = {
        name    = local.resource_names.subnet_delegations.container_apps
        service = "Microsoft.App/environments"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
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
  }

  subnets = {
    for subnet_key, subnet in local.subnet_definitions :
    subnet_key => subnet
    if local.subnet_enabled[subnet_key]
  }

  private_dns_zones = setunion(
    var.services.key_vault ? toset(["privatelink.vaultcore.azure.net"]) : toset([]),
    var.services.container_registry ? toset(["privatelink.azurecr.io"]) : toset([]),
    var.services.storage ? toset([
      "privatelink.blob.core.windows.net",
      "privatelink.file.core.windows.net"
    ]) : toset([]),
    var.services.premium_files ? toset(["privatelink.file.core.windows.net"]) : toset([]),
    var.services.azure_sql ? toset(["privatelink.database.windows.net"]) : toset([]),
    var.services.postgresql ? toset(["privatelink.postgres.database.azure.com"]) : toset([]),
    var.services.mysql ? toset(["privatelink.mysql.database.azure.com"]) : toset([]),
    var.services.web_app ? toset(["privatelink.azurewebsites.net"]) : toset([]),
    var.services.function_app ? toset([
      "privatelink.azurewebsites.net",
      "privatelink.blob.core.windows.net",
      "privatelink.file.core.windows.net",
      "privatelink.queue.core.windows.net",
      "privatelink.table.core.windows.net"
    ]) : toset([]),
    var.services.cosmos_db ? toset([local.cosmos_private_dns_zone_by_api[var.cosmos_db.api_type]]) : toset([])
  )

  private_dns_link_names = {
    for zone_name in local.private_dns_zones :
    zone_name => "${local.naming_prefixes.private_dns_link}-${substr(md5(zone_name), 0, 8)}-${local.name_stem}"
  }
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = local.resource_names.resource_group
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "../../modules/network"

  name                = local.resource_names.virtual_network
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = var.address_space
  subnets             = local.subnets
  planned_subnet_address_prefixes = {
    for subnet_key, cidr in var.subnet_cidrs :
    subnet_key => [cidr]
  }
  tags = local.common_tags
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
  count  = var.services.virtual_machine ? 1 : 0
  source = "../../modules/virtual-machine"

  name                   = local.resource_names.virtual_machine
  network_interface_name = local.resource_names.network_interface
  os_disk_name           = local.resource_names.os_disk
  data_disk_names        = local.resource_names.data_disks
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  subnet_id              = module.network.subnet_ids["virtual_machines"]
  size                   = coalesce(var.vm_size, var.virtual_machine.size)
  admin_username         = var.virtual_machine.admin_username
  os_type                = var.virtual_machine.os_type
  source_image_reference = var.virtual_machine.source_image_reference
  computer_name          = "vm-${substr(local.compact_environment, 0, 6)}-${local.naming_suffix}"
  admin_ssh_public_key   = var.virtual_machine.os_type == "Linux" ? tls_private_key.vm[0].public_key_openssh : null
  admin_password         = var.virtual_machine.os_type == "Windows" ? random_password.vm_windows[0].result : null
  os_disk                = var.virtual_machine.os_disk
  data_disks             = var.virtual_machine.data_disks
  tags                   = local.common_tags

  depends_on = [module.nat_gateway]
}

module "virtual_machine_scale_set" {
  count  = var.services.virtual_machine_scale_set ? 1 : 0
  source = "../../modules/virtual-machine-scale-set"

  name                                         = local.resource_names.virtual_machine_scale_set
  autoscale_setting_name                       = local.resource_names.vmss_autoscale_setting
  network_interface_name                       = local.resource_names.vmss_network_interface
  resource_group_name                          = module.resource_group.name
  location                                     = module.resource_group.location
  subnet_id                                    = module.network.subnet_ids["virtual_machines"]
  size                                         = var.virtual_machine_scale_set.size
  admin_username                               = var.virtual_machine_scale_set.admin_username
  os_type                                      = var.virtual_machine_scale_set.os_type
  source_image_reference                       = var.virtual_machine_scale_set.source_image_reference
  admin_ssh_public_key                         = var.virtual_machine_scale_set.os_type == "Linux" ? tls_private_key.vmss[0].public_key_openssh : null
  admin_password                               = var.virtual_machine_scale_set.os_type == "Windows" ? random_password.vmss_windows[0].result : null
  os_disk                                      = var.virtual_machine_scale_set.os_disk
  data_disks                                   = var.virtual_machine_scale_set.data_disks
  scaling                                      = var.virtual_machine_scale_set.scaling
  zones                                        = var.virtual_machine_scale_set.zones
  upgrade_mode                                 = var.virtual_machine_scale_set.upgrade_mode
  enable_accelerated_networking                = var.virtual_machine_scale_set.enable_accelerated_networking
  load_balancer_backend_address_pool_ids       = var.virtual_machine_scale_set.load_balancer_backend_address_pool_ids
  application_gateway_backend_address_pool_ids = var.virtual_machine_scale_set.application_gateway_backend_address_pool_ids
  tags                                         = local.common_tags

  depends_on = [module.nat_gateway]
}

module "nat_gateway" {
  count  = local.nat_gateway_required ? 1 : 0
  source = "../../modules/nat-gateway"

  name                = local.resource_names.nat_gateway
  public_ip_name      = local.resource_names.nat_public_ip
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_ids = merge(
    var.services.virtual_machine || var.services.virtual_machine_scale_set ? {
      virtual_machines = module.network.subnet_ids["virtual_machines"]
    } : {},
    var.services.container_apps ? {
      container_apps = module.network.subnet_ids["container_apps"]
    } : {}
  )
  idle_timeout_in_minutes = var.nat_gateway.idle_timeout_in_minutes
  tags                    = local.common_tags
}

module "key_vault" {
  count  = var.services.key_vault ? 1 : 0
  source = "../../modules/key-vault"

  name                     = local.resource_names.key_vault
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = var.key_vault.sku_name
  purge_protection_enabled = var.key_vault.purge_protection_enabled
  tags                     = local.common_tags
}

module "key_vault_private_endpoint" {
  count  = var.services.key_vault ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.key_vault
  private_service_connection_name = local.resource_names.private_service_connections.key_vault
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.key_vault
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.key_vault[0].id
  subresource_names               = ["vault"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.vaultcore.azure.net"]]
  tags                            = local.common_tags
}

module "container_registry" {
  count  = var.services.container_registry ? 1 : 0
  source = "../../modules/container-registry"

  name                = local.resource_names.container_registry
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.common_tags
}

module "container_registry_private_endpoint" {
  count  = var.services.container_registry ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.container_registry
  private_service_connection_name = local.resource_names.private_service_connections.container_registry
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.container_registry
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.container_registry[0].id
  subresource_names               = ["registry"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.azurecr.io"]]
  tags                            = local.common_tags
}

module "storage" {
  count  = var.services.storage ? 1 : 0
  source = "../../modules/storage-account"

  name                        = local.resource_names.storage_account
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  replication_type            = var.storage.replication_type
  shared_access_key_enabled   = var.storage.shared_access_key_enabled
  containers                  = local.resource_names.storage_containers
  file_share_names            = local.resource_names.storage_file_shares
  file_shares                 = var.storage.file_shares
  data_plane_role_assignments = var.storage.data_plane_role_assignments
  tags                        = local.common_tags
}

module "storage_private_endpoints" {
  for_each = var.services.storage ? toset(["blob", "file"]) : toset([])
  source   = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.storage[each.value]
  private_service_connection_name = local.resource_names.private_service_connections.storage[each.value]
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.storage[each.value]
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.storage[0].id
  subresource_names               = [each.value]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.${each.value}.core.windows.net"]]
  tags                            = local.common_tags
}

module "premium_files" {
  count  = var.services.premium_files ? 1 : 0
  source = "../../modules/premium-files"

  name                = local.resource_names.premium_files_account
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  replication_type    = var.premium_files.replication_type
  file_share_names    = local.resource_names.premium_file_shares
  file_shares         = var.premium_files.file_shares
  tags                = local.common_tags
}

module "premium_files_private_endpoint" {
  count  = var.services.premium_files ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.premium_files
  private_service_connection_name = local.resource_names.private_service_connections.premium_files
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.premium_files
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.premium_files[0].id
  subresource_names               = ["file"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.file.core.windows.net"]]
  tags                            = local.common_tags
}

module "azure_sql" {
  count  = var.services.azure_sql ? 1 : 0
  source = "../../modules/azure-sql"

  server_name       = local.resource_names.azure_sql_server
  database_name     = local.resource_names.azure_sql_database
  database_sku_name = var.azure_sql.database_sku_name
  max_size_gb       = var.azure_sql.max_size_gb
  elastic_pool = merge(
    var.azure_sql.elastic_pool,
    { name = local.resource_names.azure_sql_elastic_pool }
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

module "azure_sql_private_endpoint" {
  count  = var.services.azure_sql ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.azure_sql
  private_service_connection_name = local.resource_names.private_service_connections.azure_sql
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.azure_sql
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.azure_sql[0].server_id
  subresource_names               = ["sqlServer"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.database.windows.net"]]
  tags                            = local.common_tags
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
  subnet_address_prefix       = var.subnet_cidrs.sql_managed_instance
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
  count  = var.services.postgresql ? 1 : 0
  source = "../../modules/postgresql-flexible"

  name                   = local.resource_names.postgresql_server
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  delegated_subnet_id    = module.network.subnet_ids["postgresql"]
  private_dns_zone_id    = module.private_dns.zone_ids["privatelink.postgres.database.azure.com"]
  administrator_password = random_password.postgresql[0].result
  database_name          = local.resource_names.postgresql_database
  administrator_login    = var.postgresql.administrator_login
  sku_name               = var.postgresql.sku_name
  version_number         = var.postgresql.version_number
  storage_mb             = var.postgresql.storage_mb
  zone                   = var.postgresql.zone
  high_availability      = var.postgresql.high_availability
  tags                   = local.common_tags

  depends_on = [module.private_dns]
}

module "mysql" {
  count  = var.services.mysql ? 1 : 0
  source = "../../modules/mysql-flexible"

  name                   = local.resource_names.mysql_server
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  delegated_subnet_id    = module.network.subnet_ids["mysql"]
  private_dns_zone_id    = module.private_dns.zone_ids["privatelink.mysql.database.azure.com"]
  administrator_password = random_password.mysql[0].result
  database_name          = local.resource_names.mysql_database
  administrator_login    = var.mysql.administrator_login
  sku_name               = var.mysql.sku_name
  version_number         = var.mysql.version_number
  zone                   = var.mysql.zone
  high_availability      = var.mysql.high_availability
  tags                   = local.common_tags

  depends_on = [module.private_dns]
}

module "cosmos_db" {
  count  = var.services.cosmos_db ? 1 : 0
  source = "../../modules/cosmos-db"

  name                          = local.resource_names.cosmos_db_account
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  api_type                      = var.cosmos_db.api_type
  database_name                 = local.resource_names.cosmos_db_database
  container_name                = local.resource_names.cosmos_db_container
  throughput                    = var.cosmos_db.throughput
  consistency_level             = var.cosmos_db.consistency_level
  local_authentication_disabled = var.cosmos_db.local_authentication_disabled
  nosql_partition_key_paths     = var.cosmos_db.nosql_partition_key_paths
  mongodb                       = var.cosmos_db.mongodb
  cassandra_schema              = var.cosmos_db.cassandra_schema
  gremlin_partition_key_path    = var.cosmos_db.gremlin_partition_key_path
  tags                          = local.common_tags
}

module "cosmos_db_private_endpoint" {
  count  = var.services.cosmos_db ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.cosmos_db
  private_service_connection_name = local.resource_names.private_service_connections.cosmos_db
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.cosmos_db
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.cosmos_db[0].id
  subresource_names               = [local.cosmos_private_endpoint_subresource_by_api[var.cosmos_db.api_type]]
  private_dns_zone_ids            = [module.private_dns.zone_ids[local.cosmos_private_dns_zone_by_api[var.cosmos_db.api_type]]]
  tags                            = local.common_tags
}

module "container_apps" {
  count  = var.services.container_apps ? 1 : 0
  source = "../../modules/container-apps"

  environment_name             = local.resource_names.container_apps_environment
  app_name                     = local.resource_names.container_app
  log_analytics_workspace_name = local.resource_names.log_analytics_workspace
  private_dns_link_name        = local.resource_names.container_apps_dns_link
  container_name               = local.resource_names.container_app_container
  resource_group_name          = module.resource_group.name
  location                     = module.resource_group.location
  infrastructure_subnet_id     = module.network.subnet_ids["container_apps"]
  virtual_network_id           = module.network.id
  image                        = var.container_apps.image
  target_port                  = var.container_apps.target_port
  dedicated_workload_profile = merge(
    var.container_apps.dedicated_workload_profile,
    { name = local.resource_names.container_apps_profile }
  )
  dedicated_workload_profiles = {
    for key, profile in var.container_apps.dedicated_workload_profiles : key => merge(
      profile,
      { name = local.resource_names.container_apps_profiles[key] }
    )
  }
  app_workload_profile = var.container_apps.app_workload_profile
  tags                 = local.common_tags

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

module "web_app_private_endpoint" {
  count  = var.services.web_app ? 1 : 0
  source = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.web_app
  private_service_connection_name = local.resource_names.private_service_connections.web_app
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.web_app
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.web_app[0].id
  subresource_names               = ["sites"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.azurewebsites.net"]]
  tags                            = local.common_tags
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
  for_each = var.services.function_app ? toset(["blob", "file", "queue", "table"]) : toset([])
  source   = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints.function_storage[each.value]
  private_service_connection_name = local.resource_names.private_service_connections.function_storage[each.value]
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.function_storage[each.value]
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.function_storage[0].id
  subresource_names               = [each.value]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.${each.value}.core.windows.net"]]
  tags                            = local.common_tags
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

  name                            = local.resource_names.private_endpoints.function_app
  private_service_connection_name = local.resource_names.private_service_connections.function_app
  private_dns_zone_group_name     = local.resource_names.private_dns_zone_groups.function_app
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = module.function_app[0].id
  subresource_names               = ["sites"]
  private_dns_zone_ids            = [module.private_dns.zone_ids["privatelink.azurewebsites.net"]]
  tags                            = local.common_tags
}
