variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "storage_use_azuread" {
  description = "Whether AzureRM uses Microsoft Entra ID instead of Shared Key for supported Storage Blob and Queue data-plane operations."
  type        = bool
  default     = true

  validation {
    condition = (
      var.storage_use_azuread ||
      alltrue([
        for account in values(var.storage_accounts) :
        account.shared_access_key_enabled
      ])
    )
    error_message = "Every storage_accounts entry must set shared_access_key_enabled to true when storage_use_azuread is false."
  }
}

variable "location" {
  description = "Azure region used by the lab."
  type        = string
  default     = "swedencentral"
}

variable "project_name" {
  description = "Short lowercase project name used in resource names."
  type        = string
  default     = "metlen"

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]{0,10}[a-z0-9]$", var.project_name)) &&
      !strcontains(var.project_name, "--")
    )
    error_message = "project_name must be 2-12 lowercase alphanumeric or hyphen characters, start with a letter, end with an alphanumeric character, and not contain consecutive hyphens."
  }
}

variable "environment" {
  description = "Environment label."
  type        = string
  default     = "lab"

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]{0,6}[a-z0-9]$", var.environment)) &&
      !strcontains(var.environment, "--")
    )
    error_message = "environment must be 2-8 lowercase alphanumeric or hyphen characters, start with a letter, end with an alphanumeric character, and not contain consecutive hyphens."
  }
}

variable "naming" {
  description = "Central naming convention. Names use <prefix>-<project>-<environment>-<suffix>; constrained global names use the same tokens in a compact form."
  type = object({
    unique_suffix = optional(string)
    prefixes = optional(object({
      resource_group             = optional(string, "rg")
      virtual_network            = optional(string, "vnet")
      subnet                     = optional(string, "snet")
      subnet_delegation          = optional(string, "dlg")
      virtual_machine            = optional(string, "vm")
      virtual_machine_scale_set  = optional(string, "vmss")
      network_interface          = optional(string, "nic")
      os_disk                    = optional(string, "osdisk")
      data_disk                  = optional(string, "disk")
      autoscale_setting          = optional(string, "autoscale")
      nat_gateway                = optional(string, "nat")
      load_balancer              = optional(string, "lbi")
      load_balancer_frontend     = optional(string, "lbfe")
      load_balancer_backend_pool = optional(string, "lbbe")
      load_balancer_probe        = optional(string, "lbprobe")
      load_balancer_rule         = optional(string, "lbrule")
      public_ip                  = optional(string, "pip")
      key_vault                  = optional(string, "kv")
      container_registry         = optional(string, "cr")
      storage_account            = optional(string, "st")
      premium_files_account      = optional(string, "stpf")
      function_storage_account   = optional(string, "stfn")
      storage_container          = optional(string, "blob")
      file_share                 = optional(string, "share")
      private_endpoint           = optional(string, "pe")
      private_service_connection = optional(string, "psc")
      private_dns_zone_group     = optional(string, "pdnszg")
      private_dns_link           = optional(string, "pdnslink")
      azure_sql_server           = optional(string, "sql")
      azure_sql_database         = optional(string, "sqldb")
      azure_sql_elastic_pool     = optional(string, "sqlep")
      sql_managed_instance       = optional(string, "sqlmi")
      network_security_group     = optional(string, "nsg")
      route_table                = optional(string, "rt")
      postgresql_server          = optional(string, "psql")
      postgresql_database        = optional(string, "psqldb")
      mysql_server               = optional(string, "mysql")
      mysql_database             = optional(string, "mysqldb")
      cosmos_db_account          = optional(string, "cosmos")
      cosmos_db_database         = optional(string, "cosmosdb")
      cosmos_db_container        = optional(string, "cosmosct")
      container_apps_environment = optional(string, "cae")
      container_app              = optional(string, "ca")
      container_app_container    = optional(string, "ctr")
      container_apps_profile     = optional(string, "wp")
      log_analytics_workspace    = optional(string, "log")
      web_app                    = optional(string, "app")
      web_app_service_plan       = optional(string, "aspweb")
      function_app               = optional(string, "func")
      app_service_plan           = optional(string, "asp")
    }), {})
  })
  default = {}

  validation {
    condition = (
      var.naming.unique_suffix == null ||
      can(regex("^[a-z0-9]{3,5}$", var.naming.unique_suffix))
    )
    error_message = "naming.unique_suffix must be null for a generated five-character suffix or contain 3-5 lowercase alphanumeric characters."
  }

  validation {
    condition = alltrue([
      for prefix in values(var.naming.prefixes) :
      can(regex("^[a-z][a-z0-9]{0,9}$", prefix))
    ])
    error_message = "Every naming prefix must be 1-10 lowercase alphanumeric characters and start with a letter."
  }

  validation {
    condition     = length(var.naming.prefixes.container_app) <= 4
    error_message = "naming.prefixes.container_app must be no more than four characters so generated Container App names (<prefix>-<app key>-<environment key>-<suffix>) remain within Azure's 32-character limit."
  }

  validation {
    condition     = length(var.naming.prefixes.key_vault) <= 7
    error_message = "naming.prefixes.key_vault must be no more than seven characters so every generated Key Vault name keeps its full logical-key token within Azure's 24-character limit."
  }
}

