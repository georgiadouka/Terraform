mock_provider "azurerm" {
  mock_resource "azurerm_private_endpoint" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateEndpoints/pe-test"
    }
  }
}

variables {
  resource_group_name = "rg-test"
  location            = "swedencentral"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/pe"
  storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest"
  endpoints = {
    blob = {
      name                            = "sttest-blob"
      private_service_connection_name = "sttest-blob"
      private_dns_zone_group_name     = "default"
      private_dns_zone_ids            = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
    }
    file = {
      name                            = "sttest-file"
      private_service_connection_name = "sttest-file"
      private_dns_zone_group_name     = "default"
      private_dns_zone_ids            = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"]
    }
  }
}

run "creates_only_requested_subresources" {
  command = plan

  assert {
    condition = (
      length(module.blob) == 1 &&
      length(module.file) == 1 &&
      length(module.queue) == 0 &&
      length(module.table) == 0 &&
      keys(output.ids) == ["blob", "file"]
    )
    error_message = "Only the requested storage subresources may get a Private Endpoint."
  }
}

run "creates_every_storage_subresource" {
  command = plan

  variables {
    endpoints = {
      for subresource in ["blob", "file", "queue", "table"] : subresource => {
        name                            = "sttest-${subresource}"
        private_service_connection_name = "sttest-${subresource}"
        private_dns_zone_group_name     = "default"
        private_dns_zone_ids            = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.${subresource}.core.windows.net"]
      }
    }
  }

  assert {
    condition     = keys(output.ids) == ["blob", "file", "queue", "table"]
    error_message = "Every storage subresource must get its own Private Endpoint."
  }
}

run "creates_nothing_without_endpoints" {
  command = plan

  variables {
    endpoints = {}
  }

  assert {
    condition     = output.ids == {}
    error_message = "An empty endpoints map must not create Private Endpoints."
  }
}

run "rejects_unsupported_subresource" {
  command = plan

  variables {
    endpoints = {
      dfs = {
        name                            = "sttest-dfs"
        private_service_connection_name = "sttest-dfs"
        private_dns_zone_group_name     = "default"
        private_dns_zone_ids            = []
      }
    }
  }

  expect_failures = [var.endpoints]
}
