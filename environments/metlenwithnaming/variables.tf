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
  description = "Legacy sample naming for resources and inner names that have no METLEN convention yet (VMs and scale sets with their NICs and disks, subnet delegations, Container Apps containers and workload profiles). Names use <prefix>-<project>-<environment>-<suffix>."
  type = object({
    unique_suffix = optional(string)
    prefixes = optional(object({
      virtual_machine           = optional(string, "vm")
      virtual_machine_scale_set = optional(string, "vmss")
      network_interface         = optional(string, "nic")
      os_disk                   = optional(string, "osdisk")
      data_disk                 = optional(string, "disk")
      autoscale_setting         = optional(string, "autoscale")
      subnet_delegation         = optional(string, "dlg")
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

variable "virtual_networks" {
  description = "Virtual networks keyed by a stable logical name (the key never appears in Azure names). classification is the METLEN network intent, PRV (default) or PUB; it names the VNet M-AZU-VNT-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG>, its subnets <DPT><APP><ENV><PUB|PRV><NN>, its NAT Gateway and, by default, the NSGs and route tables its subnets use. The standard defines no NN for VNets, so each classification can be used by one VNet only (at most one PRV and one PUB). subnets lists every subnet of the VNet, and every listed subnet is created whether or not anything uses it, so adding or removing a workload never adds or removes a subnet. The subnet key is its role: private_endpoints, virtual_machines, web_app_integration, function_integration, logic_app_integration, postgresql, mysql, sql_managed_instance, load_balancers, container_apps/<container_apps_environments key> or databricks/<databricks_workspaces key>/<host|container>; the role sets the delegation and the minimum size. number is the two-digit NN in the subnet name <DPT><APP><ENV><PUB|PRV><NN> (1-99, unique within the VNet); keep it stable, because changing it renames, and therefore replaces, the subnet. On each subnet, network_security_group and route_table name a network_security_groups or route_tables key and nat_gateway = true sends its outbound traffic through the VNet's NAT Gateway, which is created (with nat_gateway settings) only when a subnet uses it. A Container Apps environment or Databricks workspace is placed in the VNet that lists its subnets; every other networked resource selects its VNet with virtual_network and defaults to the PRV VNet (or the only VNet)."
  type = map(object({
    classification = optional(string, "PRV")
    address_space  = list(string)
    nat_gateway = optional(object({
      sequence                = optional(string, "00")
      idle_timeout_in_minutes = optional(number, 4)
    }), {})
    subnets = optional(map(object({
      cidr                   = string
      number                 = number
      network_security_group = optional(string)
      route_table            = optional(string)
      nat_gateway            = optional(bool, false)
    })), {})
  }))
  default = {
    main = {
      address_space = ["10.42.0.0/20"]
    }
  }
  nullable = false

  validation {
    condition = length(var.virtual_networks) > 0 && alltrue([
      for key in keys(var.virtual_networks) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "virtual_networks needs at least one entry, and its keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = (
      alltrue([for network in values(var.virtual_networks) : contains(local.naming_dictionary.network_classifications, network.classification)]) &&
      length(distinct([for network in values(var.virtual_networks) : network.classification])) == length(var.virtual_networks)
    )
    error_message = "Every virtual_networks classification must be PUB or PRV, and each classification can be used by one virtual network only: the METLEN name M-AZU-VNT-<BU>-<DPT>-<APP>-<PUB|PRV>-<ENV>-<REG> has no NN, so two VNets with the same classification would get the same name. Current classifications: ${join(", ", [for key, network in var.virtual_networks : "${key}=${network.classification}"])}."
  }

  validation {
    condition = alltrue([
      for network in values(var.virtual_networks) :
      length(network.address_space) > 0 && alltrue([
        for prefix in network.address_space :
        can(cidrnetmask(prefix)) &&
        can(cidrhost(prefix, 0)) &&
        try(cidrhost(prefix, 0) == split("/", prefix)[0], false)
      ])
    ])
    error_message = "Every virtual_networks address_space must contain at least one valid IPv4 CIDR written with its network address."
  }

  validation {
    condition     = alltrue([for network in values(var.virtual_networks) : can(regex("^[0-9]{2}$", network.nat_gateway.sequence))])
    error_message = "Every virtual_networks nat_gateway.sequence must be two digits, for example 00."
  }

  # Container Apps and Databricks keys follow the key rules of their
  # variables, so the subnet can match the environment or workspace.
  validation {
    condition = alltrue(flatten([
      for network in values(var.virtual_networks) : [
        for subnet_key in keys(network.subnets) : (
          can(regex("^(private_endpoints|virtual_machines|web_app_integration|function_integration|logic_app_integration|postgresql|mysql|sql_managed_instance|load_balancers)$", subnet_key)) ||
          can(regex("^container_apps/[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", subnet_key)) && !strcontains(subnet_key, "--") ||
          can(regex("^databricks/[a-z]([a-z0-9-]{0,10}[a-z0-9])?/(host|container)$", subnet_key)) && !strcontains(subnet_key, "--")
        )
      ]
    ]))
    error_message = "Every virtual_networks subnets key must be a subnet role (private_endpoints, virtual_machines, web_app_integration, function_integration, logic_app_integration, postgresql, mysql, sql_managed_instance or load_balancers), container_apps/<environment key> or databricks/<workspace key>/<host|container>, where the environment and workspace keys follow the container_apps_environments and databricks_workspaces key rules. Current keys: ${join("; ", [for key, network in var.virtual_networks : "${key}: ${join(", ", keys(network.subnets))}"])}."
  }

  validation {
    condition = alltrue(flatten([
      for network in values(var.virtual_networks) : [
        for subnet in values(network.subnets) :
        can(cidrnetmask(subnet.cidr)) &&
        can(cidrhost(subnet.cidr, 0)) &&
        try(cidrhost(subnet.cidr, 0) == split("/", subnet.cidr)[0], false)
      ]
    ]))
    error_message = "Every virtual_networks subnets cidr must be a valid IPv4 CIDR written with its network address."
  }

  # The subnet role is derived inline, as in local.subnet_roles: a validation
  # cannot read a local built from its own variable (dependency cycle).
  validation {
    condition = alltrue(flatten([
      for network_key, network in var.virtual_networks : [
        for subnet_key, subnet in network.subnets : try(
          tonumber(split("/", subnet.cidr)[1]) <= lookup(local.subnet_maximum_prefix_lengths, startswith(subnet_key, "container_apps/") ? "container_apps" : startswith(subnet_key, "databricks/") ? "databricks_${element(split("/", subnet_key), 2)}" : subnet_key, 29),
          true
        )
      ]
    ]))
    error_message = "These subnets are too small (Azure needs /29 or larger for every subnet, /27 for sql_managed_instance and container_apps/<key>, /28 for databricks/<key>/<host|container>): ${join(", ", flatten([
      for network_key, network in var.virtual_networks : [
        for subnet_key, subnet in network.subnets : "${network_key}/${subnet_key}=${subnet.cidr}"
        if !try(tonumber(split("/", subnet.cidr)[1]) <= lookup(local.subnet_maximum_prefix_lengths, startswith(subnet_key, "container_apps/") ? "container_apps" : startswith(subnet_key, "databricks/") ? "databricks_${element(split("/", subnet_key), 2)}" : subnet_key, 29), true)
      ]
    ]))}."
  }

  validation {
    condition = alltrue(flatten([
      for network in values(var.virtual_networks) : [
        for subnet in values(network.subnets) :
        subnet.number >= 1 && subnet.number <= 99 && floor(subnet.number) == subnet.number
      ]
    ]))
    error_message = "Every virtual_networks subnets number must be a whole number from 1 to 99 (the two-digit NN of the METLEN subnet name)."
  }

  # Subnet names are scoped to their VNet, so numbers only need to be unique
  # within one VNet.
  validation {
    condition = alltrue([
      for network in values(var.virtual_networks) :
      length(distinct([for subnet_key, subnet in network.subnets : subnet.number])) == length(network.subnets)
    ])
    error_message = "Every subnet number (the NN of its name) must be unique within its virtual network. Numbers per VNet: ${join("; ", [for network_key, network in var.virtual_networks : "${network_key}: ${join(", ", [for subnet_key, subnet in network.subnets : "${subnet_key}=${subnet.number}"])}"])}."
  }

  # The subnet key places the environment or workspace, so it can appear in
  # one VNet only, and a workspace's two subnets share that VNet.
  validation {
    condition = (
      length(flatten([for network in values(var.virtual_networks) : [for subnet_key in keys(network.subnets) : subnet_key if strcontains(subnet_key, "/")]])) ==
      length(distinct(flatten([for network in values(var.virtual_networks) : [for subnet_key in keys(network.subnets) : subnet_key if strcontains(subnet_key, "/")]]))) &&
      alltrue(flatten([
        for network in values(var.virtual_networks) : [
          for subnet_key in keys(network.subnets) : try(
            contains(keys(network.subnets), "databricks/${split("/", subnet_key)[1]}/host") &&
            contains(keys(network.subnets), "databricks/${split("/", subnet_key)[1]}/container"),
            false
          )
          if startswith(subnet_key, "databricks/")
        ]
      ]))
    )
    error_message = "A container_apps/<key> or databricks/<key>/<host|container> subnet can appear in one virtual network only, because it places that environment or workspace in the VNet, and every Databricks workspace needs both its host and container subnet in the same virtual network."
  }

  # The SQL Managed Instance module attaches its own NSG and route table, and
  # the Databricks module its own NSG.
  validation {
    condition = alltrue(flatten([
      for network in values(var.virtual_networks) : concat(
        [
          for subnet_key, subnet in network.subnets :
          subnet.network_security_group == null && subnet.route_table == null && !subnet.nat_gateway
          if subnet_key == "sql_managed_instance"
        ],
        [
          for subnet_key, subnet in network.subnets :
          subnet.network_security_group == null
          if startswith(subnet_key, "databricks/")
        ]
      )
    ]))
    error_message = "The sql_managed_instance subnet cannot set network_security_group, route_table or nat_gateway, and databricks/<key>/<host|container> subnets cannot set network_security_group: their modules attach their own."
  }
}

variable "virtual_network_peerings" {
  description = "Peerings between virtual_networks entries, keyed by a stable label that never appears in Azure names. Each entry peers the two listed VNets in both directions; each side is named <local VNet name>-to-<remote VNet name>. allow_forwarded_traffic accepts traffic forwarded by an NVA in the other VNet. Peered address spaces must not overlap. Defaults to none."
  type = map(object({
    virtual_networks        = list(string)
    allow_forwarded_traffic = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for peering in values(var.virtual_network_peerings) :
      length(peering.virtual_networks) == 2 &&
      length(distinct(peering.virtual_networks)) == 2 &&
      alltrue([for key in peering.virtual_networks : contains(keys(var.virtual_networks), key)])
    ])
    error_message = "Every virtual_network_peerings entry must list two different virtual_networks keys. Available keys: ${join(", ", keys(var.virtual_networks))}."
  }

  validation {
    condition = (
      length(distinct([for peering in values(var.virtual_network_peerings) : join("/", sort(peering.virtual_networks))])) ==
      length(var.virtual_network_peerings)
    )
    error_message = "Each pair of virtual networks can be peered only once in virtual_network_peerings."
  }

  validation {
    condition = alltrue(flatten([
      for peering in values(var.virtual_network_peerings) : [
        for first in try(local.virtual_network_address_ranges[peering.virtual_networks[0]], []) : [
          for second in try(local.virtual_network_address_ranges[peering.virtual_networks[1]], []) :
          first.end < second.start || second.end < first.start
        ]
      ]
    ]))
    error_message = "Peered virtual networks must not have overlapping address spaces."
  }
}

# Lab approach: one known initial password per resource type, set outside git
# (git-ignored tfvars or TF_VAR_* pipeline secret) and changed by users after
# first sign-in. Production should use generated passwords stored in Key Vault.
variable "vm_admin_password" {
  description = "Initial administrator password shared by every VM and scale set (Windows and Linux; Linux SSH keys are not used). Required when virtual_machines or virtual_machine_scale_sets is non-empty. Set it in a git-ignored tfvars file or as TF_VAR_vm_admin_password, never in a committed file. Users change it after first sign-in; Terraform ignores later changes to this value for existing machines. 12-72 characters with at least three of lower case, upper case, digits and special characters."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = (
      length(var.virtual_machines) + length(var.virtual_machine_scale_sets) == 0 ||
      var.vm_admin_password != null
    )
    error_message = "vm_admin_password is required when virtual_machines or virtual_machine_scale_sets is non-empty. Set it in a git-ignored tfvars file or as TF_VAR_vm_admin_password."
  }

  validation {
    condition = var.vm_admin_password == null || (
      length(var.vm_admin_password) >= 12 &&
      length(var.vm_admin_password) <= 72 &&
      length([for pattern in ["[a-z]", "[A-Z]", "[0-9]", "[^a-zA-Z0-9]"] : pattern if can(regex(pattern, var.vm_admin_password))]) >= 3
    )
    error_message = "vm_admin_password must be 12-72 characters (Linux allows at most 72) with at least three of: lower case, upper case, digits, special characters."
  }
}

variable "database_admin_password" {
  description = "Initial administrator password shared by every PostgreSQL and MySQL Flexible Server. Required when postgresql_servers or mysql_servers is non-empty. Set it in a git-ignored tfvars file or as TF_VAR_database_admin_password, never in a committed file. 12-128 characters with at least three of lower case, upper case, digits and special characters. Azure SQL and SQL Managed Instance use Entra ID only and need no password."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = (
      length(var.postgresql_servers) + length(var.mysql_servers) == 0 ||
      var.database_admin_password != null
    )
    error_message = "database_admin_password is required when postgresql_servers or mysql_servers is non-empty. Set it in a git-ignored tfvars file or as TF_VAR_database_admin_password."
  }

  validation {
    condition = var.database_admin_password == null || (
      length(var.database_admin_password) >= 12 &&
      length(var.database_admin_password) <= 128 &&
      length([for pattern in ["[a-z]", "[A-Z]", "[0-9]", "[^a-zA-Z0-9]"] : pattern if can(regex(pattern, var.database_admin_password))]) >= 3
    )
    error_message = "database_admin_password must be 12-128 characters with at least three of: lower case, upper case, digits, special characters."
  }
}

