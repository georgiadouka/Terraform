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
  description = "Azure region used by the lab. Must have a METLEN region code in the naming dictionary."
  type        = string
  default     = "swedencentral"

  validation {
    condition     = contains(keys(local.naming_dictionary.region_codes), lower(replace(var.location, " ", "")))
    error_message = "location has no approved METLEN region code. Add it to region_codes in locals.naming-dictionary.tf first."
  }
}

variable "naming_tokens" {
  description = "METLEN naming tokens: business unit (BU), department (DPT), application (APP) and environment (ENV). Each value must exist in locals.naming-dictionary.tf."
  type = object({
    business_unit = string
    department    = string
    application   = string
    environment   = string
  })

  validation {
    condition     = contains(local.naming_dictionary.business_units, var.naming_tokens.business_unit)
    error_message = "naming_tokens.business_unit is not an approved METLEN business unit code."
  }

  validation {
    condition     = contains(local.naming_dictionary.departments, var.naming_tokens.department)
    error_message = "naming_tokens.department is not an approved METLEN department code."
  }

  validation {
    condition     = contains(local.naming_dictionary.applications, var.naming_tokens.application)
    error_message = "naming_tokens.application is not an approved METLEN application code."
  }

  validation {
    condition     = contains(local.naming_dictionary.environments, var.naming_tokens.environment)
    error_message = "naming_tokens.environment must be DEV, UAT or PRD."
  }

  # Compact names are mazu + 3-character code + BU/DPT/APP + ENV (3) + REG (3)
  # + NN (2), so BU, DPT and APP together have 9 characters within the
  # 24-character Storage Account and Key Vault limit. The same budget keeps
  # Container App names within 32 characters and Function App names within the
  # 32 characters Azure uses for the Functions host ID.
  validation {
    condition = (
      length("${var.naming_tokens.business_unit}${var.naming_tokens.department}${var.naming_tokens.application}") <= 9
    )
    error_message = "naming_tokens business_unit, department and application together must be at most 9 characters so Storage Account and Key Vault names fit 24 characters and Container App and Function App names fit 32."
  }
}

