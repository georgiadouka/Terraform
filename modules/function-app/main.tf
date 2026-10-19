variable "name" {
  description = "Function App name."
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

variable "tags" {
  description = "Tags applied to Function App resources."
  type        = map(string)
  default     = {}
}

locals {
  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME                 = var.runtime.name
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_access_key};EndpointSuffix=core.windows.net"
    WEBSITE_CONTENTOVERVNET                  = "1"
    WEBSITE_CONTENTSHARE                     = var.content_share_name
    WEBSITE_DNS_SERVER                       = "168.63.129.16"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE          = "true"
    }, var.runtime.name == "dotnet" && var.runtime.version == "8.0" ? {
    FUNCTIONS_INPROC_NET8_ENABLED = "1"
  } : {})
}

resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  sku_name            = var.service_plan_sku_name
  tags                = var.tags
}

moved {
  from = azurerm_linux_function_app.this
  to   = azurerm_linux_function_app.this[0]
}

resource "azurerm_linux_function_app" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.this.id
  storage_account_name                           = var.storage_account_name
  storage_account_access_key                     = var.storage_account_access_key
  functions_extension_version                    = "~4"
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  public_network_access_enabled                  = false
  https_only                                     = true
  builtin_logging_enabled                        = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  app_settings = local.app_settings

  site_config {
    always_on               = true
    ftps_state              = "Disabled"
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    use_32_bit_worker       = false
    vnet_route_all_enabled  = true

    application_stack {
      python_version              = var.runtime.name == "python" ? var.runtime.version : null
      node_version                = var.runtime.name == "node" ? var.runtime.version : null
      dotnet_version              = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? var.runtime.version : null
      use_dotnet_isolated_runtime = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? var.runtime.name == "dotnet-isolated" : null
      java_version                = var.runtime.name == "java" ? var.runtime.version : null
      powershell_core_version     = var.runtime.name == "powershell" ? var.runtime.version : null
    }
  }
}

resource "azurerm_windows_function_app" "this" {
  count = var.os_type == "Windows" ? 1 : 0

  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.this.id
  storage_account_name                           = var.storage_account_name
  storage_account_access_key                     = var.storage_account_access_key
  functions_extension_version                    = "~4"
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  public_network_access_enabled                  = false
  https_only                                     = true
  builtin_logging_enabled                        = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags
  app_settings                                   = local.app_settings

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on               = true
    ftps_state              = "Disabled"
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    use_32_bit_worker       = false
    vnet_route_all_enabled  = true

    application_stack {
      dotnet_version              = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? "v${var.runtime.version}" : null
      use_dotnet_isolated_runtime = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? var.runtime.name == "dotnet-isolated" : null
      node_version                = var.runtime.name == "node" ? "~${var.runtime.version}" : null
      java_version                = var.runtime.name == "java" ? (var.runtime.version == "8" ? "1.8" : var.runtime.version) : null
      powershell_core_version     = var.runtime.name == "powershell" ? var.runtime.version : null
    }
  }
}

output "id" {
  description = "Function App ID."
  value       = one(concat(azurerm_linux_function_app.this[*].id, azurerm_windows_function_app.this[*].id))
}

output "default_hostname" {
  description = "Function App default hostname."
  value       = one(concat(azurerm_linux_function_app.this[*].default_hostname, azurerm_windows_function_app.this[*].default_hostname))
}

output "principal_id" {
  description = "Function App system-assigned managed identity principal ID."
  value       = one(concat(azurerm_linux_function_app.this[*].identity[0].principal_id, azurerm_windows_function_app.this[*].identity[0].principal_id))
}

output "os_type" {
  description = "Selected Function App hosting OS."
  value       = var.os_type
}
