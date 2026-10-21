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
