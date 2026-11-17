mock_provider "azurerm" {
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-func-test"
    }
  }
}

variables {
  name                       = "func-test"
  service_plan_name          = "asp-func-test"
  resource_group_name        = "rg-test"
  location                   = "swedencentral"
  storage_account_name       = "stfunctest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "function-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
}

# The Azure portal adds the hidden-link tag; the first runs put it in state
# the way the portal leaves it.
run "linux_with_portal_tag" {
  variables {
    tags = {
      owner                                    = "team-a"
      "hidden-link: /app-insights-resource-id" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/microsoft.insights/components/appi-test"
    }
  }
}

run "linux_keeps_portal_tag" {
  variables {
    tags = { owner = "team-b" }
  }

  assert {
    condition = (
      azurerm_linux_function_app.this[0].tags["hidden-link: /app-insights-resource-id"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/microsoft.insights/components/appi-test" &&
      azurerm_linux_function_app.this[0].tags["owner"] == "team-b"
    )
    error_message = "The portal's hidden-link tag must be left alone while other tag changes still apply."
  }
}

run "windows_with_portal_tag" {
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet-isolated", version = "8.0" }
    tags = {
      owner                                    = "team-a"
      "hidden-link: /app-insights-resource-id" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/microsoft.insights/components/appi-test"
    }
  }
}

run "windows_keeps_portal_tag" {
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet-isolated", version = "8.0" }
    tags    = { owner = "team-b" }
  }

  assert {
    condition = (
      contains(keys(azurerm_windows_function_app.this[0].tags), "hidden-link: /app-insights-resource-id") &&
      azurerm_windows_function_app.this[0].tags["owner"] == "team-b"
    )
    error_message = "The portal's hidden-link tag must be left alone while other tag changes still apply."
  }
}