variable "virtual_machines" {
  description = "Linux or Windows virtual machines keyed by a stable logical name. Defaults to none; add one entry per VM. Every VM signs in with admin_username and the shared vm_admin_password (Linux VMs use password sign-in, no SSH keys). virtual_network selects the VNet whose virtual_machines subnet the VM joins (default: the PRV VNet). Every VM is backed up to the shared Recovery Services vault with backup_policy (a vm_backup.policies key, default \"default\"); set backup = false to opt a VM out."
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
    load_balancer   = optional(string)
    virtual_network = optional(string)
    backup          = optional(bool, true)
    backup_policy   = optional(string, "default")
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
      !var.vm_backup.enabled || !vm.backup || contains(keys(var.vm_backup.policies), vm.backup_policy)
    ])
    error_message = "Every backed-up virtual_machines entry needs a backup_policy (default \"default\") that is a vm_backup.policies key, or backup = false. Policies: ${join(", ", keys(var.vm_backup.policies))}. VMs: ${join(", ", [for key, vm in var.virtual_machines : "${key}=${vm.backup ? vm.backup_policy : "no backup"}"])}."
  }

  validation {
    condition = alltrue([
      for vm in values(var.virtual_machines) :
      vm.load_balancer == null || contains(keys(var.load_balancers), coalesce(vm.load_balancer, "-"))
    ])
    error_message = "Every virtual_machines load_balancer must be a key in load_balancers."
  }

  validation {
    condition = alltrue([
      for vm in values(var.virtual_machines) :
      try(contains(keys(var.virtual_networks[coalesce(vm.virtual_network, local.default_virtual_network)].subnets), "virtual_machines"), false)
    ])
    error_message = "Every virtual_machines virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list virtual_machines. VMs per VNet: ${join(", ", [for key, vm in var.virtual_machines : "${key}=${coalesce(vm.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  # A load balancer reaches only backends in its own VNet.
  validation {
    condition = alltrue([
      for vm in values(var.virtual_machines) :
      vm.load_balancer == null || try(
        coalesce(var.load_balancers[vm.load_balancer].virtual_network, local.default_virtual_network) == coalesce(vm.virtual_network, local.default_virtual_network),
        true
      )
    ])
    error_message = "Every virtual_machines entry with a load_balancer must be in the same virtual_network as that load balancer."
  }
}

variable "vm_backup" {
  description = "Azure Backup for virtual_machines entries. One Recovery Services vault, M-AZU-RSV-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence> (sequence is the two-digit NN), is created when at least one VM is backed up; every VM is, unless it sets backup = false. enabled = false turns backup off for every VM. policies are Enhanced (V2) VM backup policies keyed by a stable name that is also the policy name in the vault (the only policy type that protects the Trusted Launch VMs this environment creates); VMs select one with backup_policy, default \"default\". The default policy backs up daily at 23:00 UTC, keeps instant-restore snapshots 7 days and daily recovery points 30 days. storage_mode_type is ZoneRedundant (default), GeoRedundant or LocallyRedundant, and Azure rejects a change once a VM is protected; cross_region_restore_enabled needs GeoRedundant. public_network_access_enabled defaults to false: VM backup and full-VM restore still work, file-level restore needs public access. immutability is Disabled, Unlocked or Locked (Locked cannot be undone). Soft delete is always on, so deleted backup data stays recoverable for 14 days."
  type = object({
    enabled                       = optional(bool, true)
    sequence                      = optional(string, "00")
    storage_mode_type             = optional(string, "ZoneRedundant")
    cross_region_restore_enabled  = optional(bool, false)
    public_network_access_enabled = optional(bool, false)
    immutability                  = optional(string)
    policies = optional(map(object({
      timezone                       = optional(string, "UTC")
      frequency                      = optional(string, "Daily")
      time                           = optional(string, "23:00")
      hour_interval                  = optional(number)
      hour_duration                  = optional(number)
      weekdays                       = optional(list(string), [])
      instant_restore_retention_days = optional(number)
      retention_daily                = optional(number)
      retention_weekly = optional(object({
        count    = number
        weekdays = list(string)
      }))
      retention_monthly = optional(object({
        count             = number
        weekdays          = optional(list(string), [])
        weeks             = optional(list(string), [])
        days              = optional(list(number), [])
        include_last_days = optional(bool, false)
      }))
      retention_yearly = optional(object({
        count             = number
        months            = list(string)
        weekdays          = optional(list(string), [])
        weeks             = optional(list(string), [])
        days              = optional(list(number), [])
        include_last_days = optional(bool, false)
      }))
    })), { default = {} })
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(regex("^[0-9]{2}$", var.vm_backup.sequence))
    error_message = "vm_backup.sequence must be two digits, for example 00."
  }

  validation {
    condition = length(var.vm_backup.policies) > 0 && alltrue([
      for key in keys(var.vm_backup.policies) :
      can(regex("^[a-z][a-z0-9-]{1,48}[a-z0-9]$", key)) && !strcontains(key, "--")
    ])
    error_message = "vm_backup.policies needs at least one policy, and every key (the policy name) must be 3-50 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }
}

variable "virtual_machine_scale_sets" {
  description = "Linux or Windows Virtual Machine Scale Sets keyed by a stable logical name. Defaults to none; add one entry per scale set. Every instance signs in with admin_username and the shared vm_admin_password (Linux uses password sign-in, no SSH keys); new instances always start with that initial password. virtual_network selects the VNet whose virtual_machines subnet the instances join (default: the PRV VNet)."
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
    virtual_network                              = optional(string)
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

  validation {
    condition = alltrue([
      for scale_set in values(var.virtual_machine_scale_sets) :
      try(contains(keys(var.virtual_networks[coalesce(scale_set.virtual_network, local.default_virtual_network)].subnets), "virtual_machines"), false)
    ])
    error_message = "Every virtual_machine_scale_sets virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list virtual_machines. Scale sets per VNet: ${join(", ", [for key, scale_set in var.virtual_machine_scale_sets : "${key}=${coalesce(scale_set.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  validation {
    condition = alltrue([
      for scale_set in values(var.virtual_machine_scale_sets) :
      scale_set.load_balancer == null || try(
        coalesce(var.load_balancers[scale_set.load_balancer].virtual_network, local.default_virtual_network) == coalesce(scale_set.virtual_network, local.default_virtual_network),
        true
      )
    ])
    error_message = "Every virtual_machine_scale_sets entry with a load_balancer must be in the same virtual_network as that load balancer."
  }
}

variable "load_balancers" {
  description = "Internal Standard load balancers keyed by a stable logical name. Every frontend IP sits in the load_balancers subnet of the load balancer's virtual_network (default: the PRV VNet), shared by every load balancer in that VNet, and each load balancer has one backend pool; VMs and scale sets in the same VNet join by setting load_balancer to the key. Names follow M-AZU-LBL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per load balancer. Probe and rule names are their keys. Defaults to none."
  type = map(object({
    sequence           = optional(string, "00")
    virtual_network    = optional(string)
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
    condition = alltrue([
      for load_balancer in values(var.load_balancers) :
      try(contains(keys(var.virtual_networks[coalesce(load_balancer.virtual_network, local.default_virtual_network)].subnets), "load_balancers"), false)
    ])
    error_message = "Every load_balancers virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list load_balancers, the range shared by every load balancer frontend in that VNet (/29 or larger)."
  }

  # Azure reserves the first four addresses and the last address of a subnet.
  validation {
    condition = alltrue([
      for load_balancer in values(var.load_balancers) : load_balancer.private_ip_address == null ? true : try(
        can(regex("^(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])){3}$", load_balancer.private_ip_address)) &&
        sum([
          for index, octet in split(".", load_balancer.private_ip_address) :
          tonumber(octet) * pow(256, 3 - index)
          ]) >= sum([
          for index, octet in split(".", cidrhost(var.virtual_networks[coalesce(load_balancer.virtual_network, local.default_virtual_network)].subnets["load_balancers"].cidr, 0)) :
          tonumber(octet) * pow(256, 3 - index)
        ]) + 4 &&
        sum([
          for index, octet in split(".", load_balancer.private_ip_address) :
          tonumber(octet) * pow(256, 3 - index)
          ]) <= sum([
          for index, octet in split(".", cidrhost(var.virtual_networks[coalesce(load_balancer.virtual_network, local.default_virtual_network)].subnets["load_balancers"].cidr, 0)) :
          tonumber(octet) * pow(256, 3 - index)
        ]) + pow(2, 32 - tonumber(split("/", var.virtual_networks[coalesce(load_balancer.virtual_network, local.default_virtual_network)].subnets["load_balancers"].cidr)[1])) - 2,
        false
      )
    ])
    error_message = "Every load_balancers private_ip_address must be a usable address in the load_balancers subnet of the load balancer's virtual_network: not one of the first four addresses or the last address."
  }

  validation {
    condition = length(distinct([
      for load_balancer in values(var.load_balancers) :
      "${coalesce(load_balancer.virtual_network, local.default_virtual_network, "none")}/${load_balancer.private_ip_address}"
      if load_balancer.private_ip_address != null
      ])) == length([
      for load_balancer in values(var.load_balancers) : load_balancer.private_ip_address
      if load_balancer.private_ip_address != null
    ])
    error_message = "Load balancers in the same virtual network share one frontend subnet, so their static private_ip_address values must be unique."
  }
}

variable "log_analytics_workspace" {
  description = "Settings for the Log Analytics workspace shared by every Container Apps environment, the shared Application Insights resource and the diagnostic settings of Databricks workspaces (created only when one of them exists). The workspace is named M-AZU-LAW-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN. daily_quota_gb caps ingestion across everything that sends data to the workspace (Application Insights telemetry included; -1 removes the cap); retention_in_days is 30-730."
  type = object({
    sequence          = optional(string, "00")
    daily_quota_gb    = optional(number, 0.1)
    retention_in_days = optional(number, 30)
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(regex("^[0-9]{2}$", var.log_analytics_workspace.sequence))
    error_message = "log_analytics_workspace.sequence must be two digits, for example 00."
  }

  validation {
    condition     = var.log_analytics_workspace.daily_quota_gb == -1 || var.log_analytics_workspace.daily_quota_gb > 0
    error_message = "log_analytics_workspace.daily_quota_gb must be greater than 0, or -1 for no cap."
  }

  # Disabled: azurerm validates retention_in_days (30-730) at plan time.
  # validation {
  #   condition = (
  #     var.log_analytics_workspace.retention_in_days >= 30 &&
  #     var.log_analytics_workspace.retention_in_days <= 730 &&
  #     floor(var.log_analytics_workspace.retention_in_days) == var.log_analytics_workspace.retention_in_days
  #   )
  #   error_message = "log_analytics_workspace.retention_in_days must be a whole number from 30 to 730."
  # }
}

variable "application_insights" {
  description = "Settings for the workspace-based Application Insights resource shared by every function_apps, logic_apps and web_apps entry whose application_insights flag is true (the default). enabled = false turns telemetry off for every app, for example when the deployer cannot create role assignments. The resource is created only when at least one app uses it, stores its data in the shared Log Analytics workspace, and accepts only Microsoft Entra-authenticated telemetry: each app's system-assigned identity gets Monitoring Metrics Publisher, so the deployer needs rights to create role assignments. Telemetry leaves the VNet, so the function_integration, logic_app_integration and web_app_integration subnets of the apps' VNets need nat_gateway = true or a route table with a 0.0.0.0/0 route (Terraform warns otherwise). Named M-AZU-AIN-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN."
  type = object({
    enabled  = optional(bool, true)
    sequence = optional(string, "00")
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(regex("^[0-9]{2}$", var.application_insights.sequence))
    error_message = "application_insights.sequence must be two digits, for example 00."
  }
}

variable "network_security_groups" {
  description = "Network security groups keyed by a stable logical name, holding rules only: a subnet uses a group by setting network_security_group = \"<key>\" in virtual_networks.<VNet key>.subnets, and every subnet that uses a group must be in the same virtual network. The SQL Managed Instance and Databricks subnets cannot use one because their modules manage their own group. Rule names are the security_rules keys. Defaults to none. Names follow M-AZU-NSG-<BU>-<DPT>-<APP>-<classification>-<ENV>-<REG>[-<sequence>]; classification defaults to the classification of the VNet whose subnets use the group (or of the default VNet while no subnet uses it) and, if set, must match it. Set a unique two-digit sequence when more than one group shares a classification."
  type = map(object({
    classification = optional(string)
    sequence       = optional(string)
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
  default  = {}
  nullable = false

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
      (nsg.classification == null || contains(local.naming_dictionary.network_classifications, coalesce(nsg.classification, "-"))) &&
      (nsg.sequence == null || can(regex("^[0-9]{2}$", coalesce(nsg.sequence, "-"))))
    ])
    error_message = "Every network_security_groups entry needs classification PUB or PRV if set (default: the classification of its VNet) and, if set, a two-digit sequence such as 01."
  }

  # The name carries the PUB/PRV classification of one VNet.
  validation {
    condition = alltrue([
      for key, nsg in var.network_security_groups :
      length(lookup(local.network_security_group_networks, key, [])) <= 1 &&
      alltrue([
        for network_key in lookup(local.network_security_group_networks, key, []) :
        nsg.classification == null || nsg.classification == var.virtual_networks[network_key].classification
      ])
    ])
    error_message = "Every network_security_groups entry can be used by subnets of one virtual network only, and a classification set on it must match that VNet's: its name carries the VNet's PUB/PRV classification. Use one group per VNet. VNets per group: ${join(", ", [for key, network_keys in local.network_security_group_networks : "${key}=${join("+", network_keys)}"])}."
  }

  validation {
    condition     = alltrue([for key in keys(local.network_security_group_subnets) : contains(keys(var.network_security_groups), key)])
    error_message = "Every network_security_group set on a virtual_networks subnet must be a network_security_groups key. Unknown keys and the subnets that use them: ${join(", ", [for key, subnets in local.network_security_group_subnets : "${key} (${join(", ", [for subnet in subnets : "${subnet.virtual_network}/${subnet.subnet}"])})" if !contains(keys(var.network_security_groups), key)])}."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for key, nsg in var.network_security_groups : "${coalesce(nsg.classification, try(var.virtual_networks[one(local.network_security_group_networks[key])].classification, null), try(var.virtual_networks[local.default_virtual_network].classification, null), "PRV")}-${coalesce(nsg.sequence, "none")}"],
        [
          for instance in values(var.sql_managed_instances) :
          "${try(var.virtual_networks[coalesce(instance.virtual_network, local.default_virtual_network)].classification, "PRV")}-${coalesce(instance.network_sequence, "none")}"
        ],
        [
          for key, workspace in var.databricks_workspaces :
          "${try(var.virtual_networks[local.databricks_workspace_networks[key]].classification, "PRV")}-${coalesce(workspace.network_sequence, workspace.sequence)}"
        ]
      ))) ==
      length(var.network_security_groups) + length(var.sql_managed_instances) + length(var.databricks_workspaces)
    )
    error_message = "Network security group names must be unique: give each group with the same classification its own sequence (including the sql_managed_instances network_sequence and the databricks_workspaces network_sequence, which defaults to the workspace sequence; both use the classification of their VNet)."
  }
}

variable "route_tables" {
  description = "Route tables keyed by a stable logical name, holding routes only: a subnet uses a table by setting route_table = \"<key>\" in virtual_networks.<VNet key>.subnets, and every subnet that uses a table must be in the same virtual network. The SQL Managed Instance subnet cannot use one because its module manages its own table. Route names are the routes keys. A 0.0.0.0/0 route overrides NAT Gateway egress for its subnets. Defaults to none. Names follow M-AZU-UDR-<BU>-<DPT>-<APP>-<classification>-<ENV>-<REG>[-<sequence>]; classification defaults to the classification of the VNet whose subnets use the table (or of the default VNet while no subnet uses it) and, if set, must match it. Set a unique two-digit sequence when more than one table shares a classification."
  type = map(object({
    classification                = optional(string)
    sequence                      = optional(string)
    bgp_route_propagation_enabled = optional(bool, true)
    routes = optional(map(object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })), {})
  }))
  default  = {}
  nullable = false

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
      (route_table.classification == null || contains(local.naming_dictionary.network_classifications, coalesce(route_table.classification, "-"))) &&
      (route_table.sequence == null || can(regex("^[0-9]{2}$", coalesce(route_table.sequence, "-"))))
    ])
    error_message = "Every route_tables entry needs classification PUB or PRV if set (default: the classification of its VNet) and, if set, a two-digit sequence such as 01."
  }

  # The name carries the PUB/PRV classification of one VNet.
  validation {
    condition = alltrue([
      for key, route_table in var.route_tables :
      length(lookup(local.route_table_networks, key, [])) <= 1 &&
      alltrue([
        for network_key in lookup(local.route_table_networks, key, []) :
        route_table.classification == null || route_table.classification == var.virtual_networks[network_key].classification
      ])
    ])
    error_message = "Every route_tables entry can be used by subnets of one virtual network only, and a classification set on it must match that VNet's: its name carries the VNet's PUB/PRV classification. Use one table per VNet. VNets per table: ${join(", ", [for key, network_keys in local.route_table_networks : "${key}=${join("+", network_keys)}"])}."
  }

  validation {
    condition     = alltrue([for key in keys(local.route_table_subnets) : contains(keys(var.route_tables), key)])
    error_message = "Every route_table set on a virtual_networks subnet must be a route_tables key. Unknown keys and the subnets that use them: ${join(", ", [for key, subnets in local.route_table_subnets : "${key} (${join(", ", [for subnet in subnets : "${subnet.virtual_network}/${subnet.subnet}"])})" if !contains(keys(var.route_tables), key)])}."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for key, route_table in var.route_tables : "${coalesce(route_table.classification, try(var.virtual_networks[one(local.route_table_networks[key])].classification, null), try(var.virtual_networks[local.default_virtual_network].classification, null), "PRV")}-${coalesce(route_table.sequence, "none")}"],
        [
          for instance in values(var.sql_managed_instances) :
          "${try(var.virtual_networks[coalesce(instance.virtual_network, local.default_virtual_network)].classification, "PRV")}-${coalesce(instance.network_sequence, "none")}"
        ]
      ))) ==
      length(var.route_tables) + length(var.sql_managed_instances)
    )
    error_message = "Route table names must be unique: give each table with the same classification its own sequence (including the sql_managed_instances network_sequence, which uses the classification of its VNet)."
  }
}

