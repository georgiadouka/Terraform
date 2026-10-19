variable "environment_name" {
  description = "Container Apps environment name."
  type        = string
}

variable "app_name" {
  description = "Container App name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "infrastructure_subnet_id" {
  description = "Dedicated Container Apps infrastructure subnet ID."
  type        = string
}

variable "virtual_network_id" {
  description = "VNet ID linked to the environment private DNS zone."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "private_dns_link_name" {
  description = "Private DNS VNet link name."
  type        = string
}

variable "container_name" {
  description = "Container name within the Container App."
  type        = string
}

variable "image" {
  description = "Container image."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

  validation {
    condition     = trimspace(var.image) != ""
    error_message = "image must be nonempty."
  }
}

variable "target_port" {
  description = "Container ingress target port."
  type        = number
  default     = 80

  validation {
    condition = (
      var.target_port >= 1 &&
      var.target_port <= 65535 &&
      var.target_port == floor(var.target_port)
    )
    error_message = "target_port must be a whole number from 1 through 65535."
  }
}

variable "dedicated_workload_profile" {
  description = "Deprecated single-profile configuration. Retained to preserve existing profile names and use_for_app behavior; do not combine with the new map or selector."
  type = object({
    enabled               = optional(bool, false)
    name                  = optional(string)
    workload_profile_type = optional(string, "D4")
    minimum_count         = optional(number, 0)
    maximum_count         = optional(number, 3)
    use_for_app           = optional(bool, true)
  })
  default = {}

  validation {
    condition = (
      !var.dedicated_workload_profile.enabled ||
      (
        try(trimspace(var.dedicated_workload_profile.name), "") != "" &&
        try(length(trimspace(var.dedicated_workload_profile.name)), 16) <= 15 &&
        try(lower(trimspace(var.dedicated_workload_profile.name)), "") != "consumption" &&
        trimspace(var.dedicated_workload_profile.workload_profile_type) != "" &&
        lower(trimspace(var.dedicated_workload_profile.workload_profile_type)) != "consumption" &&
        var.dedicated_workload_profile.minimum_count >= 0 &&
        var.dedicated_workload_profile.minimum_count == floor(var.dedicated_workload_profile.minimum_count) &&
        var.dedicated_workload_profile.maximum_count >= 1 &&
        var.dedicated_workload_profile.maximum_count == floor(var.dedicated_workload_profile.maximum_count) &&
        var.dedicated_workload_profile.maximum_count >= var.dedicated_workload_profile.minimum_count
      )
    )
    error_message = "An enabled dedicated workload profile requires a non-Consumption name of 1-15 characters and integer node counts where minimum_count is at least zero and maximum_count is at least one and not less than minimum_count."
  }
}

variable "dedicated_workload_profiles" {
  description = "Dedicated workload profiles keyed by stable logical labels. Names are Azure profile names; node counts are not app replica counts."
  type = map(object({
    name                  = string
    workload_profile_type = optional(string, "D4")
    minimum_count         = optional(number, 0)
    maximum_count         = optional(number, 3)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key, profile in var.dedicated_workload_profiles : try(
        can(regex("^[a-z][a-z0-9-]{0,19}$", key)) &&
        key != "consumption" &&
        can(regex("^[A-Za-z][A-Za-z0-9-]{0,14}$", profile.name)) &&
        lower(profile.name) != "consumption" &&
        trimspace(profile.workload_profile_type) != "" &&
        lower(trimspace(profile.workload_profile_type)) != "consumption" &&
        profile.minimum_count >= 0 &&
        profile.minimum_count == floor(profile.minimum_count) &&
        profile.maximum_count >= 1 &&
        profile.maximum_count == floor(profile.maximum_count) &&
        profile.maximum_count >= profile.minimum_count,
        false
      )
    ])
    error_message = "Dedicated profiles require lowercase logical keys of 1-20 letters/digits/hyphens starting with a letter (not consumption), Azure names of 1-15 letters/digits/hyphens starting with a letter (not Consumption), a non-Consumption type, and integer node counts with 0 <= minimum_count <= maximum_count and maximum_count >= 1."
  }

  validation {
    condition = length(distinct([
      for profile in values(var.dedicated_workload_profiles) : try(lower(profile.name), "")
    ])) == length(var.dedicated_workload_profiles)
    error_message = "Dedicated workload profile Azure names must be unique, ignoring case."
  }

  validation {
    condition     = !var.dedicated_workload_profile.enabled || length(var.dedicated_workload_profiles) == 0
    error_message = "Do not combine an enabled legacy dedicated_workload_profile with dedicated_workload_profiles."
  }
}

variable "app_workload_profile" {
  description = "Consumption or a key in dedicated_workload_profiles. Null defaults to Consumption, except for legacy use_for_app placement."
  type        = string
  default     = null

  validation {
    condition = var.app_workload_profile == null ? true : (
      !var.dedicated_workload_profile.enabled &&
      (var.app_workload_profile == "Consumption" || contains(keys(var.dedicated_workload_profiles), var.app_workload_profile))
    )
    error_message = "app_workload_profile must be Consumption or a configured dedicated_workload_profiles key, and cannot be combined with an enabled legacy dedicated_workload_profile."
  }
}

variable "tags" {
  description = "Tags applied to Container Apps resources."
  type        = map(string)
  default     = {}
}

locals {
  dedicated_workload_profiles = merge(var.dedicated_workload_profiles, var.dedicated_workload_profile.enabled ? {
    legacy = {
      name                  = var.dedicated_workload_profile.name
      workload_profile_type = var.dedicated_workload_profile.workload_profile_type
      minimum_count         = var.dedicated_workload_profile.minimum_count
      maximum_count         = var.dedicated_workload_profile.maximum_count
    }
  } : {})
  dedicated_workload_profile_names = {
    for key, profile in local.dedicated_workload_profiles : key => profile.name
  }
  app_workload_profile = var.app_workload_profile != null ? var.app_workload_profile : (
    var.dedicated_workload_profile.enabled && var.dedicated_workload_profile.use_for_app ? "legacy" : "Consumption"
  )
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.environment_name
  resource_group_name            = var.resource_group_name
  location                       = var.location
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true
  public_network_access          = "Disabled"
  logs_destination               = "log-analytics"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  tags                           = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  dynamic "workload_profile" {
    for_each = local.dedicated_workload_profiles

    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }
}

resource "azurerm_private_dns_zone" "environment" {
  name                = azurerm_container_app_environment.this.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "environment" {
  name                  = var.private_dns_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.environment.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "environment_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.environment.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
  tags                = var.tags
}

resource "azurerm_private_dns_a_record" "environment_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.environment.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
  tags                = var.tags
}

resource "azurerm_container_app" "this" {
  name                         = var.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  workload_profile_name = (
    local.app_workload_profile == "Consumption"
    ? "Consumption"
    : lookup(local.dedicated_workload_profile_names, local.app_workload_profile, null)
  )
  tags = var.tags

  identity {
    type = "SystemAssigned"
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = var.target_port
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = var.container_name
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.environment,
    azurerm_private_dns_a_record.environment_apex,
    azurerm_private_dns_a_record.environment_wildcard
  ]
}

output "environment_id" {
  description = "Container Apps environment ID."
  value       = azurerm_container_app_environment.this.id
}

output "app_id" {
  description = "Container App ID."
  value       = azurerm_container_app.this.id
}

output "fqdn" {
  description = "Container App ingress FQDN."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "static_ip_address" {
  description = "Internal Container Apps environment IP address."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "dedicated_workload_profile_name" {
  description = "Deprecated: dedicated profile name when exactly one is configured, otherwise null. Use dedicated_workload_profile_names."
  value       = length(local.dedicated_workload_profile_names) == 1 ? one(values(local.dedicated_workload_profile_names)) : null
}

output "dedicated_workload_profile_names" {
  description = "Azure profile names keyed by logical label; the legacy single profile uses the key legacy."
  value       = local.dedicated_workload_profile_names
}

output "app_workload_profile_name" {
  description = "Workload profile used by the sample Container App."
  value       = azurerm_container_app.this.workload_profile_name
}
