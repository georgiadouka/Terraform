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
    error_message = "naming.prefixes.container_app must be no more than four characters so generated Container App names remain within Azure's 32-character limit."
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
  description = "CIDR prefix assigned to each lab subnet."
  type = object({
    private_endpoints    = string
    virtual_machines     = string
    container_apps       = string
    web_app_integration  = optional(string, "10.42.8.0/26")
    function_integration = string
    postgresql           = string
    mysql                = string
    sql_managed_instance = string
  })
  default = {
    private_endpoints    = "10.42.0.0/24"
    virtual_machines     = "10.42.1.0/24"
    container_apps       = "10.42.2.0/23"
    web_app_integration  = "10.42.8.0/26"
    function_integration = "10.42.4.0/24"
    postgresql           = "10.42.5.0/24"
    mysql                = "10.42.6.0/24"
    sql_managed_instance = "10.42.7.0/27"
  }

  validation {
    condition = alltrue([
      for prefix in values(var.subnet_cidrs) :
      can(cidrnetmask(prefix)) &&
      can(cidrhost(prefix, 0)) &&
      try(cidrhost(prefix, 0) == split("/", prefix)[0], false)
    ])
    error_message = "Every subnet_cidrs value must be a valid IPv4 CIDR written with its network address."
  }

  validation {
    condition     = can(tonumber(split("/", var.subnet_cidrs.container_apps)[1])) && tonumber(split("/", var.subnet_cidrs.container_apps)[1]) <= 23
    error_message = "The Container Apps subnet must be /23 or larger."
  }

  validation {
    condition     = can(tonumber(split("/", var.subnet_cidrs.sql_managed_instance)[1])) && tonumber(split("/", var.subnet_cidrs.sql_managed_instance)[1]) <= 27
    error_message = "The future SQL Managed Instance subnet must be /27 or larger."
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

variable "container_apps" {
  description = "Container Apps environment and workload profile configuration."
  type = object({
    image       = optional(string, "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest")
    target_port = optional(number, 80)
    dedicated_workload_profiles = optional(map(object({
      workload_profile_type = optional(string, "D4")
      minimum_count         = optional(number, 0)
      maximum_count         = optional(number, 3)
    })), {})
    app_workload_profile = optional(string)
  })
  default = {}
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

variable "postgresql" {
  description = "PostgreSQL Flexible Server version, compute, and storage settings."
  type = object({
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
  })
  default = {}
}

variable "mysql" {
  description = "MySQL Flexible Server version and compute settings."
  type = object({
    administrator_login = optional(string, "mysqladminuser")
    sku_name            = optional(string, "B_Standard_B1ms")
    version_number      = optional(string, "8.0.21")
    zone                = optional(string)
    high_availability = optional(object({
      enabled                   = optional(bool, false)
      mode                      = optional(string, "ZoneRedundant")
      standby_availability_zone = optional(string)
    }), {})
  })
  default = {}
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
    postgresql           = optional(bool, false)
    mysql                = optional(bool, false)
    container_apps       = optional(bool, false)
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