variable "hub_peering" {
  description = "Peers virtual networks as spokes to an existing hub VNet. Defaults to null (no peering). virtual_networks lists the virtual_networks keys to peer (default: every VNet). For each, the spoke-to-hub side is always created; the hub-to-spoke side is created by default (create_hub_to_spoke_peering) through the azurerm.hub provider, whose subscription is read from hub_virtual_network_id. use_remote_gateways routes the spokes through the hub's VPN or ExpressRoute gateway and sets allow_gateway_transit on the hub side. Each side is named <local VNet name>-to-<remote VNet name>, which must fit the 80-character peering limit."
  type = object({
    hub_virtual_network_id      = string
    virtual_networks            = optional(list(string))
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

  validation {
    condition = (
      try(var.hub_peering.virtual_networks, null) == null ||
      try(
        length(var.hub_peering.virtual_networks) > 0 &&
        length(distinct(var.hub_peering.virtual_networks)) == length(var.hub_peering.virtual_networks) &&
        alltrue([for key in var.hub_peering.virtual_networks : contains(keys(var.virtual_networks), key)]),
        false
      )
    )
    error_message = "hub_peering.virtual_networks must list one or more different virtual_networks keys, or be left unset to peer every VNet. Available keys: ${join(", ", keys(var.virtual_networks))}."
  }

  # Peering names are not truncated (the standard forbids arbitrary
  # truncation), so a long hub VNet name is rejected.
  validation {
    condition = var.hub_peering == null || try(alltrue([
      for key in try(coalescelist(var.hub_peering.virtual_networks, keys(var.virtual_networks)), keys(var.virtual_networks)) :
      length(split("/", var.hub_peering.hub_virtual_network_id)[8]) + length(try(local.virtual_network_names[key], "")) + 4 <= 80
    ]), true)
    error_message = "Hub peering names are <spoke VNet name>-to-<hub VNet name> and <hub VNet name>-to-<spoke VNet name>, at most 80 characters; the hub VNet name in hub_peering.hub_virtual_network_id is too long for: ${join(", ", [for key, name in local.virtual_network_names : name])}."
  }
}

variable "container_registries" {
  description = "Private Premium Azure Container Registries keyed by a stable logical name. Defaults to none; add one entry per registry. Names follow the compact family mazuacr<BU><DPT><APP><ENV><REG><sequence> (global, 5-50 lowercase letters and digits); sequence is the two-digit NN and must be unique per registry. virtual_network selects the VNet whose private_endpoints subnet hosts the registry's Private Endpoint (default: the PRV VNet)."
  type = map(object({
    virtual_network = optional(string)
    sequence        = optional(string, "00")
  }))
  default = {}

  validation {
    condition = alltrue([
      for item in values(var.container_registries) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every container_registries virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its Private Endpoint sits in that subnet. VNets: ${join(", ", [for key, item in var.container_registries : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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
  description = "RBAC-enabled Key Vaults keyed by a stable logical name. Defaults to none; add one entry per vault. Names follow mazukva<BU><DPT><APP><ENV><REG><sequence>; sequence is the two-digit NN and must be unique per vault. virtual_network selects the VNet whose private_endpoints subnet hosts the vault's Private Endpoint (default: the PRV VNet)."
  type = map(object({
    virtual_network          = optional(string)
    sequence                 = optional(string, "00")
    sku_name                 = optional(string, "standard")
    purge_protection_enabled = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for item in values(var.key_vaults) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every key_vaults virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its Private Endpoint sits in that subnet. VNets: ${join(", ", [for key, item in var.key_vaults : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  # Disabled: the key is only a label; it never appears in the vault name or
  # its Private Endpoint name, so neither Azure nor METLEN restricts it.
  # validation {
  #   condition = alltrue([
  #     for key in keys(var.key_vaults) :
  #     can(regex("^[a-z][a-z0-9-]{0,11}$", key)) &&
  #     !strcontains(key, "--")
  #   ])
  #   error_message = "key_vaults keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, and not contain consecutive hyphens."
  # }

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
  description = "General-purpose v2 storage accounts keyed by a stable logical name. Defaults to none; add one entry per account. Names follow mazusoa<BU><DPT><APP><ENV><REG><sequence>; sequence is the two-digit NN, shared with premium_file_accounts and the function_apps host storage, and must be unique across them. Blob container names (containers) and file share names (file_shares keys) are chosen by the application and used as-is: 3-63 lowercase letters, digits and hyphens, starting and ending with a letter or digit, without consecutive hyphens. virtual_network selects the VNet whose private_endpoints subnet hosts the account's blob and file Private Endpoints (default: the PRV VNet)."
  type = map(object({
    virtual_network  = optional(string)
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
      for item in values(var.storage_accounts) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every storage_accounts virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its blob and file Private Endpoints sit in that subnet. VNets: ${join(", ", [for key, item in var.storage_accounts : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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
    condition = alltrue(flatten([
      for account in values(var.storage_accounts) : [
        for name in concat(tolist(account.containers), keys(account.file_shares)) :
        can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", name)) && !strcontains(name, "--")
      ]
    ]))
    error_message = "Every storage_accounts container name and file_shares key is used as the Azure name and must be 3-63 lowercase letters, digits and hyphens, start and end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for account in values(var.storage_accounts) : account.sequence],
        [for account in values(var.premium_file_accounts) : account.sequence],
        [for app in values(var.function_apps) : app.storage_sequence],
        [for app in values(var.logic_apps) : app.storage_sequence]
      ))) ==
      length(var.storage_accounts) + length(var.premium_file_accounts) + length(var.function_apps) + length(var.logic_apps)
    )
    error_message = "Storage Account names must be unique, so every storage_accounts and premium_file_accounts sequence and function_apps and logic_apps storage_sequence must differ. Current sequences: ${join(", ", concat(
      [for key, account in var.storage_accounts : "storage_accounts.${key}=${account.sequence}"],
      [for key, account in var.premium_file_accounts : "premium_file_accounts.${key}=${account.sequence}"],
      [for key, app in var.function_apps : "function_apps.${key}.storage_sequence=${app.storage_sequence}"],
      [for key, app in var.logic_apps : "logic_apps.${key}.storage_sequence=${app.storage_sequence}"]
    ))}."
  }
}

variable "premium_file_accounts" {
  description = "Premium FileStorage accounts and SMB shares keyed by a stable logical account name. Defaults to none; add one entry per account. Names follow the Storage Account family; sequence must be unique across all storage accounts. File share names (file_shares keys) are chosen by the application and used as-is: 3-63 lowercase letters, digits and hyphens, starting and ending with a letter or digit, without consecutive hyphens. virtual_network selects the VNet whose private_endpoints subnet hosts the account's file Private Endpoint (default: the PRV VNet)."
  type = map(object({
    virtual_network  = optional(string)
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
      for item in values(var.premium_file_accounts) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every premium_file_accounts virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its file Private Endpoint sits in that subnet. VNets: ${join(", ", [for key, item in var.premium_file_accounts : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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

  validation {
    condition = alltrue(flatten([
      for account in values(var.premium_file_accounts) : [
        for name in keys(account.file_shares) :
        can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", name)) && !strcontains(name, "--")
      ]
    ]))
    error_message = "Every premium_file_accounts file_shares key is used as the Azure share name and must be 3-63 lowercase letters, digits and hyphens, start and end with a letter or digit, and not contain consecutive hyphens."
  }
}

variable "azure_sql_servers" {
  description = "Azure SQL logical servers keyed by a stable logical name. Each server hosts one database, standalone or in an optional elastic pool. Defaults to none; add one entry per server. Server names follow m-azu-sql-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> and elastic pool names M-AZU-SEL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per server. The database name is chosen by the application (database_name) and defaults to the entry key. virtual_network selects the VNet whose private_endpoints subnet hosts the server's Private Endpoint (default: the PRV VNet)."
  type = map(object({
    virtual_network   = optional(string)
    sequence          = optional(string, "00")
    database_name     = optional(string)
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
      for item in values(var.azure_sql_servers) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every azure_sql_servers virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its Private Endpoint sits in that subnet. VNets: ${join(", ", [for key, item in var.azure_sql_servers : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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

  validation {
    condition = alltrue([
      for key, server in var.azure_sql_servers :
      can(regex("^[^<>*%&:\\\\/?]{0,127}[^<>*%&:\\\\/?. ]$", coalesce(server.database_name, key))) &&
      !contains(["master", "model", "msdb", "tempdb"], lower(coalesce(server.database_name, key)))
    ])
    error_message = "Every azure_sql_servers database_name (the entry key when unset) must be 1-128 characters without < > * % & : \\ / ?, must not end with a period or space, and must not be a system database name (master, model, msdb, tempdb)."
  }
}

variable "container_apps_environments" {
  description = "Internal Container Apps environments keyed by a stable logical name. Each environment is placed in the virtual network that lists its container_apps/<key> subnet in virtual_networks.<VNet key>.subnets, uses that subnet as its own delegated subnet, and gets its own private DNS zone (linked to every VNet), optional dedicated workload profiles, and zero or more Container Apps. Environment names follow M-AZU-CEV-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence> and app names m-azu-cap-<bu>-<dpt>-<app>-<env>-<reg>-<sequence>; environment sequences must be unique, and app sequences unique across every environment because Container App names are unique per resource group. Defaults to none."
  type = map(object({
    sequence = optional(string, "00")
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
    condition     = alltrue([for key in keys(var.container_apps_environments) : anytrue([for network in values(var.virtual_networks) : contains(keys(network.subnets), "container_apps/${key}")])])
    error_message = "Every container_apps_environments entry needs a container_apps/<key> subnet in the virtual network that hosts it, for example virtual_networks = { main = { subnets = { \"container_apps/primary\" = { cidr = \"10.42.2.0/27\", number = 9 } } } }. Missing: ${join(", ", [for key in keys(var.container_apps_environments) : key if !anytrue([for network in values(var.virtual_networks) : contains(keys(network.subnets), "container_apps/${key}")])])}."
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
  description = "Cosmos DB accounts keyed by a stable logical name, each with its own classic API, throughput, and data-plane resources. Defaults to none; add one entry per account. Account names follow m-azu-cdb-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase); sequence is the two-digit NN and must be unique per account. The database (keyspace, graph database; unused by the Table API) and container (collection, table, graph) names are chosen by the application through database_name and container_name and both default to the entry key. Rules per API: NoSQL and Gremlin 1-255 characters without / \\ # ? and no trailing space; MongoDB 1-63 letters, digits, hyphens and underscores; Cassandra a letter followed by up to 47 letters, digits and underscores; Table (container only) a letter followed by 2-62 letters and digits. virtual_network selects the VNet whose private_endpoints subnet hosts the account's Private Endpoint (default: the PRV VNet)."
  type = map(object({
    virtual_network               = optional(string)
    sequence                      = optional(string, "00")
    database_name                 = optional(string)
    container_name                = optional(string)
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
      for item in values(var.cosmos_db_accounts) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every cosmos_db_accounts virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list private_endpoints; its Private Endpoint sits in that subnet. VNets: ${join(", ", [for key, item in var.cosmos_db_accounts : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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

  validation {
    condition = alltrue([
      for key, account in var.cosmos_db_accounts : (
        account.api_type == "Cassandra" ? alltrue([
          for name in [coalesce(account.database_name, key), coalesce(account.container_name, key)] :
          can(regex("^[A-Za-z][A-Za-z0-9_]{0,47}$", name))
          ]) : account.api_type == "Table" ? (
          can(regex("^[A-Za-z][A-Za-z0-9]{2,62}$", coalesce(account.container_name, key)))
          ) : account.api_type == "MongoDB" ? alltrue([
            for name in [coalesce(account.database_name, key), coalesce(account.container_name, key)] :
            can(regex("^[A-Za-z0-9_-]{1,63}$", name))
            ]) : alltrue([
            for name in [coalesce(account.database_name, key), coalesce(account.container_name, key)] :
            can(regex("^[^/\\\\#?]{0,254}[^/\\\\#? ]$", name))
        ])
      )
    ])
    error_message = "Every cosmos_db_accounts database_name and container_name (the entry key when unset) must meet the rules of its API: NoSQL and Gremlin 1-255 characters without / \\ # ? and no trailing space; MongoDB 1-63 letters, digits, hyphens and underscores; Cassandra a letter followed by up to 47 letters, digits and underscores (no hyphens, so keys with hyphens need explicit names); Table container a letter followed by 2-62 letters and digits."
  }
}

variable "databricks_workspaces" {
  description = "Premium Azure Databricks workspaces keyed by a stable logical name, injected with secure cluster connectivity (no public IPs on clusters) into the virtual network that lists its databricks/<key>/host and databricks/<key>/container subnets in virtual_networks.<VNet key>.subnets. Defaults to none. Both subnets are delegated to Azure Databricks, and the workspace gets its own NSG on both. Its Private Endpoints sit in the private_endpoints subnet of the same VNet. network_access is private (default: databricks_ui_api Private Endpoint for users and clusters, public access disabled), backend_private (Private Endpoint for clusters only, users over the internet) or public. One private workspace per region hosts the browser_authentication Private Endpoint that browser sign-in to every private workspace uses; following Microsoft's guidance, it is a dedicated workspace (browser_authentication_workspace = true, network_access private) that runs no workloads, gets no databricks_ui_api endpoint or Access Connector, and is protected by a CanNotDelete lock unless delete_lock = false. Without one, sign-in to private workspaces works only when a hub already provides the endpoint (Terraform warns). Clusters need outbound internet access: set nat_gateway = true on both subnets or attach a route table that sends 0.0.0.0/0 to a hub firewall. Names: workspace and Access Connector M-AZU-DBR-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>, managed resource group M-AZU-RGP-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>, NSG M-AZU-NSG-<BU>-<DPT>-<APP>-<PUB|PRV of the VNet>-<ENV>-<REG>-<network_sequence, default sequence>, root (DBFS) storage mazusoa...<storage_sequence> (null lets Azure generate it). access_connector creates the Unity Catalog managed identity and grants it Storage Blob Data Contributor on the listed storage_accounts keys; diagnostics sends the workspace resource logs to the shared Log Analytics workspace: every category (allLogs, the only category group Azure Databricks supports) or only the listed categories."
  type = map(object({
    sequence                         = optional(string, "00")
    sku                              = optional(string, "premium")
    network_access                   = optional(string, "private")
    browser_authentication_workspace = optional(bool, false)
    delete_lock                      = optional(bool, true)
    network_sequence                 = optional(string)
    storage_sequence                 = optional(string)
    access_connector = optional(object({
      enabled          = optional(bool, true)
      storage_accounts = optional(list(string), [])
    }), {})
    diagnostics = optional(object({
      enabled    = optional(bool, true)
      categories = optional(list(string), [])
    }), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.databricks_workspaces) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "databricks_workspaces keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for workspace in values(var.databricks_workspaces) :
      can(regex("^[0-9]{2}$", workspace.sequence)) &&
      (workspace.network_sequence == null || can(regex("^[0-9]{2}$", workspace.network_sequence))) &&
      (workspace.storage_sequence == null || can(regex("^[0-9]{2}$", workspace.storage_sequence)))
    ])
    error_message = "Every databricks_workspaces sequence must be two digits, for example 00, and every network_sequence and storage_sequence null or two digits."
  }

  validation {
    condition     = length(distinct([for workspace in values(var.databricks_workspaces) : workspace.sequence])) == length(var.databricks_workspaces)
    error_message = "Every databricks_workspaces entry needs a unique sequence because workspace and managed resource group names must be unique. Current sequences: ${join(", ", [for key, workspace in var.databricks_workspaces : "${key}=${workspace.sequence}"])}."
  }

  # Standard tier workspaces cannot be created since 1 April 2026.
  validation {
    condition = alltrue([
      for workspace in values(var.databricks_workspaces) :
      contains(["premium", "trial"], workspace.sku) &&
      contains(["private", "backend_private", "public"], workspace.network_access) &&
      length(distinct(workspace.diagnostics.categories)) == length(workspace.diagnostics.categories) &&
      alltrue([for category in workspace.diagnostics.categories : can(regex("^[A-Za-z][A-Za-z0-9]*$", category))])
    ])
    error_message = "Every databricks_workspaces entry needs sku premium or trial, network_access private, backend_private or public, and unique diagnostics.categories names such as clusters or unityCatalog (empty sends every category)."
  }

  validation {
    condition = (
      length([for workspace in values(var.databricks_workspaces) : workspace if workspace.browser_authentication_workspace]) <= 1 &&
      alltrue([
        for workspace in values(var.databricks_workspaces) :
        !workspace.browser_authentication_workspace || (
          workspace.network_access == "private" &&
          length(workspace.access_connector.storage_accounts) == 0
        )
      ])
    )
    error_message = "At most one databricks_workspaces entry can be the browser_authentication_workspace; it must use network_access = \"private\" and list no access_connector.storage_accounts (it runs no workloads)."
  }

  validation {
    condition     = alltrue([for key in keys(var.databricks_workspaces) : anytrue([for network in values(var.virtual_networks) : contains(keys(network.subnets), "databricks/${key}/host")])])
    error_message = "Every databricks_workspaces entry needs databricks/<key>/host and databricks/<key>/container subnets in the virtual network that hosts it, for example virtual_networks = { main = { subnets = { \"databricks/analytics/host\" = { cidr = \"10.42.10.0/26\", number = 10 }, \"databricks/analytics/container\" = { cidr = \"10.42.10.64/26\", number = 11 } } } }. Missing: ${join(", ", [for key in keys(var.databricks_workspaces) : key if !anytrue([for network in values(var.virtual_networks) : contains(keys(network.subnets), "databricks/${key}/host")])])}."
  }

  validation {
    condition = alltrue([
      for key, workspace in var.databricks_workspaces :
      workspace.network_access == "public" && !workspace.browser_authentication_workspace ||
      anytrue([
        for network in values(var.virtual_networks) :
        contains(keys(network.subnets), "databricks/${key}/host") && contains(keys(network.subnets), "private_endpoints")
      ])
    ])
    error_message = "Every databricks_workspaces entry with a Private Endpoint (network_access private or backend_private, or the browser_authentication_workspace) needs a private_endpoints subnet in the virtual network that hosts it."
  }

  validation {
    condition = (
      length(distinct(concat(
        [for workspace in values(var.databricks_workspaces) : workspace.storage_sequence if workspace.storage_sequence != null],
        [for account in values(var.storage_accounts) : account.sequence],
        [for account in values(var.premium_file_accounts) : account.sequence],
        [for app in values(var.function_apps) : app.storage_sequence],
        [for app in values(var.logic_apps) : app.storage_sequence]
      ))) ==
      length([for workspace in values(var.databricks_workspaces) : workspace if workspace.storage_sequence != null]) +
      length(var.storage_accounts) + length(var.premium_file_accounts) + length(var.function_apps) + length(var.logic_apps)
    )
    error_message = "Storage Account names must be unique, so every databricks_workspaces storage_sequence must differ from the others and from every storage_accounts and premium_file_accounts sequence and function_apps and logic_apps storage_sequence."
  }

  validation {
    condition = alltrue(flatten([
      for workspace in values(var.databricks_workspaces) : [
        for account_key in workspace.access_connector.storage_accounts :
        workspace.access_connector.enabled && contains(keys(var.storage_accounts), account_key)
      ]
    ]))
    error_message = "databricks_workspaces access_connector.storage_accounts entries must be storage_accounts keys, and need access_connector.enabled = true."
  }

  # Azure Databricks VNet injection requires a /16 to /24 virtual network.
  validation {
    condition = alltrue(flatten([
      for network in values(var.virtual_networks) : [
        for prefix in network.address_space :
        try(tonumber(split("/", prefix)[1]) >= 16 && tonumber(split("/", prefix)[1]) <= 24, false)
      ] if anytrue([for key in keys(var.databricks_workspaces) : contains(keys(network.subnets), "databricks/${key}/host")])
    ]))
    error_message = "Azure Databricks VNet injection requires every address_space prefix of a virtual network that hosts a workspace to be between /16 and /24."
  }
}

variable "sql_managed_instances" {
  description = "SQL Managed Instances keyed by a stable logical name. Defaults to none; add one entry, for example { primary = {} }, to create an instance with its delegated subnet and its own NSG and route table. At most one entry is allowed: the module attaches its own NSG and route table to the sql_managed_instance subnet of its virtual_network (default: the PRV VNet), and they use the classification of that VNet. The instance name follows m-azu-smi-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase); sequence is its two-digit NN. network_sequence is the optional two-digit NN of the instance's NSG and route table; set it when another group or table already uses the name without a sequence."
  type = map(object({
    virtual_network             = optional(string)
    sequence                    = optional(string, "00")
    sku_name                    = optional(string, "GP_Gen5")
    vcores                      = optional(number, 4)
    storage_size_in_gb          = optional(number, 32)
    license_type                = optional(string, "LicenseIncluded")
    azuread_administrator_login = optional(string, "Terraform SQL MI Admin")
    azuread_administrator_type  = optional(string, "User")
    network_sequence            = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for item in values(var.sql_managed_instances) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "sql_managed_instance"),
      false)
    ])
    error_message = "Every sql_managed_instances virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list sql_managed_instance; the instance is injected into that subnet. VNets: ${join(", ", [for key, item in var.sql_managed_instances : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  validation {
    condition = alltrue([
      for key in keys(var.sql_managed_instances) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "sql_managed_instances keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition     = length(var.sql_managed_instances) <= 1
    error_message = "sql_managed_instances supports at most one entry. Current keys: ${join(", ", keys(var.sql_managed_instances))}."
  }

  validation {
    condition = alltrue([
      for instance in values(var.sql_managed_instances) :
      can(regex("^[0-9]{2}$", instance.sequence)) &&
      (instance.network_sequence == null || can(regex("^[0-9]{2}$", instance.network_sequence)))
    ])
    error_message = "Every sql_managed_instances sequence must be two digits, for example 00, and every network_sequence null or two digits."
  }
}

variable "postgresql_servers" {
  description = "PostgreSQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database; every server uses database_admin_password as its administrator password, and the servers in a virtual network (virtual_network, default: the PRV VNet) share its delegated postgresql subnet, and every server uses the privatelink.postgres.database.azure.com zone. Server names follow m-azu-pgs-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase); sequence is the two-digit NN and must be unique per server. The database name is chosen by the application (database_name) and defaults to the entry key. Defaults to none."
  type = map(object({
    virtual_network     = optional(string)
    sequence            = optional(string, "00")
    database_name       = optional(string)
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
      for item in values(var.postgresql_servers) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "postgresql"),
      false)
    ])
    error_message = "Every postgresql_servers virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list postgresql; the server is injected into that delegated subnet. VNets: ${join(", ", [for key, item in var.postgresql_servers : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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

  validation {
    condition = alltrue([
      for key, server in var.postgresql_servers :
      can(regex("^[A-Za-z_-][A-Za-z0-9_-]{0,62}$", coalesce(server.database_name, key))) &&
      !contains(["azure_maintenance", "azure_sys", "postgres", "template0", "template1"], lower(coalesce(server.database_name, key)))
    ])
    error_message = "Every postgresql_servers database_name (the entry key when unset) must be 1-63 letters, digits, hyphens and underscores, must not start with a digit, and must not be a system database name (azure_maintenance, azure_sys, postgres, template0, template1)."
  }

  # Azure's documented minimum for a PostgreSQL delegated subnet is /28.
  validation {
    condition = alltrue([
      for server in values(var.postgresql_servers) :
      try(tonumber(split("/", var.virtual_networks[coalesce(server.virtual_network, local.default_virtual_network)].subnets["postgresql"].cidr)[1]) <= 28, false)
    ])
    error_message = "The postgresql subnet must be /28 or larger in every virtual network that hosts postgresql_servers."
  }

  # Azure documents four subnet addresses per high-availability server; a
  # non-HA server was measured in Azure to use one. Azure reserves five
  # addresses in every subnet.
  validation {
    condition = alltrue([
      for network_key in distinct([for server in values(var.postgresql_servers) : coalesce(server.virtual_network, local.default_virtual_network, "-")]) : try(
        sum([
          for server in values(var.postgresql_servers) : server.high_availability.enabled ? 4 : 1
          if coalesce(server.virtual_network, local.default_virtual_network) == network_key
        ]) <= pow(2, 32 - tonumber(split("/", var.virtual_networks[network_key].subnets["postgresql"].cidr)[1])) - 5,
        false
      )
    ])
    error_message = "The postgresql subnet is too small for the postgresql_servers in its virtual network: each server needs one address, or four with high availability, and Azure reserves five addresses per subnet."
  }
}

variable "mysql_servers" {
  description = "MySQL Flexible Servers keyed by a stable logical name. Each entry creates one server with one database; every server uses database_admin_password as its administrator password, and the servers in a virtual network (virtual_network, default: the PRV VNet) share its delegated mysql subnet, and every server uses the privatelink.mysql.database.azure.com zone. Server names follow m-azu-mys-<bu>-<dpt>-<app>-<env>-<reg>-<sequence> (global, lowercase); sequence is the two-digit NN and must be unique per server. The database name is chosen by the application (database_name), defaults to the entry key, and must be lowercase because MySQL stores database names in lowercase. Defaults to none."
  type = map(object({
    virtual_network     = optional(string)
    sequence            = optional(string, "00")
    database_name       = optional(string)
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
      for item in values(var.mysql_servers) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "mysql"),
      false)
    ])
    error_message = "Every mysql_servers virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list mysql; the server is injected into that delegated subnet. VNets: ${join(", ", [for key, item in var.mysql_servers : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

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

  # Azure Database for MySQL uses lower_case_table_names = 1, so an uppercase
  # name would be stored in lowercase and cause drift on every plan.
  validation {
    condition = alltrue([
      for key, server in var.mysql_servers :
      can(regex("^[a-z0-9_-]{1,63}$", coalesce(server.database_name, key))) &&
      !contains(["information_schema", "mysql", "performance_schema", "sys"], coalesce(server.database_name, key))
    ])
    error_message = "Every mysql_servers database_name (the entry key when unset) must be 1-63 lowercase letters, digits, hyphens and underscores, and must not be a system database name (information_schema, mysql, performance_schema, sys)."
  }

  # Each server takes one subnet address, or two with high availability; Azure
  # reserves five addresses in every subnet.
  validation {
    condition = alltrue([
      for network_key in distinct([for server in values(var.mysql_servers) : coalesce(server.virtual_network, local.default_virtual_network, "-")]) : try(
        sum([
          for server in values(var.mysql_servers) : server.high_availability.enabled ? 2 : 1
          if coalesce(server.virtual_network, local.default_virtual_network) == network_key
        ]) <= pow(2, 32 - tonumber(split("/", var.virtual_networks[network_key].subnets["mysql"].cidr)[1])) - 5,
        false
      )
    ])
    error_message = "The mysql subnet is too small for the mysql_servers in its virtual network: each server needs one address, or two with high availability, and Azure reserves five addresses per subnet."
  }
}

variable "app_service_plans" {
  description = "App Service Plans keyed by a stable logical name, the only place App Service Plan NN values are set. Web Apps, Function Apps and Logic Apps select a plan through their service_plan key, and several apps can share one plan (they then share its compute and scale together). Basic, Standard and Premium SKUs host Web Apps; Elastic Premium (EP1-EP3) hosts Function Apps; Workflow Standard (WS1-WS3, Windows only) hosts Logic Apps (Standard), so a plan never mixes app types. Every app on a plan must match its os_type. Names follow M-AZU-ASP-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>; sequence is the two-digit NN and must be unique per plan. A plan no app uses is still billed, so Terraform warns about it. Defaults to none."
  type = map(object({
    sequence = optional(string, "00")
    os_type  = optional(string, "Linux")
    sku_name = optional(string, "B1")
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key in keys(var.app_service_plans) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "app_service_plans keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition     = alltrue([for plan in values(var.app_service_plans) : can(regex("^[0-9]{2}$", plan.sequence))])
    error_message = "Every app_service_plans sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for plan in values(var.app_service_plans) : plan.sequence])) == length(var.app_service_plans)
    error_message = "Every app_service_plans entry needs a unique sequence because App Service Plan names must be unique. Current sequences: ${join(", ", [for key, plan in var.app_service_plans : "${key}=${plan.sequence}"])}."
  }

  validation {
    condition     = alltrue([for plan in values(var.app_service_plans) : contains(["Linux", "Windows"], plan.os_type)])
    error_message = "Every app_service_plans os_type must be Linux or Windows."
  }

  validation {
    condition = alltrue([
      for plan in values(var.app_service_plans) : contains([
        "B1", "B2", "B3",
        "S1", "S2", "S3",
        "P1v2", "P2v2", "P3v2",
        "P0v3", "P1v3", "P2v3", "P3v3",
        "P1mv3", "P2mv3", "P3mv3", "P4mv3", "P5mv3",
        "P0v4", "P1v4", "P2v4", "P3v4",
        "P1mv4", "P2mv4", "P3mv4", "P4mv4", "P5mv4",
        "EP1", "EP2", "EP3",
        "WS1", "WS2", "WS3"
      ], plan.sku_name)
    ])
    error_message = "Every app_service_plans sku_name must be a Basic, Standard or Premium SKU (for Web Apps), an Elastic Premium SKU EP1-EP3 (for Function Apps) or a Workflow Standard SKU WS1-WS3 (for Logic Apps)."
  }

  validation {
    condition     = alltrue([for plan in values(var.app_service_plans) : !startswith(plan.sku_name, "WS") || plan.os_type == "Windows"])
    error_message = "Workflow Standard (WS1-WS3) plans host Logic Apps (Standard), which run on Windows only; set os_type = \"Windows\". Plans: ${join(", ", [for key, plan in var.app_service_plans : "${key}=${plan.sku_name}/${plan.os_type}" if startswith(plan.sku_name, "WS")])}."
  }
}

variable "function_apps" {
  description = "Private Elastic Premium Function Apps keyed by a stable logical name. Defaults to none; add one entry per app. service_plan is the key of an Elastic Premium app_service_plans entry, which also sets the app's OS; several Function Apps can share one plan. Each entry creates its own host Storage Account with its content share and Private Endpoints (blob, file, queue and table on the storage account, sites on the app); every app joins the function_integration subnet of its virtual_network (default: the PRV VNet; apps on one plan must share it), where its Private Endpoints sit too. application_insights (default true) sends the app's telemetry to the shared Application Insights resource (see var.application_insights); set false to opt out. Names follow M-AZU-FUN-<BU>-<DPT>-<APP>-<ENV>-<REG>[-<sequence>] for the app (global <name>.azurewebsites.net; the standard defines no NN, so at most one app may leave sequence null) and mazusoa...<storage_sequence> for its host storage (unique across all storage accounts)."
  type = map(object({
    virtual_network      = optional(string)
    service_plan         = string
    sequence             = optional(string)
    storage_sequence     = optional(string, "00")
    application_insights = optional(bool, true)
    runtime = optional(object({
      name    = optional(string, "python")
      version = optional(string, "3.11")
    }), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for item in values(var.function_apps) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "function_integration") &&
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every function_apps virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list function_integration and private_endpoints; the app integrates with the first and its Private Endpoints sit in the second. VNets: ${join(", ", [for key, item in var.function_apps : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  validation {
    condition = alltrue([
      for key in keys(var.function_apps) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "function_apps keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for app in values(var.function_apps) :
      can(regex("^[0-9]{2}$", app.storage_sequence)) &&
      (app.sequence == null || can(regex("^[0-9]{2}$", app.sequence)))
    ])
    error_message = "Every function_apps storage_sequence must be two digits, for example 01, and every sequence null or two digits."
  }

  validation {
    condition     = length(distinct([for app in values(var.function_apps) : coalesce(app.sequence, "none")])) == length(var.function_apps)
    error_message = "Function App names are global, so every function_apps entry needs a unique sequence and at most one may leave it null. Current sequences: ${join(", ", [for key, app in var.function_apps : "${key}=${coalesce(app.sequence, "null")}"])}."
  }

  validation {
    condition     = alltrue([for app in values(var.function_apps) : contains(keys(var.app_service_plans), app.service_plan)])
    error_message = "Every function_apps service_plan must be a key in app_service_plans. Available plans: ${join(", ", keys(var.app_service_plans))}."
  }

  # This composition hosts Function Apps on Elastic Premium only (content share
  # over the VNet, pre-warmed instances); the Function host settings depend on it.
  validation {
    condition = alltrue([
      for app in values(var.function_apps) :
      startswith(try(var.app_service_plans[app.service_plan].sku_name, "EP"), "EP")
    ])
    error_message = "Every function_apps service_plan must be an Elastic Premium plan (sku_name EP1, EP2 or EP3). Plans per app: ${join(", ", [for key, app in var.function_apps : "${key}=${app.service_plan}(${try(var.app_service_plans[app.service_plan].sku_name, "missing")})"])}."
  }

  # Multi-plan subnet join, which lets several App Service Plans share the
  # integration subnet, requires a /26 or larger subnet.
  validation {
    condition = alltrue([
      for network_key in distinct([for app in values(var.function_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-")]) : (
        length(distinct([for app in values(var.function_apps) : app.service_plan if coalesce(app.virtual_network, local.default_virtual_network, "-") == network_key])) <= 1 ||
        try(tonumber(split("/", var.virtual_networks[network_key].subnets["function_integration"].cidr)[1]) <= 26, false)
      )
    ])
    error_message = "The function_integration subnet must be /26 or larger in a virtual network where Function Apps on more than one App Service Plan share it."
  }

  # An App Service Plan integrates with one VNet, so its apps share it.
  validation {
    condition = alltrue([
      for plan_key in distinct([for app in values(var.function_apps) : app.service_plan]) :
      length(distinct([for app in values(var.function_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-") if app.service_plan == plan_key])) == 1
    ])
    error_message = "Every function_apps entry on the same service_plan must use the same virtual_network, because an App Service Plan integrates with one virtual network. Apps: ${join(", ", [for key, app in var.function_apps : "${key}=${app.service_plan}@${coalesce(app.virtual_network, local.default_virtual_network, "none")}"])}."
  }
}

variable "logic_apps" {
  description = "Private Logic Apps (Standard) keyed by a stable logical name. Defaults to none; add one entry per app. service_plan is the key of a Windows Workflow Standard (WS1-WS3) app_service_plans entry; several Logic Apps can share one plan. Each entry creates its own host Storage Account with its content share and Private Endpoints (blob, file, queue and table on the storage account, sites on the app); every app joins the logic_app_integration subnet of its virtual_network (default: the PRV VNet; apps on one plan must share it; Microsoft recommends /26), and its Private Endpoints sit in the private_endpoints subnet. node_version is the Node.js major version for Inline Code actions (default 22) and app_settings adds workflow settings, for example parameters. application_insights (default true) sends the app's telemetry to the shared Application Insights resource (see var.application_insights); set false to opt out. Names follow M-AZU-LAP-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence> for the app (global <name>.azurewebsites.net; sequence must be unique per app) and mazusoa...<storage_sequence> for its host storage (unique across all storage accounts)."
  type = map(object({
    virtual_network      = optional(string)
    service_plan         = string
    sequence             = optional(string, "00")
    storage_sequence     = optional(string, "00")
    node_version         = optional(string, "22")
    app_settings         = optional(map(string), {})
    application_insights = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for item in values(var.logic_apps) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "logic_app_integration") &&
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every logic_apps virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list logic_app_integration and private_endpoints; the app integrates with the first and its Private Endpoints sit in the second. VNets: ${join(", ", [for key, item in var.logic_apps : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  validation {
    condition = alltrue([
      for key in keys(var.logic_apps) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "logic_apps keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition = alltrue([
      for app in values(var.logic_apps) :
      can(regex("^[0-9]{2}$", app.sequence)) && can(regex("^[0-9]{2}$", app.storage_sequence))
    ])
    error_message = "Every logic_apps sequence and storage_sequence must be two digits, for example 01."
  }

  validation {
    condition     = length(distinct([for app in values(var.logic_apps) : app.sequence])) == length(var.logic_apps)
    error_message = "Every logic_apps entry needs a unique sequence because Logic App names are global. Current sequences: ${join(", ", [for key, app in var.logic_apps : "${key}=${app.sequence}"])}."
  }

  validation {
    condition     = alltrue([for app in values(var.logic_apps) : contains(keys(var.app_service_plans), app.service_plan)])
    error_message = "Every logic_apps service_plan must be a key in app_service_plans. Available plans: ${join(", ", keys(var.app_service_plans))}."
  }

  # Logic Apps (Standard) run on Workflow Standard plans, which are Windows
  # only (app_service_plans enforces the OS).
  validation {
    condition = alltrue([
      for app in values(var.logic_apps) :
      startswith(try(var.app_service_plans[app.service_plan].sku_name, "WS"), "WS")
    ])
    error_message = "Every logic_apps service_plan must be a Workflow Standard plan (sku_name WS1, WS2 or WS3, os_type Windows). Plans per app: ${join(", ", [for key, app in var.logic_apps : "${key}=${app.service_plan}(${try(var.app_service_plans[app.service_plan].sku_name, "missing")})"])}."
  }

  # Multi-plan subnet join, which lets several App Service Plans share the
  # integration subnet, requires a /26 or larger subnet.
  validation {
    condition = alltrue([
      for network_key in distinct([for app in values(var.logic_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-")]) : (
        length(distinct([for app in values(var.logic_apps) : app.service_plan if coalesce(app.virtual_network, local.default_virtual_network, "-") == network_key])) <= 1 ||
        try(tonumber(split("/", var.virtual_networks[network_key].subnets["logic_app_integration"].cidr)[1]) <= 26, false)
      )
    ])
    error_message = "The logic_app_integration subnet must be /26 or larger in a virtual network where Logic Apps on more than one App Service Plan share it."
  }

  # An App Service Plan integrates with one VNet, so its apps share it.
  validation {
    condition = alltrue([
      for plan_key in distinct([for app in values(var.logic_apps) : app.service_plan]) :
      length(distinct([for app in values(var.logic_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-") if app.service_plan == plan_key])) == 1
    ])
    error_message = "Every logic_apps entry on the same service_plan must use the same virtual_network, because an App Service Plan integrates with one virtual network. Apps: ${join(", ", [for key, app in var.logic_apps : "${key}=${app.service_plan}@${coalesce(app.virtual_network, local.default_virtual_network, "none")}"])}."
  }
}

variable "web_apps" {
  description = "Private App Service Web Apps keyed by a stable logical name. Defaults to none; add one entry per app. service_plan is the key of a Basic, Standard or Premium app_service_plans entry whose os_type matches mode (Windows for windows, Linux for linux and container); several Web Apps can share one plan. Each entry creates its own Private Endpoint; every app joins the web_app_integration subnet of its virtual_network (default: the PRV VNet; apps on one plan must share it), where its Private Endpoint sits too. application_insights (default true) sends the app's telemetry to the shared Application Insights resource (see var.application_insights) and, in linux and windows mode, turns on the App Service agent; container images need their own Application Insights SDK or OpenTelemetry distro. Set false to opt out. Names follow M-AZU-APP-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence> (global <name>.azurewebsites.net); sequence must be unique per app."
  type = map(object({
    virtual_network      = optional(string)
    service_plan         = string
    sequence             = optional(string, "00")
    mode                 = optional(string, "linux")
    application_insights = optional(bool, true)
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
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for item in values(var.web_apps) : try(
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "web_app_integration") &&
        contains(keys(var.virtual_networks[coalesce(item.virtual_network, local.default_virtual_network)].subnets), "private_endpoints"),
      false)
    ])
    error_message = "Every web_apps virtual_network must be a virtual_networks key (default: the PRV VNet) whose subnets list web_app_integration and private_endpoints; the app integrates with the first and its Private Endpoint sits in the second. VNets: ${join(", ", [for key, item in var.web_apps : "${key}=${coalesce(item.virtual_network, local.default_virtual_network, "none")}"])}."
  }

  validation {
    condition = alltrue([
      for key in keys(var.web_apps) :
      can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", key)) && !strcontains(key, "--")
    ])
    error_message = "web_apps keys must be 1-12 lowercase alphanumeric or hyphen characters, start with a letter, end with a letter or digit, and not contain consecutive hyphens."
  }

  validation {
    condition     = alltrue([for app in values(var.web_apps) : can(regex("^[0-9]{2}$", app.sequence))])
    error_message = "Every web_apps sequence must be two digits, for example 00."
  }

  validation {
    condition     = length(distinct([for app in values(var.web_apps) : app.sequence])) == length(var.web_apps)
    error_message = "Every web_apps entry needs a unique sequence because Web App names are global. Current sequences: ${join(", ", [for key, app in var.web_apps : "${key}=${app.sequence}"])}."
  }

  validation {
    condition     = alltrue([for app in values(var.web_apps) : contains(keys(var.app_service_plans), app.service_plan)])
    error_message = "Every web_apps service_plan must be a key in app_service_plans. Available plans: ${join(", ", keys(var.app_service_plans))}."
  }

  validation {
    condition = alltrue([
      for app in values(var.web_apps) :
      !startswith(try(var.app_service_plans[app.service_plan].sku_name, "B1"), "EP") &&
      !startswith(try(var.app_service_plans[app.service_plan].sku_name, "B1"), "WS")
    ])
    error_message = "Every web_apps service_plan must be a Basic, Standard or Premium plan; Elastic Premium (EP) plans are reserved for Function Apps and Workflow Standard (WS) plans for Logic Apps. Plans per app: ${join(", ", [for key, app in var.web_apps : "${key}=${app.service_plan}(${try(var.app_service_plans[app.service_plan].sku_name, "missing")})"])}."
  }

  validation {
    condition = alltrue([
      for app in values(var.web_apps) :
      try(var.app_service_plans[app.service_plan].os_type == (app.mode == "windows" ? "Windows" : "Linux"), true)
    ])
    error_message = "Every web_apps mode must match its plan's os_type: windows needs a Windows plan, linux and container need a Linux plan. Apps: ${join(", ", [for key, app in var.web_apps : "${key}=${app.mode} on ${app.service_plan}(${try(var.app_service_plans[app.service_plan].os_type, "missing")})"])}."
  }

  # Multi-plan subnet join, which lets several App Service Plans share the
  # integration subnet, requires a /26 or larger subnet.
  validation {
    condition = alltrue([
      for network_key in distinct([for app in values(var.web_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-")]) : (
        length(distinct([for app in values(var.web_apps) : app.service_plan if coalesce(app.virtual_network, local.default_virtual_network, "-") == network_key])) <= 1 ||
        try(tonumber(split("/", var.virtual_networks[network_key].subnets["web_app_integration"].cidr)[1]) <= 26, false)
      )
    ])
    error_message = "The web_app_integration subnet must be /26 or larger in a virtual network where Web Apps on more than one App Service Plan share it."
  }

  # An App Service Plan integrates with one VNet, so its apps share it.
  validation {
    condition = alltrue([
      for plan_key in distinct([for app in values(var.web_apps) : app.service_plan]) :
      length(distinct([for app in values(var.web_apps) : coalesce(app.virtual_network, local.default_virtual_network, "-") if app.service_plan == plan_key])) == 1
    ])
    error_message = "Every web_apps entry on the same service_plan must use the same virtual_network, because an App Service Plan integrates with one virtual network. Apps: ${join(", ", [for key, app in var.web_apps : "${key}=${app.service_plan}@${coalesce(app.virtual_network, local.default_virtual_network, "none")}"])}."
  }
}

variable "tags" {
  description = "Additional tags merged with the required lab tags."
  type        = map(string)
  default     = {}
}