variable "project_name" {
  description = "Legacy sample naming: short lowercase project name used by resources not yet migrated to the METLEN standard."
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
  description = "Legacy sample naming: environment label used by resources not yet migrated to the METLEN standard."
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
  description = "Legacy sample naming for resources and inner names that have no METLEN convention yet (VMs and scale sets with their NICs and disks, NAT Gateway and Public IP, VNet peerings, private DNS links, Log Analytics, SQL elastic pools, SQL Managed Instance, storage containers and file shares, subnet delegations, Container Apps containers and workload profiles). Names use <prefix>-<project>-<environment>-<suffix>."
  type = object({
    unique_suffix = optional(string)
    prefixes = optional(object({
      virtual_machine           = optional(string, "vm")
      virtual_machine_scale_set = optional(string, "vmss")
      network_interface         = optional(string, "nic")
      os_disk                   = optional(string, "osdisk")
      data_disk                 = optional(string, "disk")
      autoscale_setting         = optional(string, "autoscale")
      nat_gateway               = optional(string, "nat")
      public_ip                 = optional(string, "pip")
      virtual_network_peering   = optional(string, "peer")
      private_dns_link          = optional(string, "pdnslink")
      log_analytics_workspace   = optional(string, "log")
      azure_sql_elastic_pool    = optional(string, "sqlep")
      sql_managed_instance      = optional(string, "sqlmi")
      subnet_delegation         = optional(string, "dlg")
      storage_container         = optional(string, "blob")
      file_share                = optional(string, "share")
      container_app_container   = optional(string, "ctr")
      container_apps_profile    = optional(string, "wp")
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
  description = "Internal Standard load balancers keyed by a stable logical name. Every frontend IP sits in the shared subnet_cidrs.load_balancers range, and each load balancer has one backend pool; VMs and scale sets join by setting load_balancer to the key. Names follow M-AZU-LBL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per load balancer. Probe and rule names are their keys. Defaults to none."
  type = map(object({
    sequence           = optional(string, "00")
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
    condition     = alltrue([for load_balancer in values(var.load_balancers) : can(regex("^[0-9]{2}$", load_balancer.sequence))])
    error_message = "Every load_balancers sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for load_balancer in values(var.load_balancers) : load_balancer.sequence])) == length(var.load_balancers)
    error_message = "Every load_balancers entry needs a unique sequence because load balancer names must be unique. Current sequences: ${join(", ", [for key, load_balancer in var.load_balancers : "${key}=${load_balancer.sequence}"])}."
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

variable "network_security_groups" {
  description = "Network security groups keyed by a stable logical name. Defaults to none. subnets lists the subnet keys (for example virtual_machines or container_apps/primary) to associate; a subnet can belong to only one group. The SQL Managed Instance subnet is excluded because its module manages its own group. Rule names are the security_rules keys. Names follow M-AZU-NSG-<BU>-<DPT>-<APP>-<classification>-<ENV>-<REG>[-<sequence>]; set a unique two-digit sequence when more than one group shares a classification."
  type = map(object({
    classification = optional(string, "PRV")
    sequence       = optional(string)
    subnets        = optional(list(string), [])
    security_rules = optional(map(object({
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      description                  = optional(string)
      source_port_range            = optional(string)
      source_port_ranges           = optional(list(string))
      destination_port_range       = optional(string)
      destination_port_ranges      = optional(list(string))
      source_address_prefix        = optional(string)
      source_address_prefixes      = optional(list(string))
      destination_address_prefix   = optional(string)
      destination_address_prefixes = optional(list(string))
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.network_security_groups) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "network_security_groups keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for nsg in values(var.network_security_groups) :
      contains(local.naming_dictionary.network_classifications, nsg.classification) &&
      (nsg.sequence == null || can(regex("^[0-9]{2}$", nsg.sequence)))
    ])
    error_message = "Every network_security_groups entry needs classification PUB or PRV and, if set, a two-digit sequence such as 01."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for nsg in values(var.network_security_groups) : "${nsg.classification}-${coalesce(nsg.sequence, "none")}"],
        var.services.sql_managed_instance ? ["PRV-${coalesce(var.sql_managed_instance.network_sequence, "none")}"] : []
      ))) ==
      length(var.network_security_groups) + (var.services.sql_managed_instance ? 1 : 0)
    )
    error_message = "Network security group names must be unique: give each group with the same classification its own sequence (including sql_managed_instance.network_sequence when SQL Managed Instance is enabled)."
  }

  validation {
    condition = alltrue(flatten([
      for nsg in values(var.network_security_groups) : [
        for subnet_key in nsg.subnets :
        subnet_key != "sql_managed_instance" && contains(local.deployed_subnet_keys, subnet_key)
      ]
    ]))
    error_message = "Every network_security_groups subnets entry must be a deployed subnet key other than sql_managed_instance. Deployed subnet keys: ${join(", ", local.deployed_subnet_keys)}."
  }

  validation {
    condition = (
      length(flatten([for nsg in values(var.network_security_groups) : nsg.subnets])) ==
      length(distinct(flatten([for nsg in values(var.network_security_groups) : nsg.subnets])))
    )
    error_message = "A subnet can be listed only once across all network_security_groups entries."
  }
}

variable "route_tables" {
  description = "Route tables keyed by a stable logical name. Defaults to none. subnets lists the subnet keys (for example virtual_machines or container_apps/primary) to associate; a subnet can belong to only one table. The SQL Managed Instance subnet is excluded because its module manages its own table. Route names are the routes keys. A 0.0.0.0/0 route overrides NAT Gateway egress for its subnets. Names follow M-AZU-UDR-<BU>-<DPT>-<APP>-<classification>-<ENV>-<REG>[-<sequence>]; set a unique two-digit sequence when more than one table shares a classification."
  type = map(object({
    classification                = optional(string, "PRV")
    sequence                      = optional(string)
    subnets                       = optional(list(string), [])
    bgp_route_propagation_enabled = optional(bool, true)
    routes = optional(map(object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.route_tables) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "route_tables keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for route_table in values(var.route_tables) :
      contains(local.naming_dictionary.network_classifications, route_table.classification) &&
      (route_table.sequence == null || can(regex("^[0-9]{2}$", route_table.sequence)))
    ])
    error_message = "Every route_tables entry needs classification PUB or PRV and, if set, a two-digit sequence such as 01."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for route_table in values(var.route_tables) : "${route_table.classification}-${coalesce(route_table.sequence, "none")}"],
        var.services.sql_managed_instance ? ["PRV-${coalesce(var.sql_managed_instance.network_sequence, "none")}"] : []
      ))) ==
      length(var.route_tables) + (var.services.sql_managed_instance ? 1 : 0)
    )
    error_message = "Route table names must be unique: give each table with the same classification its own sequence (including sql_managed_instance.network_sequence when SQL Managed Instance is enabled)."
  }

  validation {
    condition = alltrue(flatten([
      for route_table in values(var.route_tables) : [
        for subnet_key in route_table.subnets :
        subnet_key != "sql_managed_instance" && contains(local.deployed_subnet_keys, subnet_key)
      ]
    ]))
    error_message = "Every route_tables subnets entry must be a deployed subnet key other than sql_managed_instance. Deployed subnet keys: ${join(", ", local.deployed_subnet_keys)}."
  }

  validation {
    condition = (
      length(flatten([for route_table in values(var.route_tables) : route_table.subnets])) ==
      length(distinct(flatten([for route_table in values(var.route_tables) : route_table.subnets])))
    )
    error_message = "A subnet can be listed only once across all route_tables entries."
  }
}

variable "hub_peering" {
  description = "Peers the lab VNet as a spoke to an existing hub VNet. Defaults to null (no peering). The spoke-to-hub side is always created; the hub-to-spoke side is created by default (create_hub_to_spoke_peering) through the azurerm.hub provider, whose subscription is read from hub_virtual_network_id. use_remote_gateways routes the spoke through the hub's VPN or ExpressRoute gateway and sets allow_gateway_transit on the hub side."
  type = object({
    hub_virtual_network_id      = string
    create_hub_to_spoke_peering = optional(bool, true)
    allow_forwarded_traffic     = optional(bool, true)
    use_remote_gateways         = optional(bool, false)
  })
  default = null

  validation {
    condition = (
      var.hub_peering == null ||
      can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.hub_peering.hub_virtual_network_id))
    )
    error_message = "hub_peering.hub_virtual_network_id must be a virtual network resource ID: /subscriptions/<id>/resourceGroups/<name>/providers/Microsoft.Network/virtualNetworks/<name>."
  }
}

variable "container_registries" {
  description = "Private Premium Azure Container Registries keyed by a stable logical name. Defaults to none; add one entry per registry. Names follow the compact family mazuacr<BU><DPT><APP><ENV><REG><sequence> (global, 5-50 lowercase letters and digits); sequence is the two-digit NN and must be unique per registry."
  type = map(object({
    sequence = optional(string, "00")
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.container_registries) :
      can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
      !strcontains(key, "--")
    ])
    error_message = "container_registries keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  }

  validation {
    condition     = alltrue([for registry in values(var.container_registries) : can(regex("^[0-9]{2}$", registry.sequence))])
    error_message = "Every container_registries sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for registry in values(var.container_registries) : registry.sequence])) == length(var.container_registries)
    error_message = "Every container_registries entry needs a unique sequence because registry names must be unique. Current sequences: ${join(", ", [for key, registry in var.container_registries : "${key}=${registry.sequence}"])}."
  }
}

variable "key_vaults" {
  description = "RBAC-enabled Key Vaults keyed by a stable logical name. Defaults to none; add one entry per vault. Names follow mazukva<BU><DPT><APP><ENV><REG><sequence>; sequence is the two-digit NN and must be unique per vault."
  type = map(object({
    sequence                 = optional(string, "00")
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

  validation {
    condition     = alltrue([for vault in values(var.key_vaults) : can(regex("^[0-9]{2}$", vault.sequence))])
    error_message = "Every key_vaults sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for vault in values(var.key_vaults) : vault.sequence])) == length(var.key_vaults)
    error_message = "Every key_vaults entry needs a unique sequence because Key Vault names must be unique. Current sequences: ${join(", ", [for key, vault in var.key_vaults : "${key}=${vault.sequence}"])}."
  }
}

variable "storage_accounts" {
  description = "General-purpose v2 storage accounts keyed by a stable logical name. Defaults to none; add one entry per account. Names follow mazusoa<BU><DPT><APP><ENV><REG><sequence>; sequence is the two-digit NN, shared with premium_file_accounts and the Function App host storage, and must be unique across them."
  type = map(object({
    sequence         = optional(string, "00")
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

  validation {
    condition     = alltrue([for account in values(var.storage_accounts) : can(regex("^[0-9]{2}$", account.sequence))])
    error_message = "Every storage_accounts sequence must be two digits, for example 00."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for account in values(var.storage_accounts) : account.sequence],
        [for account in values(var.premium_file_accounts) : account.sequence],
        var.services.function_app ? [var.function_app.storage_sequence] : []
      ))) ==
      length(var.storage_accounts) + length(var.premium_file_accounts) + (var.services.function_app ? 1 : 0)
    )
    error_message = "Storage Account names must be unique, so every storage_accounts, premium_file_accounts and function_app.storage_sequence value must differ. Current sequences: ${join(", ", concat(
      [for key, account in var.storage_accounts : "storage_accounts.${key}=${account.sequence}"],
      [for key, account in var.premium_file_accounts : "premium_file_accounts.${key}=${account.sequence}"],
      var.services.function_app ? ["function_app.storage_sequence=${var.function_app.storage_sequence}"] : []
    ))}."
  }
}

