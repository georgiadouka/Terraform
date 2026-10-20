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

locals {
  naming_suffix       = coalesce(var.naming.unique_suffix, random_string.suffix.result)
  name_stem           = "${var.project_name}-${var.environment}-${local.naming_suffix}"
  compact_project     = replace(var.project_name, "-", "")
  compact_environment = replace(var.environment, "-", "")
  naming_prefixes     = var.naming.prefixes
  # Compact per-key tokens for globally unique names with tight length limits:
  # up to five key characters plus five SHA-1 characters, so similar keys still
  # produce distinct names.
  logical_key_tokens = {
    for key in setunion(
      toset(keys(var.storage_accounts)),
      toset(keys(var.premium_file_accounts)),
      toset(keys(var.key_vaults)),
      toset(keys(var.container_registries)),
      toset(keys(var.cosmos_db_accounts))
    ) : key => "${substr(replace(key, "-", ""), 0, 5)}${substr(sha1(key), 0, 5)}"
  }

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

    nat_gateway   = "${local.naming_prefixes.nat_gateway}-${local.name_stem}"
    nat_public_ip = "${local.naming_prefixes.public_ip}-nat-${local.name_stem}"
    # Instance hostnames use a 9-character prefix (the Windows limit) that is
    # unique per key, so scale sets in the same VNet never share hostnames.
    virtual_machine_scale_sets = {
      for key in keys(var.virtual_machine_scale_sets) : key => {
        name                   = "${local.naming_prefixes.virtual_machine_scale_set}-${key}-${local.name_stem}"
        network_interface_name = "${local.naming_prefixes.network_interface}-vmss-${key}-${local.name_stem}"
        autoscale_setting_name = "${local.naming_prefixes.autoscale_setting}-${key}-${local.name_stem}"
        computer_name_prefix   = "vmss${substr(sha1(key), 0, 5)}"
      }
    }
    virtual_machines = {
      for key, vm in var.virtual_machines : key => {
        name                   = "${local.naming_prefixes.virtual_machine}-${key}-${local.name_stem}"
        network_interface_name = "${local.naming_prefixes.network_interface}-${key}-${local.name_stem}"
        os_disk_name           = "${local.naming_prefixes.os_disk}-${key}-${local.name_stem}"
        computer_name          = "vm-${substr(sha1(key), 0, 6)}-${local.naming_suffix}"
        data_disk_names = {
          for label in keys(vm.data_disks) :
          label => "${local.naming_prefixes.data_disk}-${label}-${key}-${local.name_stem}"
        }
      }
    }

    # <prefix>-<key token><project><environment>-<suffix>, within 24 characters.
    # The prefix is limited to seven characters so the key token is never cut.
    key_vaults = {
      for key in keys(var.key_vaults) : key => format(
        "%s-%s",
        substr(
          "${local.naming_prefixes.key_vault}-${local.logical_key_tokens[key]}${local.compact_project}${local.compact_environment}",
          0,
          23 - length(local.naming_suffix)
        ),
        local.naming_suffix
      )
    }

    # Alphanumeric only and at most 45 characters, within the 5-50 character limit.
    container_registries = {
      for key in keys(var.container_registries) :
      key => "${local.naming_prefixes.container_registry}${local.logical_key_tokens[key]}${local.compact_project}${local.compact_environment}${local.naming_suffix}"
    }

    storage_accounts = {
      for key in keys(var.storage_accounts) : key => format(
        "%s%s",
        substr(
          "${local.naming_prefixes.storage_account}${local.logical_key_tokens[key]}${local.compact_project}${local.compact_environment}",
          0,
          24 - length(local.naming_suffix)
        ),
        local.naming_suffix
      )
    }
    premium_file_accounts = {
      for key in keys(var.premium_file_accounts) : key => format(
        "%s%s",
        substr(
          "${local.naming_prefixes.premium_files_account}${local.logical_key_tokens[key]}${local.compact_project}${local.compact_environment}",
          0,
          24 - length(local.naming_suffix)
        ),
        local.naming_suffix
      )
    }
    function_storage_account = format(
      "%s%s",
      substr("${local.naming_prefixes.function_storage_account}${local.compact_project}${local.compact_environment}", 0, 24 - length(local.naming_suffix)),
      local.naming_suffix
    )

    storage_containers = {
      for account_key, account in var.storage_accounts : account_key => {
        for label in account.containers :
        label => "${local.naming_prefixes.storage_container}-${label}-${local.name_stem}"
      }
    }
    storage_file_shares = {
      for account_key, account in var.storage_accounts : account_key => {
        for label in keys(account.file_shares) :
        label => "${local.naming_prefixes.file_share}-${label}-${local.name_stem}"
      }
    }
    premium_file_shares = {
      for account_key, account in var.premium_file_accounts : account_key => {
        for label in keys(account.file_shares) :
        label => "${local.naming_prefixes.file_share}-${label}-${local.name_stem}"
      }
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

    # <prefix>-<key token><project><environment>-<suffix>, within 44 characters.
    # Database and container names are scoped to each account, so every account
    # reuses the same names.
    cosmos_db_accounts = {
      for key in keys(var.cosmos_db_accounts) : key => format(
        "%s-%s",
        substr(
          "${local.naming_prefixes.cosmos_db_account}-${local.logical_key_tokens[key]}${local.compact_project}${local.compact_environment}",
          0,
          43 - length(local.naming_suffix)
        ),
        local.naming_suffix
      )
    }
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
      for key, endpoint in local.private_endpoint_catalog : key => {
        name                            = "${local.naming_prefixes.private_endpoint}-${endpoint.name_token}-${local.name_stem}"
        private_service_connection_name = "${local.naming_prefixes.private_service_connection}-${endpoint.name_token}-${local.name_stem}"
        private_dns_zone_group_name     = "${local.naming_prefixes.private_dns_zone_group}-${endpoint.name_token}-${local.name_stem}"
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

  # Every Private Endpoint the lab can create, keyed by a stable endpoint key.
  # Entries hold only plan-time values (no module references) so names and
  # for_each keys are always known. Names follow <prefix>-<name_token>-<stem>.
  # function_host_storage entries are deployed by a separate module call because
  # the Function App must wait for them before it is created.
  private_endpoint_catalog = merge(
    {
      azure_sql = {
        enabled               = var.services.azure_sql
        function_host_storage = false
        target                = "azure_sql"
        name_token            = local.naming_prefixes.azure_sql_server
        subresource           = "sqlServer"
        dns_zone              = "privatelink.database.windows.net"
      }
      web_app = {
        enabled               = var.services.web_app
        function_host_storage = false
        target                = "web_app"
        name_token            = local.naming_prefixes.web_app
        subresource           = "sites"
        dns_zone              = "privatelink.azurewebsites.net"
      }
      function_app = {
        enabled               = var.services.function_app
        function_host_storage = false
        target                = "function_app"
        name_token            = local.naming_prefixes.function_app
        subresource           = "sites"
        dns_zone              = "privatelink.azurewebsites.net"
      }
    },
    {
      for registry_key in keys(var.container_registries) :
      "container_registry/${registry_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "container_registry/${registry_key}"
        name_token            = "${local.naming_prefixes.container_registry}-${registry_key}"
        subresource           = "registry"
        dns_zone              = "privatelink.azurecr.io"
      }
    },
    {
      for account_key, account in var.cosmos_db_accounts :
      "cosmos_db/${account_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "cosmos_db/${account_key}"
        name_token            = "${local.naming_prefixes.cosmos_db_account}-${account_key}"
        subresource           = local.cosmos_private_endpoint_subresource_by_api[account.api_type]
        dns_zone              = local.cosmos_private_dns_zone_by_api[account.api_type]
      }
    },
    {
      for vault_key in keys(var.key_vaults) :
      "key_vault/${vault_key}" => {
        enabled               = true
        function_host_storage = false
        target                = "key_vault/${vault_key}"
        name_token            = "${local.naming_prefixes.key_vault}-${vault_key}"
        subresource           = "vault"
        dns_zone              = "privatelink.vaultcore.azure.net"
      }
    },
    {
      for pair in setproduct(keys(var.storage_accounts), ["blob", "file"]) :
      "storage/${pair[0]}/${pair[1]}" => {
        enabled               = true
        function_host_storage = false
        target                = "storage/${pair[0]}"
        name_token            = "${local.naming_prefixes.storage_account}-${pair[0]}-${pair[1]}"
        subresource           = pair[1]
        dns_zone              = "privatelink.${pair[1]}.core.windows.net"
      }
    },
    {
      for account_key in keys(var.premium_file_accounts) :
      "premium_files/${account_key}/file" => {
        enabled               = true
        function_host_storage = false
        target                = "premium_files/${account_key}"
        name_token            = "${local.naming_prefixes.premium_files_account}-${account_key}-file"
        subresource           = "file"
        dns_zone              = "privatelink.file.core.windows.net"
      }
    },
    {
      for subresource in ["blob", "file", "queue", "table"] :
      "function_storage/${subresource}" => {
        enabled               = var.services.function_app
        function_host_storage = true
        target                = "function_storage"
        name_token            = "${local.naming_prefixes.function_storage_account}-${subresource}"
        subresource           = subresource
        dns_zone              = "privatelink.${subresource}.core.windows.net"
      }
    }
  )

  service_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && !endpoint.function_host_storage
  }

  function_storage_private_endpoints = {
    for key, endpoint in local.private_endpoint_catalog : key => endpoint
    if endpoint.enabled && endpoint.function_host_storage
  }

  # Private Link resource IDs keyed by catalog target. Function host storage is
  # resolved separately so its endpoints do not wait for the Function App.
  private_endpoint_target_ids = merge(
    var.services.azure_sql ? { azure_sql = module.azure_sql[0].server_id } : {},
    var.services.web_app ? { web_app = module.web_app[0].id } : {},
    var.services.function_app ? { function_app = module.function_app[0].id } : {},
    { for key, registry in module.container_registry : "container_registry/${key}" => registry.id },
    { for key, account in module.cosmos_db : "cosmos_db/${key}" => account.id },
    { for key, vault in module.key_vault : "key_vault/${key}" => vault.id },
    { for key, account in module.storage : "storage/${key}" => account.id },
    { for key, account in module.premium_files : "premium_files/${key}" => account.id }
  )

  function_storage_target_ids = var.services.function_app ? {
    function_storage = module.function_storage[0].id
  } : {}

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
    for endpoint in values(local.private_endpoint_catalog) : endpoint.enabled
  ])

  virtual_machine_subnet_required = length(var.virtual_machines) > 0 || length(var.virtual_machine_scale_sets) > 0

  nat_gateway_required = local.virtual_machine_subnet_required || var.services.container_apps

  subnet_enabled = {
    private_endpoints    = local.private_endpoints_required
    virtual_machines     = local.virtual_machine_subnet_required
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
    toset([
      for endpoint in values(local.private_endpoint_catalog) : endpoint.dns_zone
      if endpoint.enabled
    ]),
    var.services.postgresql ? toset(["privatelink.postgres.database.azure.com"]) : toset([]),
    var.services.mysql ? toset(["privatelink.mysql.database.azure.com"]) : toset([])
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
  tags                   = local.common_tags

  depends_on = [module.nat_gateway]
}

