mock_provider "azurerm" {}

variables {
  name                       = "logic-appi-test"
  service_plan_name          = "asp-appi-test"
  resource_group_name        = "rg-appi-test"
  location                   = "swedencentral"
  storage_account_name       = "stappitest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "logic-app-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-appi-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/logic"
}

run "entra_authentication" {
  command = plan

  variables {
    application_insights = { connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition = (
      azurerm_logic_app_standard.this.app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      azurerm_logic_app_standard.this.app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "Authorization=AAD" &&
      azurerm_logic_app_standard.this.app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet"
    )
    error_message = "application_insights must add the connection string and the Entra authentication string to the managed settings."
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
      azurerm_logic_app_standard.this.app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] == "InstrumentationKey=00000000-0000-0000-0000-000000000000" &&
      !contains(keys(azurerm_logic_app_standard.this.app_settings), "APPLICATIONINSIGHTS_AUTHENTICATION_STRING")
    )
    error_message = "entra_authentication = false must omit the authentication string."
  }
}