variable "premium_file_accounts" {
  description = "Premium FileStorage accounts and SMB shares keyed by a stable logical account name. Defaults to none; add one entry per account. Names follow the Storage Account family; sequence must be unique across all storage accounts."
  type = map(object({
    sequence         = optional(string, "00")
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

  validation {
    condition     = alltrue([for account in values(var.premium_file_accounts) : can(regex("^[0-9]{2}$", account.sequence))])
    error_message = "Every premium_file_accounts sequence must be two digits, for example 01."
  }
}

variable "azure_sql_servers" {
  description = "Azure SQL logical servers keyed by a stable logical name. Each server hosts one database, standalone or in an optional elastic pool. Defaults to none; add one entry per server. Server names follow m-azu-sql-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> and database names M-AZU-SQL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per server."
  type = map(object({
    sequence          = optional(string, "00")
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

  validation {
    condition     = alltrue([for server in values(var.azure_sql_servers) : can(regex("^[0-9]{2}$", server.sequence))])
    error_message = "Every azure_sql_servers sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for server in values(var.azure_sql_servers) : server.sequence])) == length(var.azure_sql_servers)
    error_message = "Every azure_sql_servers entry needs a unique sequence because SQL server names must be unique. Current sequences: ${join(", ", [for key, server in var.azure_sql_servers : "${key}=${server.sequence}"])}."
  }
}

variable "container_apps_environments" {
  description = "Internal Container Apps environments keyed by a stable logical name. Each environment uses the subnet_cidrs.container_apps range with the same key as its own delegated subnet, and gets its own private DNS zone, optional dedicated workload profiles, and zero or more Container Apps. subnet_number is the two-digit NN in the METLEN subnet name <DPT><APP><ENV>PRV<NN> (1-99, unique, and not used by another deployed subnet). Environment names follow M-AZU-CEV-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence> and app names m-azu-cap-<bu>-<dpt>-<app>-<env>-<reg>-<sequence>; environment sequences must be unique, and app sequences unique across every environment because Container App names are unique per resource group. Defaults to none."
  type = map(object({
    sequence      = optional(string, "00")
    subnet_number = optional(number, 9)
    dedicated_workload_profiles = optional(map(object({
      workload_profile_type = optional(string, "D4")
      minimum_count         = optional(number, 0)
      maximum_count         = optional(number, 3)
    })), {})
    apps = optional(map(object({
      sequence         = optional(string, "00")
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
      for environment in values(var.container_apps_environments) :
      environment.subnet_number >= 1 && environment.subnet_number <= 99 && floor(environment.subnet_number) == environment.subnet_number
    ])
    error_message = "container_apps_environments subnet_number must be a whole number from 1 to 99 (the two-digit NN of the METLEN subnet name)."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for environment in values(var.container_apps_environments) : environment.subnet_number],
        [for subnet_key, enabled in local.subnet_enabled : local.subnet_numbers[subnet_key] if enabled]
      ))) ==
      length(var.container_apps_environments) + length([for enabled in values(local.subnet_enabled) : enabled if enabled])
    )
    error_message = "Every container_apps_environments subnet_number must be unique and must not reuse the number of another deployed subnet (${join(", ", [for subnet_key, enabled in local.subnet_enabled : "${subnet_key}=${local.subnet_numbers[subnet_key]}" if enabled])})."
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
        can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", app_key)) && !strcontains(app_key, "--")
      ]
    ]))
    error_message = "App keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue(concat(
      [for environment in values(var.container_apps_environments) : can(regex("^[0-9]{2}$", environment.sequence))],
      flatten([for environment in values(var.container_apps_environments) : [for app in values(environment.apps) : can(regex("^[0-9]{2}$", app.sequence))]])
    ))
    error_message = "Every Container Apps environment and app sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for environment in values(var.container_apps_environments) : environment.sequence])) == length(var.container_apps_environments)
    error_message = "Every container_apps_environments entry needs a unique sequence because environment names must be unique. Current sequences: ${join(", ", [for key, environment in var.container_apps_environments : "${key}=${environment.sequence}"])}."
  }

  validation {
    condition = (
      length(distinct(flatten([for environment in values(var.container_apps_environments) : [for app in values(environment.apps) : app.sequence]]))) ==
      length(flatten([for environment in values(var.container_apps_environments) : keys(environment.apps)]))
    )
    error_message = "Container App names are unique per resource group, so every app sequence must be unique across all environments. Current sequences: ${join(", ", flatten([for environment_key, environment in var.container_apps_environments : [for app_key, app in environment.apps : "${environment_key}/${app_key}=${app.sequence}"]]))}."
  }
}

