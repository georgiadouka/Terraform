variable "name" {
  description = "App Service Web App name."
  type        = string
}

variable "service_plan_name" {
  description = "App Service plan name."
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

variable "virtual_network_subnet_id" {
  description = "Regional VNet integration subnet ID."
  type        = string
}

variable "mode" {
  description = "Web App hosting mode: linux, windows, or container."
  type        = string
  default     = "linux"

  validation {
    condition     = contains(["linux", "windows", "container"], var.mode)
    error_message = "mode must be linux, windows, or container."
  }
}

variable "service_plan_sku_name" {
  description = "App Service plan SKU supporting Private Link and regional VNet integration."
  type        = string
  default     = "B1"

  validation {
    condition = contains([
      "B1", "B2", "B3",
      "S1", "S2", "S3",
      "P1v2", "P2v2", "P3v2",
      "P0v3", "P1v3", "P2v3", "P3v3",
      "P1mv3", "P2mv3", "P3mv3", "P4mv3", "P5mv3",
      "P0v4", "P1v4", "P2v4", "P3v4",
      "P1mv4", "P2mv4", "P3mv4", "P4mv4", "P5mv4"
    ], var.service_plan_sku_name)
    error_message = "service_plan_sku_name must be a Basic, Standard, or Premium App Service SKU that supports Private Link and VNet integration."
  }
}

variable "runtime" {
  description = "Code runtime used by linux or windows mode. Container mode ignores this setting."
  type = object({
    name    = optional(string, "node")
    version = optional(string, "22")
  })
  default  = {}
  nullable = false

  # Exact runtime-version allowlists are temporarily disabled because Azure
  # lifecycle support changes independently from this module.
  /*
  validation {
    condition = (
      var.mode == "container" ||
      var.mode == "linux" && contains(lookup({
        node   = ["18", "20", "22", "24"]
        python = ["3.9", "3.10", "3.11", "3.12", "3.13"]
        dotnet = ["6.0", "7.0", "8.0", "9.0"]
      }, var.runtime.name, []), var.runtime.version) ||
      var.mode == "windows" && contains(lookup({
        node   = ["18", "20", "22", "24"]
        dotnet = ["6.0", "7.0", "8.0", "9.0"]
      }, var.runtime.name, []), var.runtime.version)
    )
    error_message = "runtime must select a supported runtime/version for the chosen mode: Linux supports node, python, and dotnet; Windows supports node and dotnet."
  }
  */

  validation {
    condition = (
      var.mode == "container" ||
      trimspace(var.runtime.version) != "" &&
      (
        var.mode == "linux" && contains(["node", "python", "dotnet"], var.runtime.name) ||
        var.mode == "windows" && contains(["node", "dotnet"], var.runtime.name)
      )
    )
    error_message = "runtime must select a language supported for the chosen mode and a nonempty version: Linux supports node, python, and dotnet; Windows supports node and dotnet."
  }
}

variable "container" {
  description = "Linux container image settings used by container mode."
  type = object({
    registry_url = optional(string, "https://mcr.microsoft.com")
    image_name   = optional(string, "appsvc/staticsite:latest")
    port         = optional(number, 80)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      can(regex("^https://[^/]+/?$", var.container.registry_url)) &&
      trimspace(var.container.image_name) != "" &&
      var.container.port >= 1 &&
      var.container.port <= 65535 &&
      var.container.port == floor(var.container.port)
    )
    error_message = "container requires an HTTPS registry_url, a non-empty image_name, and a whole-number port from 1 to 65535."
  }
}

variable "app_settings" {
  description = "Additional Web App settings."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to Web App resources."
  type        = map(string)
  default     = {}
}

locals {
  os_type = var.mode == "windows" ? "Windows" : "Linux"
  app_settings = merge(
    var.app_settings,
    var.mode == "container" ? {
      WEBSITES_PORT = tostring(var.container.port)
    } : {}
  )
}

resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = local.os_type
  sku_name            = var.service_plan_sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  count = var.mode == "windows" ? 0 : 1

  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.this.id
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  public_network_access_enabled                  = false
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  app_settings                                   = local.app_settings
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on               = true
    ftps_state              = "Disabled"
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    vnet_route_all_enabled  = true

    application_stack {
      docker_image_name   = var.mode == "container" ? var.container.image_name : null
      docker_registry_url = var.mode == "container" ? var.container.registry_url : null
      dotnet_version      = var.mode == "linux" && var.runtime.name == "dotnet" ? var.runtime.version : null
      node_version        = var.mode == "linux" && var.runtime.name == "node" ? "${var.runtime.version}-lts" : null
      python_version      = var.mode == "linux" && var.runtime.name == "python" ? var.runtime.version : null
    }
  }
}

resource "azurerm_windows_web_app" "this" {
  count = var.mode == "windows" ? 1 : 0

  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.this.id
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  public_network_access_enabled                  = false
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  app_settings                                   = local.app_settings
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on               = true
    ftps_state              = "Disabled"
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    vnet_route_all_enabled  = true

    application_stack {
      current_stack  = var.runtime.name
      dotnet_version = var.runtime.name == "dotnet" ? "v${var.runtime.version}" : null
      node_version   = var.runtime.name == "node" ? "~${var.runtime.version}" : null
    }
  }
}

output "id" {
  description = "Web App ID."
  value       = one(concat(azurerm_linux_web_app.this[*].id, azurerm_windows_web_app.this[*].id))
}

output "default_hostname" {
  description = "Web App default hostname."
  value       = one(concat(azurerm_linux_web_app.this[*].default_hostname, azurerm_windows_web_app.this[*].default_hostname))
}

output "principal_id" {
  description = "Web App system-assigned managed identity principal ID."
  value       = one(concat(azurerm_linux_web_app.this[*].identity[0].principal_id, azurerm_windows_web_app.this[*].identity[0].principal_id))
}

output "mode" {
  description = "Selected Web App hosting mode."
  value       = var.mode
}

output "service_plan_id" {
  description = "App Service plan ID."
  value       = azurerm_service_plan.this.id
}