variable "address_space" {
  description = "Lab virtual network address space."
  type        = list(string)
  default     = ["10.42.0.0/20"]

  validation {
    condition = (
      length(var.address_space) > 0 &&
      alltrue([
        for prefix in var.address_space :
        can(cidrnetmask(prefix)) &&
        can(cidrhost(prefix, 0)) &&
        try(cidrhost(prefix, 0) == split("/", prefix)[0], false)
      ])
    )
    error_message = "address_space must contain at least one valid IPv4 CIDR written with its network address."
  }
}

variable "subnet_cidrs" {
  description = "CIDR prefix for each lab subnet. container_apps maps each Container Apps environment key to its own range; load_balancers is one range shared by every load balancer frontend. Ranges are reserved and overlap-checked even when unused; a subnet is created only when something uses it."
  type = object({
    private_endpoints    = string
    virtual_machines     = string
    web_app_integration  = optional(string, "10.42.8.0/26")
    function_integration = string
    postgresql           = string
    mysql                = string
    sql_managed_instance = string
    container_apps       = optional(map(string), {})
    load_balancers       = optional(string)
  })
  default = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }

  validation {
    condition = alltrue([
      for prefix in concat(
        [
          var.subnet_cidrs.private_endpoints,
          var.subnet_cidrs.virtual_machines,
          var.subnet_cidrs.web_app_integration,
          var.subnet_cidrs.function_integration,
          var.subnet_cidrs.postgresql,
          var.subnet_cidrs.mysql,
          var.subnet_cidrs.sql_managed_instance
        ],
        var.subnet_cidrs.load_balancers == null ? [] : [var.subnet_cidrs.load_balancers],
        values(var.subnet_cidrs.container_apps)
      ) :
      can(cidrnetmask(prefix)) &&
      can(cidrhost(prefix, 0)) &&
      try(cidrhost(prefix, 0) == split("/", prefix)[0], false)
    ])
    error_message = "Every subnet_cidrs value must be a valid IPv4 CIDR written with its network address."
  }

  validation {
    condition     = can(tonumber(split("/", var.subnet_cidrs.sql_managed_instance)[1])) && tonumber(split("/", var.subnet_cidrs.sql_managed_instance)[1]) <= 27
    error_message = "The future SQL Managed Instance subnet must be /27 or larger."
  }

  validation {
    condition = alltrue([
      for key in keys(var.subnet_cidrs.container_apps) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "subnet_cidrs.container_apps keys must match Container Apps environment keys: 1-12 lowercase alphanumeric or hyphen characters, starting with a letter, ending with a letter or digit, without consecutive hyphens."
  }

  # A workload profiles environment needs at least a /27; the /23 minimum
  # applies only to Consumption-only environments, which this lab doesn't create.
  validation {
    condition = alltrue([
      for prefix in values(var.subnet_cidrs.container_apps) :
      try(tonumber(split("/", prefix)[1]) <= 27, false)
    ])
    error_message = "Every subnet_cidrs.container_apps range must be /27 or larger."
  }

  # Azure's smallest subnet is /29.
  validation {
    condition     = var.subnet_cidrs.load_balancers == null || try(tonumber(split("/", var.subnet_cidrs.load_balancers)[1]) <= 29, false)
    error_message = "subnet_cidrs.load_balancers must be /29 or larger."
  }
}

variable "virtual_machines" {
  description = "Linux or Windows virtual machines keyed by a stable logical name. Defaults to none; add one entry per VM."
  type = map(object({
    size           = optional(string, "Standard_B2s_v2")
    admin_username = optional(string, "azureadmin")
    os_type        = optional(string, "Linux")
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }))
    os_disk = optional(object({
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "StandardSSD_LRS")
      disk_size_gb         = optional(number)
    }), {})
    data_disks = optional(map(object({
      lun                  = number
      disk_size_gb         = number
      storage_account_type = optional(string, "StandardSSD_LRS")
      caching              = optional(string, "ReadWrite")
      })), {
      data = {
        lun                  = 0
        disk_size_gb         = 32
        storage_account_type = "StandardSSD_LRS"
        caching              = "ReadWrite"
      }
    })
    load_balancer = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.virtual_machines) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "virtual_machines keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for vm in values(var.virtual_machines) :
      vm.load_balancer == null || contains(keys(var.load_balancers), coalesce(vm.load_balancer, "-"))
    ])
    error_message = "Every virtual_machines load_balancer must be a key in load_balancers."
  }
}

