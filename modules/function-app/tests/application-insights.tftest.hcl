mock_provider "azurerm" {}

variables {
  name                       = "func-appi-test"
  service_plan_name          = "asp-appi-test"
  resource_group_name        = "rg-appi-test"
  location                   = "swedencentral"
  storage_account_name       = "stappitest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "function-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-appi-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
}

run "no_application_insights_by_default" {
  command = plan

  assert {
    condition = (
      azurerm_linux_function_app.this[0].site_config[0].application_insights_connection_string == null &&
      !contains(keys(azurerm_linux_function_app.this[0].app_settings), "APPLICATIONINSIGHTS_AUTHENTICATION_STRING")
    )
    error_message = "Without application_insights the app must not get telemetry settings."
  }
}

run "linux_entra_authentication" {
  command = plan

  variables {
    application_insights = { connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition = (
      azurerm_linux_function_app.this[0].site_config[0].application_insights_connection_string == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      !contains(keys(azurerm_linux_function_app.this[0].app_settings), "APPLICATIONINSIGHTS_CONNECTION_STRING") &&
      azurerm_linux_function_app.this[0].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "Authorization=AAD" &&
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "python"
    )
    error_message = "application_insights must set the site_config connection string and add the Entra authentication string to the existing settings."
  }
}

run "windows_entra_authentication" {
  command = plan

  variables {
    os_type              = "Windows"
    runtime              = { name = "dotnet-isolated", version = "8.0" }
    application_insights = { connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition = (
      azurerm_windows_function_app.this[0].site_config[0].application_insights_connection_string == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      azurerm_windows_function_app.this[0].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "Authorization=AAD"
    )
    error_message = "Windows Function Apps must get the same telemetry settings."
  }
}

run "connection_string_only" {
  command = plan

  variables {
    application_insights = {
      connection_string    = "InstrumentationKey=00000000-0000-0000-0000-000000000000"
      entra_authentication = false
    }
  }

  assert {
    condition = (
      azurerm_linux_function_app.this[0].site_config[0].application_insights_connection_string == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      !contains(keys(azurerm_linux_function_app.this[0].app_settings), "APPLICATIONINSIGHTS_AUTHENTICATION_STRING")
    )
    error_message = "entra_authentication = false must omit the authentication string."
  }
}
