locals {
  os_type         = var.mode == "windows" ? "Windows" : "Linux"
  service_plan_id = var.service_plan_name == null ? var.service_plan_id : azurerm_service_plan.this[0].id

  # Container images bring their own SDK, so the App Service agent is turned
  # on only for code deployments.
  application_insights_settings = var.application_insights == null ? {} : merge(
    { APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights.connection_string },
    var.application_insights.entra_authentication ? { APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD" } : {},
    var.mode == "container" ? {} : {
      ApplicationInsightsAgent_EXTENSION_VERSION = var.mode == "windows" ? "~2" : "~3"
      XDT_MicrosoftApplicationInsights_Mode      = "recommended"
    }
  )

  app_settings = merge(
    var.app_settings,
    var.mode == "container" ? {
      WEBSITES_PORT = tostring(var.container.port)
    } : {},
    local.application_insights_settings
  )
}

resource "azurerm_service_plan" "this" {
  count = var.service_plan_name == null ? 0 : 1

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
  service_plan_id                                = local.service_plan_id
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
  service_plan_id                                = local.service_plan_id
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
