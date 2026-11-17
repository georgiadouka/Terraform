variable "name" {
  description = "Application Insights resource name."
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

variable "workspace_id" {
  description = "ID of the Log Analytics workspace that stores the telemetry (workspace-based Application Insights)."
  type        = string
}

variable "application_type" {
  description = "Application Insights application type. Use web for App Service, Azure Functions and most server applications."
  type        = string
  default     = "web"
  nullable    = false

  # Disabled: azurerm validates this at plan time.
  # validation {
  #   condition     = contains(["web", "java", "MobileCenter", "Node.JS", "other", "phone", "store", "ios"], var.application_type)
  #   error_message = "application_type must be one of web, java, MobileCenter, Node.JS, other, phone, store or ios."
  # }
}

variable "local_authentication_enabled" {
  description = "Also accept telemetry sent with the instrumentation key alone (true) instead of only from Microsoft Entra identities (false). Entra identities need Monitoring Metrics Publisher, see metrics_publisher_principal_ids."
  type        = bool
  default     = false
  nullable    = false
}

variable "metrics_publisher_principal_ids" {
  description = "Service principal (managed identity) object IDs that receive Monitoring Metrics Publisher on the resource, keyed by a stable label known at plan time."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "tags" {
  description = "Tags applied to the Application Insights resource."
  type        = map(string)
  default     = {}
}