variable "virtual_machine_scale_sets" {
  description = "Linux or Windows Virtual Machine Scale Sets keyed by a stable logical name. Defaults to none; add one entry per scale set."
  type = map(object({
    size                          = optional(string, "Standard_B2s_v2")
    admin_username                = optional(string, "azureadmin")
    os_type                       = optional(string, "Linux")
    zones                         = optional(set(string), [])
    upgrade_mode                  = optional(string, "Manual")
    enable_accelerated_networking = optional(bool, false)
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }))
    os_disk = optional(object({
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "StandardSSD_LRS")
      disk_size_gb         = optional(number)
    }), {})
    data_disks = optional(map(object({
      lun                  = number
      disk_size_gb         = number
      storage_account_type = optional(string, "StandardSSD_LRS")
      caching              = optional(string, "ReadWrite")
    })), {})
    scaling = optional(object({
      mode              = optional(string, "fixed")
      minimum_instances = optional(number, 1)
      default_instances = optional(number, 2)
      maximum_instances = optional(number, 5)
      cpu = optional(object({
        scale_out_threshold = optional(number, 75)
        scale_in_threshold  = optional(number, 25)
        scale_out_count     = optional(number, 1)
        scale_in_count      = optional(number, 1)
        time_window_minutes = optional(number, 5)
        cooldown_minutes    = optional(number, 5)
      }), {})
    }), {})
    load_balancer                                = optional(string)
    load_balancer_backend_address_pool_ids       = optional(set(string), [])
    application_gateway_backend_address_pool_ids = optional(set(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.virtual_machine_scale_sets) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "virtual_machine_scale_sets keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for scale_set in values(var.virtual_machine_scale_sets) :
      scale_set.load_balancer == null || contains(keys(var.load_balancers), coalesce(scale_set.load_balancer, "-"))
    ])
    error_message = "Every virtual_machine_scale_sets load_balancer must be a key in load_balancers."
  }
}

