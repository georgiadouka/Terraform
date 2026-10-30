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
  # register example is PPAECMDEVPRV01. PUB/PRV is the classification of the
  # subnet's VNet. The number is fixed per subnet role so names never change
  # when other subnets are enabled or disabled; Container Apps environments
  # and Databricks workspaces set their own numbers. Subnet names are scoped
  # to their VNet, so every VNet reuses the same numbers.
  metlen_subnet_prefix = "${var.naming_tokens.department}${var.naming_tokens.application}${var.naming_tokens.environment}"
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

  # Network family: M-AZU-VNT-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>, no NN, so
  # the classification (the network intent) is what tells VNets apart. Kept
  # outside resource_names so the hub_peering validation can check peering
  # name lengths without a dependency cycle.
  virtual_network_names = {
    for key, network in var.virtual_networks :
    key => join("-", ["M-AZU", local.metlen_codes.virtual_network, local.metlen_scope, network.classification, local.metlen_placement])
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
    # One entry per VNet: its name and the names of the subnets it can hold.
    virtual_networks = {
      for key, network in var.virtual_networks : key => {
        name           = local.virtual_network_names[key]
        classification = network.classification
        subnets = {
          for subnet_key, number in local.subnet_numbers :
          subnet_key => format("%s%s%02d", local.metlen_subnet_prefix, network.classification, number)
        }
      }
    }

    subnet_delegations = {
      web_app_integration  = "${local.naming_prefixes.subnet_delegation}-web-app-integration-${local.name_stem}"
      function_integration = "${local.naming_prefixes.subnet_delegation}-function-integration-${local.name_stem}"
      postgresql           = "${local.naming_prefixes.subnet_delegation}-postgresql-${local.name_stem}"
      mysql                = "${local.naming_prefixes.subnet_delegation}-mysql-${local.name_stem}"
      sql_managed_instance = "${local.naming_prefixes.subnet_delegation}-sql-managed-instance-${local.name_stem}"
    }

    # M-AZU-NGW-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>-<NN>, one per VNet, with
    # the classification of that VNet. The gateway's Public IP mirrors the
    # name (same classifier and NN) so the pair is visibly linked; there the
    # classifier names the VNet the address serves, not its exposure.
    nat_gateways = {
      for key, nat_gateway in var.nat_gateways : key => {
        name           = join("-", ["M-AZU", local.metlen_codes.nat_gateway, local.metlen_scope, try(var.virtual_networks[key].classification, "PRV"), local.metlen_placement, nat_gateway.sequence])
        public_ip_name = join("-", ["M-AZU", local.metlen_codes.public_ip, local.metlen_scope, try(var.virtual_networks[key].classification, "PRV"), local.metlen_placement, nat_gateway.sequence])
      }
    }

    # <local VNet name>-to-<remote VNet name>. Peering names are scoped to the
    # local VNet, and the VNet names are unique, so the hub side stays unique
    # when several spokes peer with the same hub.
    hub_peerings = {
      for key in local.hub_peering_virtual_networks : key => {
        spoke_to_hub = "${local.virtual_network_names[key]}-to-${local.hub_virtual_network.name}"
        hub_to_spoke = "${local.hub_virtual_network.name}-to-${local.virtual_network_names[key]}"
      }
    }
    virtual_network_peerings = {
      for key, side in local.virtual_network_peering_sides :
      key => "${local.virtual_network_names[side.virtual_network]}-to-${local.virtual_network_names[side.remote_virtual_network]}"
    }

    # Link names are scoped to their Private DNS zone, so every link takes the
    # name of the VNet it links.
    private_dns_links = local.virtual_network_names

    # Rule and route names are scoped to their group or table, so they use
    # only their own key. The classification defaults to that of the VNet.
    network_security_groups = {
      for key, nsg in var.network_security_groups :
      key => join("-", compact(["M-AZU", local.metlen_codes.network_security_group, local.metlen_scope, coalesce(nsg.classification, try(var.virtual_networks[local.network_security_group_networks[key]].classification, "PRV")), local.metlen_placement, nsg.sequence]))
    }
    route_tables = {
      for key, route_table in var.route_tables :
      key => join("-", compact(["M-AZU", local.metlen_codes.route_table, local.metlen_scope, coalesce(route_table.classification, try(var.virtual_networks[local.route_table_networks[key]].classification, "PRV")), local.metlen_placement, route_table.sequence]))
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

    # Blob containers, file shares and databases are named by the application
    # and follow no convention: the configured name is used as-is (databases
    # and Cosmos DB containers default to the entry key). They are kept here,
    # keyed like the other names, so main.tf and the outputs read every name
    # from one place.
    storage_containers = {
      for account_key, account in var.storage_accounts : account_key => {
        for name in account.containers : name => name
      }
    }
    storage_file_shares = {
      for account_key, account in var.storage_accounts : account_key => {
        for name in keys(account.file_shares) : name => name
      }
    }
    premium_file_shares = {
      for account_key, account in var.premium_file_accounts : account_key => {
        for name in keys(account.file_shares) : name => name
      }
    }

    # The logical server name is global DNS (<name>.database.windows.net) and
    # must be lowercase. The optional elastic pool is scoped to its server and
    # uses the full family with the server's NN (one pool per server).
    azure_sql_servers = {
      for key, server in var.azure_sql_servers : key => {
        server_name       = lower(join("-", ["M-AZU", local.metlen_codes.azure_sql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name     = coalesce(server.database_name, key)
        elastic_pool_name = join("-", ["M-AZU", local.metlen_codes.azure_sql_elastic_pool, local.metlen_scope, local.metlen_placement, server.sequence])
      }
    }

    # m-azu-smi-<bu>-<dpt>-<app>-<env>-<reg>-<NN>: the instance name is global
    # DNS (<name>.<id>.database.windows.net) and must be lowercase, like the SQL
    # logical server. The NSG and route table use the network family with the
    # instance's network NN and the classification of the instance's VNet.
    sql_managed_instances = {
      for key, instance in var.sql_managed_instances : key => {
        name                        = lower(join("-", ["M-AZU", local.metlen_codes.sql_managed_instance, local.metlen_scope, local.metlen_placement, instance.sequence]))
        network_security_group_name = join("-", compact(["M-AZU", local.metlen_codes.network_security_group, local.metlen_scope, try(var.virtual_networks[local.virtual_network_placement.sql_managed_instances[key]].classification, "PRV"), local.metlen_placement, instance.network_sequence]))
        route_table_name            = join("-", compact(["M-AZU", local.metlen_codes.route_table, local.metlen_scope, try(var.virtual_networks[local.virtual_network_placement.sql_managed_instances[key]].classification, "PRV"), local.metlen_placement, instance.network_sequence]))
      }
    }

    # Same approach as Azure SQL: the server name is global DNS
    # (<name>.postgres.database.azure.com / <name>.mysql.database.azure.com) and
    # must be lowercase; the database is named by the application.
    postgresql_servers = {
      for key, server in var.postgresql_servers : key => {
        server_name   = lower(join("-", ["M-AZU", local.metlen_codes.postgresql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name = coalesce(server.database_name, key)
      }
    }
    mysql_servers = {
      for key, server in var.mysql_servers : key => {
        server_name   = lower(join("-", ["M-AZU", local.metlen_codes.mysql_server, local.metlen_scope, local.metlen_placement, server.sequence]))
        database_name = coalesce(server.database_name, key)
      }
    }

    # Account: m-azu-cdb-<bu>-<dpt>-<app>-<env>-<reg>-<NN> (global
    # <name>.documents.azure.com, 3-44 lowercase letters, digits and hyphens),
    # like the SQL logical server. The database and container are named by the
    # application; variables.tf checks the rules of each API.
    cosmos_db_accounts = {
      for key, account in var.cosmos_db_accounts :
      key => lower(join("-", ["M-AZU", local.metlen_codes.cosmos_db_account, local.metlen_scope, local.metlen_placement, account.sequence]))
    }
    cosmos_db_databases = {
      for key, account in var.cosmos_db_accounts :
      key => coalesce(account.database_name, key)
    }
    cosmos_db_containers = {
      for key, account in var.cosmos_db_accounts :
      key => coalesce(account.container_name, key)
    }

    # Environment: M-AZU-CEV-...-<NN>. The provider accepts 2-60 alphanumerics
    # and hyphens, so the full family is used. Each environment has its own
    # subnet, private DNS zone link, and workload profile names (profile names
    # are scoped to their environment). Apps use the lowercase variant
    # m-azu-cap-...-<NN> because Container App names are 2-32 lowercase
    # characters, unique per resource group. The subnet name uses the
    # classification of the environment's VNet.
    container_apps_environments = {
      for environment_key, environment in var.container_apps_environments : environment_key => {
        name                   = join("-", ["M-AZU", local.metlen_codes.container_apps_env, local.metlen_scope, local.metlen_placement, environment.sequence])
        subnet_name            = format("%s%s%02d", local.metlen_subnet_prefix, try(var.virtual_networks[local.container_apps_environment_networks[environment_key]].classification, "PRV"), environment.subnet_number)
        subnet_delegation_name = "${local.naming_prefixes.subnet_delegation}-container-apps-${environment_key}-${local.name_stem}"
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
    # Workspace and Access Connector: M-AZU-DBR-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>
    # (3-64 letters, digits, underscores and hyphens, unique per resource
    # group and type). The managed resource group that Azure Databricks
    # creates uses the resource group family with the workspace NN; the
    # optional root (DBFS) storage account the mazusoa... family with
    # storage_sequence. The NSG uses the network family with network_sequence
    # (default: the workspace NN), like SQL Managed Instance. The NSG and the
    # host and container subnets (compact pattern, own numbers) use the
    # classification of the workspace's VNet.
    databricks_workspaces = {
      for key, workspace in var.databricks_workspaces : key => {
        name                             = join("-", ["M-AZU", local.metlen_codes.databricks_workspace, local.metlen_scope, local.metlen_placement, workspace.sequence])
        access_connector_name            = join("-", ["M-AZU", local.metlen_codes.databricks_workspace, local.metlen_scope, local.metlen_placement, workspace.sequence])
        managed_resource_group_name      = join("-", ["M-AZU", local.metlen_codes.resource_group, local.metlen_scope, local.metlen_placement, workspace.sequence])
        root_storage_account_name        = workspace.storage_sequence == null ? null : "mazu${lower(local.metlen_codes.storage_account)}${local.metlen_compact_tokens}${workspace.storage_sequence}"
        network_security_group_name      = join("-", ["M-AZU", local.metlen_codes.network_security_group, local.metlen_scope, try(var.virtual_networks[local.databricks_workspace_networks[key]].classification, "PRV"), local.metlen_placement, coalesce(workspace.network_sequence, workspace.sequence)])
        host_subnet_name                 = format("%s%s%02d", local.metlen_subnet_prefix, try(var.virtual_networks[local.databricks_workspace_networks[key]].classification, "PRV"), workspace.host_subnet_number)
        container_subnet_name            = format("%s%s%02d", local.metlen_subnet_prefix, try(var.virtual_networks[local.databricks_workspace_networks[key]].classification, "PRV"), workspace.container_subnet_number)
        host_subnet_delegation_name      = "${local.naming_prefixes.subnet_delegation}-databricks-${key}-host-${local.name_stem}"
        container_subnet_delegation_name = "${local.naming_prefixes.subnet_delegation}-databricks-${key}-container-${local.name_stem}"
      }
    }
    # Container names are scoped to their app, so every app reuses this name.
    container_app_container = "${local.naming_prefixes.container_app_container}-${local.name_stem}"
    # M-AZU-LAW-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>: one workspace shared by
    # every Container Apps environment; 4-63 letters, digits and hyphens.
    log_analytics_workspace = join("-", ["M-AZU", local.metlen_codes.log_analytics, local.metlen_scope, local.metlen_placement, var.log_analytics_workspace.sequence])
    # M-AZU-AIN-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>: one Application Insights
    # resource shared by every Function App and Web App; 1-255 characters.
    application_insights = join("-", ["M-AZU", local.metlen_codes.application_insights, local.metlen_scope, local.metlen_placement, var.application_insights.sequence])

    # App Service family. Web App and Function App names are global
    # (<name>.azurewebsites.net). App Service Plans are declared once in
    # app_service_plans and apps select one by key, so plan NN values live in a
    # single map and cannot collide. The Function App has no NN in the
    # standard; an optional sequence is the fallback when the global name is
    # taken or a second Function App is added. The name stays within the 32
    # characters Azure uses for the Functions host ID. Each Function App has
    # its own host Storage Account (mazusoa... family), so the internal
    # content share needs no convention: every app uses the fixed name
    # function-content in its own account.
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
        content_share_name   = "function-content"
      }
    }
  }
}