variable "cosmos_db_accounts" {
  description = "Cosmos DB accounts keyed by a stable logical name, each with its own classic API, throughput, and data-plane resources. Defaults to none; add one entry per account. Account names follow m-azu-cdb-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase); the database and container use the compact family mazucdb<BU><DPT><APP><ENV><REG><sequence>, valid for every API. sequence is the two-digit NN and must be unique per account."
  type = map(object({
    sequence                      = optional(string, "00")
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
    condition     = alltrue([for account in values(var.cosmos_db_accounts) : can(regex("^[0-9]{2}$", account.sequence))])
    error_message = "Every cosmos_db_accounts sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for account in values(var.cosmos_db_accounts) : account.sequence])) == length(var.cosmos_db_accounts)
    error_message = "Every cosmos_db_accounts entry needs a unique sequence because Cosmos DB account names must be unique. Current sequences: ${join(", ", [for key, account in var.cosmos_db_accounts : "${key}=${account.sequence}"])}."
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
  description = "Small SQL Managed Instance lab configuration. network_sequence is the optional two-digit NN of the instance's own NSG and route table; set it when another group or table already uses the name without a sequence."
  type = object({
    sku_name                    = optional(string, "GP_Gen5")
    vcores                      = optional(number, 4)
    storage_size_in_gb          = optional(number, 32)
    license_type                = optional(string, "LicenseIncluded")
    azuread_administrator_login = optional(string, "Terraform SQL MI Admin")
    azuread_administrator_type  = optional(string, "User")
    network_sequence            = optional(string)
  })
  default = {}

  validation {
    condition     = var.sql_managed_instance.network_sequence == null || can(regex("^[0-9]{2}$", var.sql_managed_instance.network_sequence))
    error_message = "sql_managed_instance.network_sequence must be null or a two-digit sequence such as 01."
  }
}

variable "postgresql_servers" {
  description = "PostgreSQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database and its own generated administrator password; all servers share the delegated postgresql subnet and the privatelink.postgres.database.azure.com zone. Server names follow m-azu-pgs-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase) and database names M-AZU-PGS-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per server. Defaults to none."
  type = map(object({
    sequence            = optional(string, "00")
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

  validation {
    condition     = alltrue([for server in values(var.postgresql_servers) : can(regex("^[0-9]{2}$", server.sequence))])
    error_message = "Every postgresql_servers sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for server in values(var.postgresql_servers) : server.sequence])) == length(var.postgresql_servers)
    error_message = "Every postgresql_servers entry needs a unique sequence because PostgreSQL server names must be unique. Current sequences: ${join(", ", [for key, server in var.postgresql_servers : "${key}=${server.sequence}"])}."
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
  description = "MySQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database and its own generated administrator password; all servers share the delegated mysql subnet and the privatelink.mysql.database.azure.com zone. Server names follow m-azu-mys-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase) and database names the same lowercase name, because MySQL stores database names in lowercase; sequence is the two-digit NN and must be unique per server. Defaults to none."
  type = map(object({
    sequence            = optional(string, "00")
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

  validation {
    condition     = alltrue([for server in values(var.mysql_servers) : can(regex("^[0-9]{2}$", server.sequence))])
    error_message = "Every mysql_servers sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for server in values(var.mysql_servers) : server.sequence])) == length(var.mysql_servers)
    error_message = "Every mysql_servers entry needs a unique sequence because MySQL server names must be unique. Current sequences: ${join(", ", [for key, server in var.mysql_servers : "${key}=${server.sequence}"])}."
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
  description = "Function App OS, Elastic Premium plan sizing, language runtime, the optional two-digit NN of the Function App name (sequence; the standard defines no NN, so leave null unless the global name is taken), and the NN of its App Service Plan (service_plan_sequence, unique across App Service Plans) and host Storage Account (storage_sequence, unique across all storage accounts)."
  type = object({
    os_type               = optional(string, "Linux")
    service_plan_sku_name = optional(string, "EP1")
    sequence              = optional(string)
    service_plan_sequence = optional(string, "00")
    storage_sequence      = optional(string, "00")
    runtime = optional(object({
      name    = optional(string, "python")
      version = optional(string, "3.11")
    }), {})
  })
  default = {}

  validation {
    condition = (
      can(regex("^[0-9]{2}$", var.function_app.storage_sequence)) &&
      can(regex("^[0-9]{2}$", var.function_app.service_plan_sequence)) &&
      (var.function_app.sequence == null || can(regex("^[0-9]{2}$", var.function_app.sequence)))
    )
    error_message = "function_app.storage_sequence and function_app.service_plan_sequence must be two digits, for example 01, and function_app.sequence null or two digits."
  }

  validation {
    condition = (
      !(var.services.function_app && var.services.web_app) ||
      var.function_app.service_plan_sequence != var.web_app.service_plan_sequence
    )
    error_message = "The Web App and Function App plans share the App Service Plan name family, so function_app.service_plan_sequence must differ from web_app.service_plan_sequence."
  }
}

variable "web_app" {
  description = "App Service Web App mode, plan, runtime, container image, and application settings. sequence is the two-digit NN of the Web App name and service_plan_sequence that of its App Service Plan."
  type = object({
    sequence              = optional(string, "00")
    service_plan_sequence = optional(string, "00")
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

  validation {
    condition     = can(regex("^[0-9]{2}$", var.web_app.sequence)) && can(regex("^[0-9]{2}$", var.web_app.service_plan_sequence))
    error_message = "web_app.sequence and web_app.service_plan_sequence must be two digits, for example 00."
  }
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
