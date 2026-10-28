locals {
  # METLEN naming standard v0.2:
  #   M-AZU-<TYPE>-<BU>-<DPT>-<APP>-<ENV>-<REG>[-NN]
  #   M-AZU-<TYPE>-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>[-NN]
  # metlen_scope holds <BU>-<DPT>-<APP> and metlen_placement <ENV>-<REG>, so the
  # optional PUB/PRV classifier can sit between them.
  metlen_codes     = local.naming_dictionary.resource_codes
  region_code      = local.naming_dictionary.region_codes[lower(replace(var.location, " ", ""))]
  metlen_scope     = "${var.naming_tokens.business_unit}-${var.naming_tokens.department}-${var.naming_tokens.application}"
  metlen_placement = "${var.naming_tokens.environment}-${local.region_code}"

  # Subnets use the compact <DPT><APP><ENV><PUB|PRV><NN> pattern; the naming
  # register example is PPAECMDEVPRV01. Every lab subnet is private. The number
  # is fixed per subnet role so names never change when other subnets are
  # enabled or disabled; Container Apps environments set their own
  # subnet_number.
  metlen_subnet_prefix = "${var.naming_tokens.department}${var.naming_tokens.application}${var.naming_tokens.environment}PRV"
  subnet_numbers = {
    private_endpoints    = 1
    virtual_machines     = 2
    web_app_integration  = 3
    function_integration = 4
    postgresql           = 5
    mysql                = 6
    sql_managed_instance = 7
    load_balancers       = 8
  }

  # Compact families for resources that cannot use the full grammar (§6):
  # lowercase alphanumeric (Storage Account, Key Vault) and lowercase
  # hyphenated (SQL logical server). Same tokens, no truncation.
  metlen_compact_tokens = lower("${var.naming_tokens.business_unit}${var.naming_tokens.department}${var.naming_tokens.application}${var.naming_tokens.environment}${local.region_code}")

  # Legacy sample naming, used by resources not yet migrated.
  naming_suffix   = coalesce(var.naming.unique_suffix, random_string.suffix.result)
  name_stem       = "${var.project_name}-${var.environment}-${local.naming_suffix}"
  naming_prefixes = var.naming.prefixes

  resource_names = {
    # Reference only: Terraform deploys into var.subscription_id and does not
    # create or rename the subscription.
    subscription_display_name = "M-AZU-${local.metlen_codes.subscription}-${var.naming_tokens.business_unit}-${var.naming_tokens.department}"

    resource_group = "M-AZU-${local.metlen_codes.resource_group}-${local.metlen_scope}-${local.metlen_placement}"
    # Network family: M-AZU-<TYPE>-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>[-NN].
    virtual_network = "M-AZU-${local.metlen_codes.virtual_network}-${local.metlen_scope}-PRV-${local.metlen_placement}"

    subnets = {
      for subnet_key, number in local.subnet_numbers :
      subnet_key => format("%s%02d", local.metlen_subnet_prefix, number)
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
      for key, nsg in var.network_security_groups :
      key => join("-", compact(["M-AZU", local.metlen_codes.network_security_group, local.metlen_scope, nsg.classification, local.metlen_placement, nsg.sequence]))
    }
    route_tables = {
      for key, route_table in var.route_tables :
      key => join("-", compact(["M-AZU", local.metlen_codes.route_table, local.metlen_scope, route_table.classification, local.metlen_placement, route_table.sequence]))
    }

    # M-AZU-LBL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>. Frontend, pool, probe and
    # rule names are scoped to their load balancer and not covered by the
    # standard, so they use fixed names or their own key, like NSG rules.
    load_balancers = {
      for key, load_balancer in var.load_balancers : key => {
        name                           = join("-", ["M-AZU", local.metlen_codes.load_balancer, local.metlen_scope, local.metlen_placement, load_balancer.sequence])
        frontend_ip_configuration_name = "frontend"
        backend_address_pool_name      = "backend"
        probes                         = { for probe_key in keys(load_balancer.probes) : probe_key => probe_key }
        rules                          = { for rule_key in keys(load_balancer.rules) : rule_key => rule_key }
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

    # mazukva<BU><DPT><APP><ENV><REG><NN>, 3-24 lowercase alphanumeric, global.
    key_vaults = {
      for key, vault in var.key_vaults :
      key => "mazu${lower(local.metlen_codes.key_vault)}${local.metlen_compact_tokens}${vault.sequence}"
    }

    # mazuacr<BU><DPT><APP><ENV><REG><NN>, same compact family as Storage
    # Accounts; registry names are global, 5-50 letters and digits.
    container_registries = {
      for key, registry in var.container_registries :
      key => "mazu${lower(local.metlen_codes.container_registry)}${local.metlen_compact_tokens}${registry.sequence}"
    }

    # mazusoa<BU><DPT><APP><ENV><REG><NN>, 3-24 lowercase alphanumeric, global.
    # Premium Files and Function host storage are Storage Accounts too.
    storage_accounts = {
      for key, account in var.storage_accounts :
      key => "mazu${lower(local.metlen_codes.storage_account)}${local.metlen_compact_tokens}${account.sequence}"
    }
    premium_file_accounts = {
      for key, account in var.premium_file_accounts :
      key => "mazu${lower(local.metlen_codes.storage_account)}${local.metlen_compact_tokens}${account.sequence}"
    }

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

    # The logical server name is global DNS (<name>.database.windows.net) and
    # must be lowercase. The database is scoped to its server and uses the full
    # family with the server's NN. Elastic pools have no METLEN code yet.
    azure_sql_servers = {
      for key, server in var.azure_sql_servers : key => {
        server_name       = lower(join("-", ["M-AZU", local.metlen_codes.azure_sql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name     = join("-", ["M-AZU", local.metlen_codes.azure_sql_database, local.metlen_scope, local.metlen_placement, server.sequence])
        elastic_pool_name = "${local.naming_prefixes.azure_sql_elastic_pool}-${key}-${local.name_stem}"
      }
    }

    # m-azu-smi-<bu>-<dpt>-<app>-<env>-<reg>-<NN>: the instance name is global
    # DNS (<name>.<id>.database.windows.net) and must be lowercase, like the SQL
    # logical server. The NSG and route table use the network family with the
    # instance's network NN.
    sql_managed_instances = {
      for key, instance in var.sql_managed_instances : key => {
        name                        = lower(join("-", ["M-AZU", local.metlen_codes.sql_managed_instance, local.metlen_scope, local.metlen_placement, instance.sequence]))
        network_security_group_name = join("-", compact(["M-AZU", local.metlen_codes.network_security_group, local.metlen_scope, "PRV", local.metlen_placement, instance.network_sequence]))
        route_table_name            = join("-", compact(["M-AZU", local.metlen_codes.route_table, local.metlen_scope, "PRV", local.metlen_placement, instance.network_sequence]))
      }
    }

    # Same approach as Azure SQL: the server name is global DNS
    # (<name>.postgres.database.azure.com / <name>.mysql.database.azure.com) and
    # must be lowercase; the database is scoped to its server and uses the full
    # family with the server's NN. MySQL stores database names in lowercase
    # (lower_case_table_names = 1), so its database name is lowercase too.
    postgresql_servers = {
      for key, server in var.postgresql_servers : key => {
        server_name   = lower(join("-", ["M-AZU", local.metlen_codes.postgresql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name = join("-", ["M-AZU", local.metlen_codes.postgresql_server, local.metlen_scope, local.metlen_placement, server.sequence])
      }
    }
    mysql_servers = {
      for key, server in var.mysql_servers : key => {
        server_name   = lower(join("-", ["M-AZU", local.metlen_codes.mysql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name = lower(join("-", ["M-AZU", local.metlen_codes.mysql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
      }
    }

    # Account: m-azu-cdb-<bu>-<dpt>-<app>-<env>-<reg>-<NN> (global
    # <name>.documents.azure.com, 3-44 lowercase letters, digits and hyphens),
    # like the SQL logical server. Database and container names must be valid
    # for every API (Cassandra keyspaces allow only letters, digits and
    # underscores up to 48; Table API tables only letters and digits), so they
    # use the compact family mazucdb...<NN> with the account's NN.
    cosmos_db_accounts = {
      for key, account in var.cosmos_db_accounts :
      key => lower(join("-", ["M-AZU", local.metlen_codes.cosmos_db_account, local.metlen_scope, local.metlen_placement, account.sequence]))
    }
    cosmos_db_databases = {
      for key, account in var.cosmos_db_accounts :
      key => "mazu${lower(local.metlen_codes.cosmos_db_account)}${local.metlen_compact_tokens}${account.sequence}"
    }
    cosmos_db_containers = {
      for key, account in var.cosmos_db_accounts :
      key => "mazu${lower(local.metlen_codes.cosmos_db_account)}${local.metlen_compact_tokens}${account.sequence}"
    }

    # Environment: M-AZU-CEV-...-<NN>. The provider accepts 2-60 alphanumerics
    # and hyphens, so the full family is used. Each environment has its own
    # subnet, private DNS zone link, and workload profile names (profile names
    # are scoped to their environment). Apps use the lowercase variant
    # m-azu-cap-...-<NN> because Container App names are 2-32 lowercase
    # characters, unique per resource group.
    container_apps_environments = {
      for environment_key, environment in var.container_apps_environments : environment_key => {
        name                   = join("-", ["M-AZU", local.metlen_codes.container_apps_env, local.metlen_scope, local.metlen_placement, environment.sequence])
        subnet_name            = format("%s%02d", local.metlen_subnet_prefix, environment.subnet_number)
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
          for app_key, app in environment.apps :
          app_key => lower(join("-", ["M-AZU", local.metlen_codes.container_app, local.metlen_scope, local.metlen_placement, app.sequence]))
        }
      }
    }
    # Container names are scoped to their app, so every app reuses this name.
    container_app_container = "${local.naming_prefixes.container_app_container}-${local.name_stem}"
    log_analytics_workspace = "${local.naming_prefixes.log_analytics_workspace}-${local.name_stem}"

    # App Service family. Web App and Function App names are global
    # (<name>.azurewebsites.net). App Service Plans are declared once in
    # app_service_plans and apps select one by key, so plan NN values live in a
    # single map and cannot collide. The Function App has no NN in the
    # standard; an optional sequence is the fallback when the global name is
    # taken or a second Function App is added. The name stays within the 32
    # characters Azure uses for the Functions host ID. Each Function App has
    # its own host Storage Account (mazusoa... family), so the content share
    # name is scoped to that account and shared by every app.
    app_service_plans = {
      for key, plan in var.app_service_plans :
      key => join("-", ["M-AZU", local.metlen_codes.app_service_plan, local.metlen_scope, local.metlen_placement, plan.sequence])
    }
    web_apps = {
      for key, app in var.web_apps : key => {
        name = join("-", ["M-AZU", local.metlen_codes.app_service, local.metlen_scope, local.metlen_placement, app.sequence])
      }
    }
    function_apps = {
      for key, app in var.function_apps : key => {
        name                 = join("-", compact(["M-AZU", local.metlen_codes.function_app, local.metlen_scope, local.metlen_placement, app.sequence]))
        storage_account_name = "mazu${lower(local.metlen_codes.storage_account)}${local.metlen_compact_tokens}${app.storage_sequence}"
        content_share_name   = "${local.naming_prefixes.file_share}-function-content-${local.name_stem}"
      }
    }
  }
}
