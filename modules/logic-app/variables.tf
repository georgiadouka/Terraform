variable "name" {
  description = "Logic App (Standard) name. The name is global (<name>.azurewebsites.net)."
  type        = string
}

variable "service_plan_name" {
  description = "Name of the Windows Workflow Standard App Service Plan this module creates. Set either service_plan_name, to create a dedicated plan, or service_plan_id, to run the app on an existing Windows Workflow Standard plan."
  type        = string
  default     = null
}

variable "service_plan_id" {
  description = "ID of an existing Windows Workflow Standard (WS1-WS3) App Service Plan to run the app on. Set either service_plan_id or service_plan_name; with service_plan_id, service_plan_sku_name is ignored."
  type        = string
  default     = null

  validation {
    condition     = (var.service_plan_name == null) != (var.service_plan_id == null)
    error_message = "Set exactly one of service_plan_name (create a plan) or service_plan_id (use an existing plan)."
  }
}

variable "service_plan_sku_name" {
  description = "Workflow Standard SKU of the plan this module creates: WS1, WS2 or WS3."
  type        = string
  default     = "WS1"
  nullable    = false

  validation {
    condition     = contains(["WS1", "WS2", "WS3"], var.service_plan_sku_name)
    error_message = "service_plan_sku_name must be WS1, WS2 or WS3."
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
  description = "Host storage account for workflow state, run history and app content. Reach it through blob, file, queue and table Private Endpoints."
  type        = string
}

variable "storage_account_access_key" {
  description = "Host storage account access key. Logic App Standard still needs a key for its content share."
  type        = string
  sensitive   = true
}

variable "content_share_name" {
  description = "Pre-created Azure Files share for the app content (WEBSITE_CONTENTSHARE). It must exist before the app, because the app reaches it over the virtual network."
  type        = string
}

variable "virtual_network_subnet_id" {
  description = "Regional VNet integration subnet ID, delegated to Microsoft.Web/serverFarms. Microsoft recommends /26."
  type        = string
}

variable "node_version" {
  description = "Node.js major version (WEBSITE_NODE_DEFAULT_VERSION, used by Inline Code actions), without the ~ prefix. 22 is the default; Microsoft reports XSLT map issues on 24, so test before moving."
  type        = string
  default     = "22"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]$", var.node_version))
    error_message = "node_version must be a plain two-digit Node.js major version, for example 22, without the ~ prefix."
  }
}

variable "app_settings" {
  description = "Additional app settings, for example workflow parameters and connection settings. Settings the module or the provider manage cannot be set here."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = length(setintersection(keys(var.app_settings), [
      "APP_KIND",
      "APPLICATIONINSIGHTS_AUTHENTICATION_STRING",
      "APPLICATIONINSIGHTS_CONNECTION_STRING",
      "AzureFunctionsJobHost__extensionBundle__id",
      "AzureFunctionsJobHost__extensionBundle__version",
      "AzureWebJobsStorage",
      "FUNCTIONS_EXTENSION_VERSION",
      "FUNCTIONS_WORKER_RUNTIME",
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING",
      "WEBSITE_CONTENTOVERVNET",
      "WEBSITE_CONTENTSHARE",
      "WEBSITE_DNS_SERVER",
      "WEBSITE_NODE_DEFAULT_VERSION",
      "WEBSITE_VNET_ROUTE_ALL",
    ])) == 0
    error_message = "app_settings must not set settings the module or the provider manage (runtime, storage, content share, networking and Application Insights). Use node_version and application_insights instead."
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
  description = "Tags applied to Logic App resources."
  type        = map(string)
  default     = {}
}