module "virtual_machine_scale_set" {
  for_each = var.virtual_machine_scale_sets
  source   = "../../modules/virtual-machine-scale-set"

  name                                         = local.resource_names.virtual_machine_scale_sets[each.key].name
  autoscale_setting_name                       = local.resource_names.virtual_machine_scale_sets[each.key].autoscale_setting_name
  network_interface_name                       = local.resource_names.virtual_machine_scale_sets[each.key].network_interface_name
  computer_name_prefix                         = local.resource_names.virtual_machine_scale_sets[each.key].computer_name_prefix
  resource_group_name                          = module.resource_group.name
  location                                     = module.resource_group.location
  subnet_id                                    = module.network.subnet_ids["virtual_machines"]
  size                                         = each.value.size
  admin_username                               = each.value.admin_username
  os_type                                      = each.value.os_type
  source_image_reference                       = each.value.source_image_reference
  admin_ssh_public_key                         = each.value.os_type == "Linux" ? tls_private_key.vmss[each.key].public_key_openssh : null
  admin_password                               = each.value.os_type == "Windows" ? random_password.vmss_windows[each.key].result : null
  os_disk                                      = each.value.os_disk
  data_disks                                   = each.value.data_disks
  scaling                                      = each.value.scaling
  zones                                        = each.value.zones
  upgrade_mode                                 = each.value.upgrade_mode
  enable_accelerated_networking                = each.value.enable_accelerated_networking
  load_balancer_backend_address_pool_ids       = each.value.load_balancer_backend_address_pool_ids
  application_gateway_backend_address_pool_ids = each.value.application_gateway_backend_address_pool_ids
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
    local.virtual_machine_subnet_required ? {
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
  for_each = var.cosmos_db_accounts
  source   = "../../modules/cosmos-db"

  name                          = local.resource_names.cosmos_db_accounts[each.key]
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  api_type                      = each.value.api_type
  database_name                 = local.resource_names.cosmos_db_database
  container_name                = local.resource_names.cosmos_db_container
  throughput                    = each.value.throughput
  consistency_level             = each.value.consistency_level
  local_authentication_disabled = each.value.local_authentication_disabled
  nosql_partition_key_paths     = each.value.nosql_partition_key_paths
  mongodb                       = each.value.mongodb
  cassandra_schema              = each.value.cassandra_schema
  gremlin_partition_key_path    = each.value.gremlin_partition_key_path
  tags                          = local.common_tags
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
  for_each = local.function_storage_private_endpoints
  source   = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints[each.key].name
  private_service_connection_name = local.resource_names.private_endpoints[each.key].private_service_connection_name
  private_dns_zone_group_name     = local.resource_names.private_endpoints[each.key].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = local.function_storage_target_ids[each.value.target]
  subresource_names               = [each.value.subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[each.value.dns_zone]]
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

module "private_endpoints" {
  for_each = local.service_private_endpoints
  source   = "../../modules/private-endpoint"

  name                            = local.resource_names.private_endpoints[each.key].name
  private_service_connection_name = local.resource_names.private_endpoints[each.key].private_service_connection_name
  private_dns_zone_group_name     = local.resource_names.private_endpoints[each.key].private_dns_zone_group_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  subnet_id                       = module.network.subnet_ids["private_endpoints"]
  private_connection_resource_id  = local.private_endpoint_target_ids[each.value.target]
  subresource_names               = [each.value.subresource]
  private_dns_zone_ids            = [module.private_dns.zone_ids[each.value.dns_zone]]
  tags                            = local.common_tags
}
