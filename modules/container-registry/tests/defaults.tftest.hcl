mock_provider "azurerm" {
  mock_resource "azurerm_container_registry" {
    override_during = plan
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/crtest"
      login_server = "crtest.azurecr.io"
    }
  }
}

variables {
  name                = "crtest"
  resource_group_name = "rg-test"
  location            = "swedencentral"
}

run "premium_private_default" {
  command = plan

  assert {
    condition = (
      azurerm_container_registry.this.sku == "Premium" &&
      !azurerm_container_registry.this.admin_enabled &&
      !azurerm_container_registry.this.public_network_access_enabled &&
      output.login_server == "crtest.azurecr.io"
    )
    error_message = "The default registry must use Premium with admin and public network access disabled."
  }
}
