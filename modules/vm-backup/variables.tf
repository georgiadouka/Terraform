variable "name" {
  description = "Recovery Services vault name: 2-50 letters, digits and hyphens, starting with a letter."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]{1,49}$", var.name))
    error_message = "name must be 2-50 letters, digits or hyphens and start with a letter."
  }
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "storage_mode_type" {
  description = "Vault storage redundancy: GeoRedundant, ZoneRedundant or LocallyRedundant. Azure rejects a change once the vault holds a protected item."
  type        = string
  default     = "ZoneRedundant"
  nullable    = false

  validation {
    condition     = contains(["GeoRedundant", "ZoneRedundant", "LocallyRedundant"], var.storage_mode_type)
    error_message = "storage_mode_type must be GeoRedundant, ZoneRedundant or LocallyRedundant."
  }
}

variable "cross_region_restore_enabled" {
  description = "Allow restores in the paired region. Needs GeoRedundant storage; once true, setting it back to false replaces the vault."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.cross_region_restore_enabled || var.storage_mode_type == "GeoRedundant"
    error_message = "cross_region_restore_enabled needs storage_mode_type = \"GeoRedundant\"."
  }
}

variable "public_network_access_enabled" {
  description = "Allow vault access from public networks. Azure VM backup and full-VM restore use the Azure backbone either way; file-level restore needs public access or a vault Private Endpoint."
  type        = bool
  default     = false
  nullable    = false
}

variable "immutability" {
  description = "Optional vault immutability: Disabled, Unlocked or Locked. Locked cannot be undone and keeps recovery points until they expire. null leaves the Azure default."
  type        = string
  default     = null

  validation {
    condition     = var.immutability == null || contains(["Disabled", "Unlocked", "Locked"], coalesce(var.immutability, "-"))
    error_message = "immutability must be Disabled, Unlocked, Locked or null."
  }
}