variable "load_balancers" {
  description = "Internal Standard load balancers keyed by a stable logical name. Every frontend IP sits in the shared subnet_cidrs.load_balancers range, and each load balancer has one backend pool; VMs and scale sets join by setting load_balancer to the key. Defaults to none."
  type = map(object({
    private_ip_address = optional(string)
    zones              = optional(set(string), ["1", "2", "3"])
    probes = optional(map(object({
      protocol            = optional(string, "Tcp")
      port                = number
      request_path        = optional(string)
      interval_in_seconds = optional(number, 5)
      probe_threshold     = optional(number, 1)
    })), {})
    rules = optional(map(object({
      probe                   = string
      protocol                = optional(string, "Tcp")
      frontend_port           = number
      backend_port            = number
      idle_timeout_in_minutes = optional(number, 4)
      load_distribution       = optional(string, "Default")
      floating_ip_enabled     = optional(bool, false)
      tcp_reset_enabled       = optional(bool, true)
    })), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.load_balancers) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "load_balancers keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in values(var.load_balancers) : [
        for key in concat(keys(load_balancer.probes), keys(load_balancer.rules)) :
        can(regex("^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$", key)) && !strcontains(key, "--")
      ]
    ]))
    error_message = "Probe and rule keys must be 1-20 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition     = length(var.load_balancers) == 0 || var.subnet_cidrs.load_balancers != null
    error_message = "Set subnet_cidrs.load_balancers to the range shared by every load balancer frontend (/29 or larger)."
  }

  # Azure reserves the first four addresses and the last address of a subnet.
  validation {
    condition = var.subnet_cidrs.load_balancers == null || alltrue([
      for load_balancer in values(var.load_balancers) : load_balancer.private_ip_address == null ? true : try(
        can(regex("^(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])){3}$", load_balancer.private_ip_address)) &&
        sum([
          for index, octet in split(".", load_balancer.private_ip_address) :
          tonumber(octet) * pow(256, 3 - index)
          ]) >= sum([
          for index, octet in split(".", cidrhost(var.subnet_cidrs.load_balancers, 0)) :
          tonumber(octet) * pow(256, 3 - index)
        ]) + 4 &&
        sum([
          for index, octet in split(".", load_balancer.private_ip_address) :
          tonumber(octet) * pow(256, 3 - index)
          ]) <= sum([
          for index, octet in split(".", cidrhost(var.subnet_cidrs.load_balancers, 0)) :
          tonumber(octet) * pow(256, 3 - index)
        ]) + pow(2, 32 - tonumber(split("/", var.subnet_cidrs.load_balancers)[1])) - 2,
        false
      )
    ])
    error_message = "Every load_balancers private_ip_address must be a usable address in subnet_cidrs.load_balancers: not one of the first four addresses or the last address."
  }

  validation {
    condition = length(distinct([
      for load_balancer in values(var.load_balancers) : load_balancer.private_ip_address
      if load_balancer.private_ip_address != null
      ])) == length([
      for load_balancer in values(var.load_balancers) : load_balancer.private_ip_address
      if load_balancer.private_ip_address != null
    ])
    error_message = "Load balancers share one frontend subnet, so their static private_ip_address values must be unique."
  }
}

variable "nat_gateway" {
  description = "Shared outbound NAT Gateway settings for the VM, VMSS, and Container Apps subnets."
  type = object({
    idle_timeout_in_minutes = optional(number, 4)
  })
  default = {}
}

variable "container_registries" {
  description = "Private Premium Azure Container Registries keyed by a stable logical name. Defaults to none; add one entry per registry."
  type        = map(object({}))
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.container_registries) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "container_registries keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }
}

