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
      web_app_integration  = "${local.naming_prefixes.subnet}-app-${local.name_stem}"
      function_integration = "${local.naming_prefixes.subnet}-func-${local.name_stem}"
      postgresql           = "${local.naming_prefixes.subnet}-psql-${local.name_stem}"
      mysql                = "${local.naming_prefixes.subnet}-mysql-${local.name_stem}"
      sql_managed_instance = "${local.naming_prefixes.subnet}-sqlmi-${local.name_stem}"
      load_balancers       = "${local.naming_prefixes.subnet}-lb-${local.name_stem}"
    }

    subnet_delegations = {
      web_app_integration  = "${local.naming_prefixes.subnet_delegation}-web-app-integration-${local.name_stem}"
      function_integration = "${local.naming_prefixes.subnet_delegation}-function-integration-${local.name_stem}"
      postgresql           = "${local.naming_prefixes.subnet_delegation}-postgresql-${local.name_stem}"
      mysql                = "${local.naming_prefixes.subnet_delegation}-mysql-${local.name_stem}"
      sql_managed_instance = "${local.naming_prefixes.subnet_delegation}-sql-managed-instance-${local.name_stem}"
    }

    nat_gateway   = "${local.naming_prefixes.nat_gateway}-${local.name_stem}"
    nat_public_ip = "${local.naming_prefixes.public_ip}-nat-${local.name_stem}"

    # The hub-side name carries the stem so peerings from several spokes stay
    # unique on the shared hub VNet.
    virtual_network_peerings = {
      spoke_to_hub = "${local.naming_prefixes.virtual_network_peering}-${local.name_stem}-to-hub"
      hub_to_spoke = "${local.naming_prefixes.virtual_network_peering}-hub-to-${local.name_stem}"
    }

    # Rule and route names are scoped to their group or table, so they use
    # only their own key.
    network_security_groups = {
      for key in keys(var.network_security_groups) :
      key => "${local.naming_prefixes.network_security_group}-${key}-${local.name_stem}"
    }
    route_tables = {
      for key in keys(var.route_tables) :
      key => "${local.naming_prefixes.route_table}-${key}-${local.name_stem}"
    }

    # Frontend, pool, probe, and rule names are scoped to their load balancer,
    # so probe and rule names use only their own key.
    load_balancers = {
      for key, load_balancer in var.load_balancers : key => {
        name                           = "${local.naming_prefixes.load_balancer}-${key}-${local.name_stem}"
        frontend_ip_configuration_name = "${local.naming_prefixes.load_balancer_frontend}-${key}-${local.name_stem}"
        backend_address_pool_name      = "${local.naming_prefixes.load_balancer_backend_pool}-${key}-${local.name_stem}"
        probes = {
          for probe_key in keys(load_balancer.probes) :
          probe_key => "${local.naming_prefixes.load_balancer_probe}-${probe_key}-${local.name_stem}"
        }
        rules = {
          for rule_key in keys(load_balancer.rules) :
          rule_key => "${local.naming_prefixes.load_balancer_rule}-${rule_key}-${local.name_stem}"
        }
      }
    }
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

    # Server names are globally unique and at most 51 characters here, within
    # the 63-character limit, so the readable key is used without hashing.
    # Database and pool names are scoped to their server.
    azure_sql_servers = {
      for key in keys(var.azure_sql_servers) : key => {
        server_name       = "${local.naming_prefixes.azure_sql_server}-${key}-${local.name_stem}"
        database_name     = "${local.naming_prefixes.azure_sql_database}-${key}-${local.name_stem}"
        elastic_pool_name = "${local.naming_prefixes.azure_sql_elastic_pool}-${key}-${local.name_stem}"
      }
    }

    sql_managed_instance = "${local.naming_prefixes.sql_managed_instance}-${local.name_stem}"
    sql_mi_nsg           = "${local.naming_prefixes.network_security_group}-sql-managed-instance-${local.name_stem}"
    sql_mi_route_table   = "${local.naming_prefixes.route_table}-sql-managed-instance-${local.name_stem}"

    # Server names are globally unique (<name>.postgres.database.azure.com) and
    # at most 51 characters here, within the 63-character limit, so the readable
    # key is used without hashing. Database names are scoped to their server.
    postgresql_servers = {
      for key in keys(var.postgresql_servers) : key => {
        server_name   = "${local.naming_prefixes.postgresql_server}-${key}-${local.name_stem}"
        database_name = "${local.naming_prefixes.postgresql_database}-${key}-${local.name_stem}"
      }
    }

    # Server names are globally unique (<name>.mysql.database.azure.com) and at
    # most 51 characters here, within the 63-character limit, so the readable
    # key is used without hashing. Database names are scoped to their server.
    mysql_servers = {
      for key in keys(var.mysql_servers) : key => {
        server_name   = "${local.naming_prefixes.mysql_server}-${key}-${local.name_stem}"
        database_name = "${local.naming_prefixes.mysql_database}-${key}-${local.name_stem}"
      }
    }

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

    # Each environment has its own subnet, private DNS zone link, and workload
    # profile names (profile names are scoped to their environment). App names
    # are unique per resource group and capped at 32 characters, so they use
    # <prefix>-<app key>-<environment key>-<suffix> without the project and
    # environment labels; the key limits keep the longest name at 32.
    container_apps_environments = {
      for environment_key, environment in var.container_apps_environments : environment_key => {
        name                   = "${local.naming_prefixes.container_apps_environment}-${environment_key}-${local.name_stem}"
        subnet_name            = "${local.naming_prefixes.subnet}-aca-${environment_key}-${local.name_stem}"
        subnet_delegation_name = "${local.naming_prefixes.subnet_delegation}-container-apps-${environment_key}-${local.name_stem}"
        private_dns_link_name  = "${local.naming_prefixes.private_dns_link}-container-apps-${environment_key}-${local.name_stem}"
        workload_profiles = {
          for profile_key in keys(environment.dedicated_workload_profiles) : profile_key => (
            length("${local.naming_prefixes.container_apps_profile}-${profile_key}01") <= 15
            ? "${local.naming_prefixes.container_apps_profile}-${profile_key}01"
            : format(
              "%s-%s01",
              substr(local.naming_prefixes.container_apps_profile, 0, 3),
              substr(sha1(profile_key), 0, 8)
            )
          )
        }
        apps = {
          for app_key in keys(environment.apps) :
          app_key => "${local.naming_prefixes.container_app}-${app_key}-${environment_key}-${local.naming_suffix}"
        }
      }
    }
    # Container names are scoped to their app, so every app reuses this name.
    container_app_container = "${local.naming_prefixes.container_app_container}-${local.name_stem}"
    log_analytics_workspace = "${local.naming_prefixes.log_analytics_workspace}-${local.name_stem}"

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
}
