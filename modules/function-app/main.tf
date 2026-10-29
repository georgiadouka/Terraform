locals {
  service_plan_id = var.service_plan_name == null ? var.service_plan_id : azurerm_service_plan.this[0].id

  # The connection string goes through site_config: the provider reads the
  # APPLICATIONINSIGHTS_CONNECTION_STRING app setting back into
  # site_config.application_insights_connection_string, so setting it in
  # app_settings would show a change on every plan.
  application_insights_connection_string = try(var.application_insights.connection_string, null)

  application_insights_settings = var.application_insights == null ? {} : (
    var.application_insights.entra_authentication ? { APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD" } : {}
  )

  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME                 = var.runtime.name
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_access_key};EndpointSuffix=core.windows.net"
    WEBSITE_CONTENTOVERVNET                  = "1"
    WEBSITE_CONTENTSHARE                     = var.content_share_name
    WEBSITE_DNS_SERVER                       = "168.63.129.16"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE          = "true"
    }, var.runtime.name == "dotnet" && var.runtime.version == "8.0" ? {
    FUNCTIONS_INPROC_NET8_ENABLED = "1"
  } : {}, local.application_insights_settings)
}

resource "azurerm_service_plan" "this" {
  count = var.service_plan_name == null ? 0 : 1

  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  sku_name            = var.service_plan_sku_name
  tags                = var.tags
}

resource "azurerm_linux_function_app" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = local.service_plan_id
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
    always_on                              = true
    application_insights_connection_string = local.application_insights_connection_string
    ftps_state                             = "Disabled"
    http2_enabled                          = true
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    use_32_bit_worker                      = false
    vnet_route_all_enabled                 = true

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
  service_plan_id                                = local.service_plan_id
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
    always_on                              = true
    application_insights_connection_string = local.application_insights_connection_string
    ftps_state                             = "Disabled"
    http2_enabled                          = true
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    use_32_bit_worker                      = false
    vnet_route_all_enabled                 = true

    application_stack {
      dotnet_version              = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? "v${var.runtime.version}" : null
      use_dotnet_isolated_runtime = contains(["dotnet", "dotnet-isolated"], var.runtime.name) ? var.runtime.name == "dotnet-isolated" : null
      node_version                = var.runtime.name == "node" ? "~${var.runtime.version}" : null
      java_version                = var.runtime.name == "java" ? (var.runtime.version == "8" ? "1.8" : var.runtime.version) : null
      powershell_core_version     = var.runtime.name == "powershell" ? var.runtime.version : null
    }
  }
}
