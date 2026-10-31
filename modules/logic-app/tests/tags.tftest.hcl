mock_provider "azurerm" {
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-logic-test"
    }
  }
}

variables {
  name                       = "logic-test"
  service_plan_name          = "asp-logic-test"
  resource_group_name        = "rg-test"
  location                   = "swedencentral"
  storage_account_name       = "stlogictest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "logic-app-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/logic"
}

# The Azure portal adds the hidden-link tag; the first run puts it in state
# the way the portal leaves it.
run "with_portal_tag" {
  variables {
    tags = {
      owner                                    = "team-a"
      "hidden-link: /app-insights-resource-id" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/microsoft.insights/components/appi-test"
    }
  }
}

run "keeps_portal_tag" {
  variables {
    tags = { owner = "team-b" }
  }

  assert {
    condition = (
      azurerm_logic_app_standard.this.tags["hidden-link: /app-insights-resource-id"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/microsoft.insights/components/appi-test" &&
      azurerm_logic_app_standard.this.tags["owner"] == "team-b"
    )
    error_message = "The portal's hidden-link tag must be left alone while other tag changes still apply."
  }
}
