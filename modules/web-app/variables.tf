variable "name" {
  description = "App Service Web App name."
  type        = string
}

variable "service_plan_name" {
  description = "Name of the App Service Plan this module creates. Set either service_plan_name, to create a dedicated plan, or service_plan_id, to run the app on an existing plan whose OS matches mode."
  type        = string
  default     = null
}

variable "service_plan_id" {
  description = "ID of an existing App Service Plan to run the app on. Set either service_plan_id or service_plan_name; with service_plan_id, service_plan_sku_name is ignored."
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