variable "key_vaults" {
  description = "RBAC-enabled Key Vaults keyed by a stable logical name. Defaults to none; add one entry per vault."
  type = map(object({
    sku_name                 = optional(string, "standard")
    purge_protection_enabled = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.key_vaults) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "key_vaults keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }
}

variable "storage_accounts" {
  description = "General-purpose v2 storage accounts keyed by a stable logical name. Defaults to none; add one entry per account."
  type = map(object({
    replication_type = optional(string, "LRS")
    containers       = optional(set(string), ["appdata", "archive"])
    file_shares = optional(map(object({
      quota_gb    = optional(number, 100)
      access_tier = optional(string, "TransactionOptimized")
    })), {})
    shared_access_key_enabled = optional(bool, false)
    data_plane_role_assignments = optional(map(object({
      principal_id                     = string
      role_definition_name             = string
      principal_type                   = optional(string)
      description                      = optional(string)
      skip_service_principal_aad_check = optional(bool, false)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.storage_accounts) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "storage_accounts keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }
}

variable "premium_file_accounts" {
  description = "Premium FileStorage accounts and SMB shares keyed by a stable logical account name. Defaults to none; add one entry per account."
  type = map(object({
    replication_type = optional(string, "LRS")
    file_shares = optional(map(object({
      quota_gb = optional(number, 100)
      })), {
      premium = {
        quota_gb = 100
      }
    })
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.premium_file_accounts) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "premium_file_accounts keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }
}

variable "azure_sql_servers" {
  description = "Azure SQL logical servers keyed by a stable logical name. Each server hosts one database, standalone or in an optional elastic pool. Defaults to none; add one entry per server."
  type = map(object({
    database_sku_name = optional(string, "Basic")
    max_size_gb       = optional(number, 2)
    elastic_pool = optional(object({
      enabled     = optional(bool, false)
      max_size_gb = optional(number, 4.8828125)
      sku = optional(object({
        name     = optional(string, "BasicPool")
        tier     = optional(string, "Basic")
        capacity = optional(number, 50)
        family   = optional(string)
      }), {})
      per_database_settings = optional(object({
        min_capacity = optional(number, 0)
        max_capacity = optional(number, 5)
      }), {})
      license_type   = optional(string)
      zone_redundant = optional(bool, false)
    }), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.azure_sql_servers) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "azure_sql_servers keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }
}

variable "container_apps_environments" {
  description = "Internal Container Apps environments keyed by a stable logical name. Each environment uses the subnet_cidrs.container_apps range with the same key as its own delegated subnet, and gets its own private DNS zone, optional dedicated workload profiles, and zero or more Container Apps. Defaults to none."
  type = map(object({
    dedicated_workload_profiles = optional(map(object({
      workload_profile_type = optional(string, "D4")
      minimum_count         = optional(number, 0)
      maximum_count         = optional(number, 3)
    })), {})
    apps = optional(map(object({
      image            = optional(string, "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest")
      target_port      = optional(number, 80)
      workload_profile = optional(string, "Consumption")
    })), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.container_apps_environments) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "container_apps_environments keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for key in keys(var.container_apps_environments) :
      contains(keys(var.subnet_cidrs.container_apps), key)
    ])
    error_message = "Every container_apps_environments key needs a subnet_cidrs.container_apps entry with the same key, for example subnet_cidrs = { container_apps = { primary = \"10.42.2.0/27\" } }."
  }

  validation {
    condition = alltrue(flatten([
      for environment in values(var.container_apps_environments) : [
        for app_key in keys(environment.apps) :
        can(regex("^[a-z]([a-z0-9-]{0,6}[a-z0-9])?$", app_key)) && !strcontains(app_key, "--")
      ]
    ]))
    error_message = "App keys must be 1-8 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens, so generated Container App names fit Azure's 32-character limit."
  }

  # App names are <prefix>-<app key>-<environment key>-<suffix>, so keys
  # containing hyphens could produce the same name in two environments.
  validation {
    condition = length(distinct(flatten([
      for environment_key, environment in var.container_apps_environments : [
        for app_key in keys(environment.apps) : "${app_key}-${environment_key}"
      ]
      ]))) == length(flatten([
      for environment in values(var.container_apps_environments) : keys(environment.apps)
    ]))
    error_message = "Every app key and environment key combination must produce a distinct Container App name; avoid pairs such as app a-b in environment c and app a in environment b-c."
  }
}

variable "cosmos_db_accounts" {
  description = "Cosmos DB accounts keyed by a stable logical name, each with its own classic API, throughput, and data-plane resources. Defaults to none; add one entry per account."
  type = map(object({
    api_type                      = optional(string, "NoSQL")
    consistency_level             = optional(string, "Session")
    local_authentication_disabled = optional(bool, false)
    throughput = optional(object({
      mode             = optional(string, "serverless")
      scope            = optional(string, "container")
      manual_ru        = optional(number, 400)
      autoscale_max_ru = optional(number, 1000)
    }), {})
    nosql_partition_key_paths = optional(list(string), ["/partitionKey"])
    mongodb = optional(object({
      server_version = optional(string, "4.2")
      shard_key      = optional(string, "partitionKey")
    }), {})
    cassandra_schema = optional(object({
      columns = optional(list(object({
        name = string
        type = string
        })), [
        {
          name = "partition_key"
          type = "text"
        },
        {
          name = "id"
          type = "text"
        },
        {
          name = "value"
          type = "text"
        }
      ])
      partition_keys = optional(list(string), ["partition_key"])
      cluster_keys = optional(list(object({
        name     = string
        order_by = optional(string, "Asc")
        })), [
        {
          name     = "id"
          order_by = "Asc"
        }
      ])
    }), {})
    gremlin_partition_key_path = optional(string, "/partitionKey")
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.cosmos_db_accounts) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "cosmos_db_accounts keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for account in values(var.cosmos_db_accounts) :
      contains(["NoSQL", "MongoDB", "Cassandra", "Gremlin", "Table"], account.api_type)
    ])
    error_message = "Every cosmos_db_accounts entry api_type must be NoSQL, MongoDB, Cassandra, Gremlin, or Table."
  }
}

variable "sql_managed_instance" {
  description = "Small SQL Managed Instance lab configuration."
  type = object({
    sku_name                    = optional(string, "GP_Gen5")
    vcores                      = optional(number, 4)
    storage_size_in_gb          = optional(number, 32)
    license_type                = optional(string, "LicenseIncluded")
    azuread_administrator_login = optional(string, "Terraform SQL MI Admin")
    azuread_administrator_type  = optional(string, "User")
  })
  default = {}
}

variable "postgresql_servers" {
  description = "PostgreSQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database and its own generated administrator password; all servers share the delegated postgresql subnet and the privatelink.postgres.database.azure.com zone. Defaults to none."
  type = map(object({
    administrator_login = optional(string, "pgadminuser")
    sku_name            = optional(string, "GP_Standard_D2ds_v5")
    version_number      = optional(string, "16")
    storage_mb          = optional(number, 32768)
    zone                = optional(string)
    high_availability = optional(object({
      enabled                   = optional(bool, false)
      mode                      = optional(string, "ZoneRedundant")
      standby_availability_zone = optional(string)
    }), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.postgresql_servers) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "postgresql_servers keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  # Azure's documented minimum for a PostgreSQL delegated subnet is /28.
  validation {
    condition     = length(var.postgresql_servers) == 0 || try(tonumber(split("/", var.subnet_cidrs.postgresql)[1]) <= 28, false)
    error_message = "subnet_cidrs.postgresql must be /28 or larger when postgresql_servers is non-empty."
  }

  # Azure documents four subnet addresses per high-availability server; a
  # non-HA server was measured in Azure to use one. Azure reserves five
  # addresses in every subnet.
  validation {
    condition = length(var.postgresql_servers) == 0 || try(
      sum([for server in values(var.postgresql_servers) : server.high_availability.enabled ? 4 : 1]) <=
      pow(2, 32 - tonumber(split("/", var.subnet_cidrs.postgresql)[1])) - 5,
      false
    )
    error_message = "subnet_cidrs.postgresql is too small for postgresql_servers: each server needs one address, or four with high availability, and Azure reserves five addresses per subnet."
  }
}

variable "mysql_servers" {
  description = "MySQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database and its own generated administrator password; all servers share the delegated mysql subnet and the privatelink.mysql.database.azure.com zone. Defaults to none."
  type = map(object({
    administrator_login = optional(string, "mysqladminuser")
    sku_name            = optional(string, "B_Standard_B1ms")
    version_number      = optional(string, "8.0.21")
    zone                = optional(string)
    high_availability = optional(object({
      enabled                   = optional(bool, false)
      mode                      = optional(string, "ZoneRedundant")
      standby_availability_zone = optional(string)
    }), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.mysql_servers) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "mysql_servers keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  # Each server takes one subnet address, or two with high availability; Azure
  # reserves five addresses in every subnet.
  validation {
    condition = length(var.mysql_servers) == 0 || try(
      sum([for server in values(var.mysql_servers) : server.high_availability.enabled ? 2 : 1]) <=
      pow(2, 32 - tonumber(split("/", var.subnet_cidrs.mysql)[1])) - 5,
      false
    )
    error_message = "subnet_cidrs.mysql is too small for mysql_servers: each server needs one address, or two with high availability, and Azure reserves five addresses per subnet."
  }
}

variable "function_app" {
  description = "Function App OS, Elastic Premium plan sizing, and language runtime."
  type = object({
    os_type               = optional(string, "Linux")
    service_plan_sku_name = optional(string, "EP1")
    runtime = optional(object({
      name    = optional(string, "python")
      version = optional(string, "3.11")
    }), {})
  })
  default = {}
}

variable "web_app" {
  description = "App Service Web App mode, plan, runtime, container image, and application settings."
  type = object({
    mode                  = optional(string, "linux")
    service_plan_sku_name = optional(string, "B1")
    runtime = optional(object({
      name    = optional(string, "node")
      version = optional(string, "22")
    }), {})
    container = optional(object({
      registry_url = optional(string, "https://mcr.microsoft.com")
      image_name   = optional(string, "appsvc/staticsite:latest")
      port         = optional(number, 80)
    }), {})
    app_settings = optional(map(string), {})
  })
  default = {}
}

variable "services" {
  description = "Single-instance services enabled in this lab composition. Every service is opt-in."
  type = object({
    sql_managed_instance = optional(bool, false)
    web_app              = optional(bool, false)
    function_app         = optional(bool, false)
  })
  default = {}
}

variable "tags" {
  description = "Additional tags merged with the required lab tags."
  type        = map(string)
  default     = {}
}
