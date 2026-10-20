variable "environment_name" {
  description = "Container Apps environment name."
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

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID that receives the environment's logs. Several environments can share one workspace."
  type        = string
}

variable "private_dns_link_name" {
  description = "Private DNS VNet link name."
  type        = string
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
}

variable "apps" {
  description = "Container Apps in this environment, keyed by stable logical name. Names are Azure resource names; workload_profile is Consumption or a key in dedicated_workload_profiles."
  type = map(object({
    name             = string
    container_name   = string
    image            = optional(string, "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest")
    target_port      = optional(number, 80)
    workload_profile = optional(string, "Consumption")
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for app in values(var.apps) : try(trimspace(app.image) != "", false)
    ])
    error_message = "Every app image must be nonempty."
  }

  validation {
    condition = alltrue([
      for app in values(var.apps) : try(
        app.target_port >= 1 &&
        app.target_port <= 65535 &&
        app.target_port == floor(app.target_port),
        false
      )
    ])
    error_message = "Every app target_port must be a whole number from 1 through 65535."
  }

  validation {
    condition = alltrue([
      for app in values(var.apps) : try(
        app.workload_profile == "Consumption" || contains(keys(var.dedicated_workload_profiles), app.workload_profile),
        false
      )
    ])
    error_message = "Every app workload_profile must be Consumption or a configured dedicated_workload_profiles key."
  }

  validation {
    condition = alltrue([
      for app in values(var.apps) :
      can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", app.name)) && !strcontains(app.name, "--")
    ])
    error_message = "Every app name must be 2-32 lowercase alphanumeric or hyphen characters, start with a letter, end with an alphanumeric character, and not contain consecutive hyphens."
  }

  validation {
    condition     = length(distinct([for app in values(var.apps) : app.name])) == length(var.apps)
    error_message = "App names must be unique."
  }
}

variable "tags" {
  description = "Tags applied to Container Apps resources."
  type        = map(string)
  default     = {}
}

locals {
  dedicated_workload_profile_names = {
    for key, profile in var.dedicated_workload_profiles : key => profile.name
  }
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.environment_name
  resource_group_name            = var.resource_group_name
  location                       = var.location
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true
  public_network_access          = "Disabled"
  logs_destination               = "log-analytics"
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  tags                           = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  dynamic "workload_profile" {
    for_each = var.dedicated_workload_profiles

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
  for_each = var.apps

  name                         = each.value.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  workload_profile_name = (
    each.value.workload_profile == "Consumption"
    ? "Consumption"
    : lookup(local.dedicated_workload_profile_names, each.value.workload_profile, null)
  )
  tags = var.tags

  identity {
    type = "SystemAssigned"
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = each.value.target_port
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
      name   = each.value.container_name
      image  = each.value.image
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

output "environment_name" {
  description = "Container Apps environment name."
  value       = azurerm_container_app_environment.this.name
}

output "default_domain" {
  description = "Environment default domain, which is also the name of its private DNS zone."
  value       = azurerm_container_app_environment.this.default_domain
}

output "static_ip_address" {
  description = "Internal Container Apps environment IP address."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "dedicated_workload_profile_names" {
  description = "Azure profile names keyed by logical label."
  value       = local.dedicated_workload_profile_names
}

output "apps" {
  description = "Container Apps keyed by logical name."
  value = {
    for key, app in azurerm_container_app.this : key => {
      id                    = app.id
      name                  = app.name
      fqdn                  = app.ingress[0].fqdn
      workload_profile_name = app.workload_profile_name
    }
  }
}