variable "policies" {
  description = <<-EOT
    Enhanced (V2) VM backup policies keyed by a stable logical name; name is the policy name in the vault.
    frequency is Daily (default), Hourly or Weekly, starting at time (HH:00 or HH:30) in timezone (default UTC).
    Hourly needs hour_interval (4, 6, 8 or 12) and hour_duration (4-24, a multiple of hour_interval); Weekly needs weekdays and retention_weekly.
    instant_restore_retention_days keeps snapshots for fast restore: 1-30 days, default 7 (Weekly: must be 5, the default).
    retention_daily is the number of daily recovery points (7-9999, default 30) and is not used by Weekly policies.
    retention_monthly and retention_yearly take either weekdays and weeks, or days and/or include_last_days.
  EOT
  type = map(object({
    name                           = string
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
  }))
  nullable = false

  validation {
    condition     = length(var.policies) > 0
    error_message = "policies must contain at least one policy."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) :
      can(regex("^[A-Za-z][A-Za-z0-9_-]{2,149}$", policy.name)) &&
      trimspace(policy.timezone) != "" &&
      contains(["Daily", "Hourly", "Weekly"], policy.frequency) &&
      can(regex("^([01][0-9]|2[0-3]):(00|30)$", policy.time))
    ])
    error_message = "Every policy needs a name of 3-150 letters, digits, hyphens or underscores starting with a letter, a timezone, frequency Daily, Hourly or Weekly, and a time of HH:00 or HH:30."
  }

  validation {
    condition     = length(distinct([for policy in values(var.policies) : lower(policy.name)])) == length(var.policies)
    error_message = "Policy names must be unique within the vault."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) : policy.frequency == "Hourly" ? try(
        contains([4, 6, 8, 12], policy.hour_interval) &&
        policy.hour_duration >= 4 && policy.hour_duration <= 24 &&
        policy.hour_duration % policy.hour_interval == 0,
        false
      ) : policy.hour_interval == null && policy.hour_duration == null
    ])
    error_message = "Hourly policies need hour_interval 4, 6, 8 or 12 and hour_duration 4-24 that is a multiple of hour_interval; other frequencies must not set them."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) : policy.frequency == "Weekly" ? (
        length(policy.weekdays) > 0 &&
        policy.retention_weekly != null &&
        policy.retention_daily == null
      ) : length(policy.weekdays) == 0
    ])
    error_message = "Weekly policies need weekdays and retention_weekly and must not set retention_daily; Daily and Hourly policies must not set weekdays."
  }

  validation {
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for day in concat(
          policy.weekdays,
          try(policy.retention_weekly.weekdays, []),
          try(policy.retention_monthly.weekdays, []),
          try(policy.retention_yearly.weekdays, [])
        ) : contains(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], day)
      ]
    ]))
    error_message = "weekdays values must be Sunday, Monday, Tuesday, Wednesday, Thursday, Friday or Saturday."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) : policy.instant_restore_retention_days == null ? true : try(
        policy.instant_restore_retention_days >= 1 &&
        policy.instant_restore_retention_days <= 30 &&
        floor(policy.instant_restore_retention_days) == policy.instant_restore_retention_days &&
        (policy.frequency != "Weekly" || policy.instant_restore_retention_days == 5),
        false
      )
    ])
    error_message = "instant_restore_retention_days must be a whole number from 1 to 30, and 5 for Weekly policies."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) : policy.retention_daily == null ? true : try(
        policy.retention_daily >= 7 &&
        policy.retention_daily <= 9999 &&
        floor(policy.retention_daily) == policy.retention_daily,
        false
      )
    ])
    error_message = "retention_daily must be a whole number from 7 to 9999."
  }

  validation {
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for retention in [policy.retention_weekly, policy.retention_monthly, policy.retention_yearly] :
        retention == null ? true : try(
          retention.count >= 1 && retention.count <= 9999 && floor(retention.count) == retention.count,
          false
        )
      ]
    ]))
    error_message = "retention_weekly, retention_monthly and retention_yearly count must be a whole number from 1 to 9999."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) :
      policy.retention_weekly == null ? true : length(try(policy.retention_weekly.weekdays, [])) > 0
    ])
    error_message = "retention_weekly needs at least one weekday."
  }

  validation {
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for retention in [policy.retention_monthly, policy.retention_yearly] : retention == null ? true : try(
          (
            (
              length(retention.weekdays) > 0 && length(retention.weeks) > 0 &&
              length(retention.days) == 0 && !retention.include_last_days
              ) || (
              length(retention.weekdays) == 0 && length(retention.weeks) == 0 &&
              (length(retention.days) > 0 || retention.include_last_days)
            )
          ) &&
          alltrue([for week in retention.weeks : contains(["First", "Second", "Third", "Fourth", "Last"], week)]) &&
          alltrue([for day in retention.days : day >= 1 && day <= 31 && floor(day) == day]),
          false
        )
      ]
    ]))
    error_message = "retention_monthly and retention_yearly need either weekdays and weeks (First, Second, Third, Fourth or Last), or days (1-31) and/or include_last_days."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) : policy.retention_yearly == null ? true : (
        length(policy.retention_yearly.months) > 0 &&
        alltrue([
          for month in policy.retention_yearly.months :
          contains(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], month)
        ])
      )
    ])
    error_message = "retention_yearly needs at least one month, written in full (January ... December)."
  }
}

variable "protected_virtual_machines" {
  description = "Virtual machines to back up, keyed by a stable logical name so the set is known at plan time: id is the VM resource ID and policy a policies key."
  type = map(object({
    id     = string
    policy = string
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for vm in values(var.protected_virtual_machines) : contains(keys(var.policies), vm.policy)])
    error_message = "Every protected_virtual_machines policy must be a policies key. Policies: ${join(", ", keys(var.policies))}."
  }
}

variable "tags" {
  description = "Tags applied to the Recovery Services vault."
  type        = map(string)
  default     = {}
}
