variable "name" {
  description = "Function App name."
  type        = string
}

variable "service_plan_name" {
  description = "Name of the Elastic Premium App Service Plan this module creates. Set either service_plan_name, to create a dedicated plan, or service_plan_id, to run the app on an existing Elastic Premium plan whose OS matches os_type."
  type        = string
  default     = null
}

variable "service_plan_id" {
  description = "ID of an existing Elastic Premium App Service Plan to run the app on. Set either service_plan_id or service_plan_name; with service_plan_id, service_plan_sku_name is ignored."
  type        = string
  default     = null

  validation {
    condition     = (var.service_plan_name == null) != (var.service_plan_id == null)
    error_message = "Set exactly one of service_plan_name (create a plan) or service_plan_id (use an existing plan)."
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

variable "storage_account_name" {
  description = "Function host storage account name."
  type        = string
}

variable "storage_account_access_key" {
  description = "Function host storage account access key."
  type        = string
  sensitive   = true
}

variable "content_share_name" {
  description = "Pre-created Azure Files share used for Function App content."
  type        = string
}

variable "virtual_network_subnet_id" {
  description = "Regional VNet integration subnet ID."
  type        = string
}

variable "service_plan_sku_name" {
  description = "Elastic Premium App Service plan SKU."
  type        = string
  default     = "EP1"

  validation {
    condition     = contains(["EP1", "EP2", "EP3"], var.service_plan_sku_name)
    error_message = "service_plan_sku_name must be EP1, EP2, or EP3 for this Elastic Premium Function App."
  }
}

variable "runtime" {
  description = "Functions language and plain version (for example node/22 or dotnet-isolated/8.0). Must match the OS and AzureRM stack schema; verify Azure lifecycle and regional support."
  type = object({
    name    = optional(string, "python")
    version = optional(string, "3.11")
  })
  default  = {}
  nullable = false

  # Exact runtime-version allowlists are temporarily disabled because Azure
  # lifecycle support changes independently from this module.
  /*
  validation {
    condition = var.os_type == "Windows" ? contains(lookup({
      dotnet          = ["8.0"]
      dotnet-isolated = ["6.0", "7.0", "8.0", "9.0", "10.0"]
      node            = ["12", "14", "16", "18", "20", "22", "24"]
      java            = ["8", "11", "17", "21", "25"]
      powershell      = ["7", "7.2", "7.4", "7.6"]
      }, var.runtime.name, []), var.runtime.version) : contains(lookup({
      python          = ["3.7", "3.8", "3.9", "3.10", "3.11", "3.12", "3.13", "3.14"]
      node            = ["12", "14", "16", "18", "20", "22", "24"]
      dotnet          = ["8.0"]
      dotnet-isolated = ["6.0", "7.0", "8.0", "9.0"]
      java            = ["8", "11", "17", "21", "25"]
      powershell      = ["7", "7.2", "7.4"]
    }, var.runtime.name, []), var.runtime.version)
    error_message = "runtime must select a language and plain version supported for the chosen OS. Python requires Linux; dotnet in-process requires 8.0. Set both name and version when changing language, without provider prefixes such as v or ~; verify Azure support before deployment."
  }
  */

  validation {
    condition = (
      trimspace(var.runtime.version) != "" &&
      (
        var.os_type == "Windows"
        ? contains(["dotnet", "dotnet-isolated", "node", "java", "powershell"], var.runtime.name)
        : contains(["python", "dotnet", "dotnet-isolated", "node", "java", "powershell"], var.runtime.name)
      ) &&
      (var.runtime.name != "dotnet" || var.runtime.version == "8.0")
    )
    error_message = "runtime must select a language supported for the chosen OS and a nonempty version. Python requires Linux, and dotnet in-process requires 8.0."
  }
}

variable "os_type" {
  description = "Function App and service plan OS: Linux or Windows. Changing OS requires app/plan recreation and redeploying code."
  type        = string
  default     = "Linux"
  nullable    = false

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "application_insights" {
  description = "Application Insights connection. null sends no telemetry. With entra_authentication (default), the app authenticates with its system-assigned identity, which needs Monitoring Metrics Publisher on the resource."
  type = object({
    connection_string    = string
    entra_authentication = optional(bool, true)
  })
  default   = null
  sensitive = true
}

variable "tags" {
  description = "Tags applied to Function App resources."
  type        = map(string)
  default     = {}
}
