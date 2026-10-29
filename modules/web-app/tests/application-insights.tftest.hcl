mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-web-test"
    }
  }
}

variables {
  name                      = "app-test"
  service_plan_name         = "asp-web-test"
  resource_group_name       = "rg-test"
  location                  = "swedencentral"
  virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web-app"
  app_settings = {
    CUSTOM_SETTING                        = "kept"
    APPLICATIONINSIGHTS_CONNECTION_STRING = "overridden"
  }
}

run "no_application_insights_by_default" {
  command = plan

  assert {
    condition = (
      azurerm_linux_web_app.this[0].app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] == "overridden" &&
      !contains(keys(azurerm_linux_web_app.this[0].app_settings), "APPLICATIONINSIGHTS_AUTHENTICATION_STRING") &&
      !contains(keys(azurerm_linux_web_app.this[0].app_settings), "ApplicationInsightsAgent_EXTENSION_VERSION")
    )
    error_message = "Without application_insights the module must add no telemetry settings."
  }
}

run "linux_agent" {
  command = plan

  variables {
    application_insights = { connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition = (
      azurerm_linux_web_app.this[0].app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      azurerm_linux_web_app.this[0].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "Authorization=AAD" &&
      azurerm_linux_web_app.this[0].app_settings["ApplicationInsightsAgent_EXTENSION_VERSION"] == "~3" &&
      azurerm_linux_web_app.this[0].app_settings["XDT_MicrosoftApplicationInsights_Mode"] == "recommended" &&
      azurerm_linux_web_app.this[0].app_settings["CUSTOM_SETTING"] == "kept"
    )
    error_message = "Linux code apps must get the connection and Entra strings, agent ~3, and keep other settings; telemetry settings win over app_settings."
  }
}

run "windows_agent" {
  command = plan

  variables {
    mode                 = "windows"
    application_insights = { connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition = (
      azurerm_windows_web_app.this[0].app_settings["ApplicationInsightsAgent_EXTENSION_VERSION"] == "~2" &&
      azurerm_windows_web_app.this[0].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "Authorization=AAD"
    )
    error_message = "Windows apps must use agent ~2."
  }
}

run "container_without_agent" {
  command = plan

  variables {
    mode = "container"
    application_insights = {
      connection_string    = "InstrumentationKey=00000000-0000-0000-0000-000000000000"
      entra_authentication = false
    }
  }

  assert {
    condition = (
      azurerm_linux_web_app.this[0].app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      !contains(keys(azurerm_linux_web_app.this[0].app_settings), "APPLICATIONINSIGHTS_AUTHENTICATION_STRING") &&
      !contains(keys(azurerm_linux_web_app.this[0].app_settings), "ApplicationInsightsAgent_EXTENSION_VERSION") &&
      azurerm_linux_web_app.this[0].app_settings["WEBSITES_PORT"] == "80"
    )
    error_message = "Container mode must get only the connection settings, without the App Service agent."
  }
}
