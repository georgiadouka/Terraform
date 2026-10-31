locals {
  service_plan_id = var.service_plan_name == null ? var.service_plan_id : azurerm_service_plan.this[0].id

  application_insights_settings = var.application_insights == null ? {} : merge(
    { APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights.connection_string },
    var.application_insights.entra_authentication ? { APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD" } : {}
  )

  # The provider adds AzureWebJobsStorage, the content share settings,
  # FUNCTIONS_EXTENSION_VERSION, APP_KIND and the Workflows extension bundle.
  # Logic Apps require the dotnet worker runtime and, on Windows, a Node.js
  # version for Inline Code actions.
  app_settings = merge(
    var.app_settings,
    {
      FUNCTIONS_WORKER_RUNTIME     = "dotnet"
      WEBSITE_NODE_DEFAULT_VERSION = "~${var.node_version}"
      WEBSITE_DNS_SERVER           = "168.63.129.16"
    },
    local.application_insights_settings
  )
}

# Workflow Standard plans run Logic Apps on Windows only.
resource "azurerm_service_plan" "this" {
  count = var.service_plan_name == null ? 0 : 1

  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = var.service_plan_sku_name
  tags                = var.tags
}

resource "azurerm_logic_app_standard" "this" {
  name                                     = var.name
  resource_group_name                      = var.resource_group_name
  location                                 = var.location
  app_service_plan_id                      = local.service_plan_id
  version                                  = "~4"
  storage_account_name                     = var.storage_account_name
  storage_account_access_key               = var.storage_account_access_key
  storage_account_share_name               = var.content_share_name
  vnet_content_share_enabled               = true
  virtual_network_subnet_id                = var.virtual_network_subnet_id
  public_network_access                    = "Disabled"
  https_only                               = true
  client_affinity_enabled                  = false
  ftp_publish_basic_authentication_enabled = false
  scm_publish_basic_authentication_enabled = false
  app_settings                             = local.app_settings
  tags                                     = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    dotnet_framework_version  = "v8.0"
    ftps_state                = "Disabled"
    http2_enabled             = true
    min_tls_version           = "1.2"
    scm_min_tls_version       = "1.2"
    use_32_bit_worker_process = false
    vnet_route_all_enabled    = true
  }

  lifecycle {
    # The Azure portal adds this tag to link the app to its Application
    # Insights resource; every other tag stays managed.
    ignore_changes = [tags["hidden-link: /app-insights-resource-id"]]
  }
}
