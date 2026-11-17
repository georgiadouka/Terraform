mock_provider "azurerm" {}

variables {
  name                            = "pe-test-blob"
  private_service_connection_name = "pe-test-blob"
  private_dns_zone_group_name     = "default"
  resource_group_name             = "RG-TEST"
  location                        = "swedencentral"
  subnet_id                       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/PrivateEndpoints"
  private_connection_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Storage/storageAccounts/sttest"
  subresource_names               = ["blob"]
  private_dns_zone_ids            = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
}

run "create" {
  assert {
    condition = (
      azurerm_private_endpoint.this.subnet_id == var.subnet_id &&
      terraform_data.subnet_id.input == lower(var.subnet_id)
    )
    error_message = "The endpoint must use the configured subnet, and the replacement trigger must hold the lowercase subnet ID."
  }
}

# Azure can return the subnet ID with a lowercase resource group; the same
# subnet in different casing must not replace the endpoint.
run "keep_endpoint_when_only_casing_differs" {
  variables {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/PrivateEndpoints"
  }

  assert {
    condition     = output.id == run.create.id
    error_message = "A subnet ID that differs only in casing must not replace the Private Endpoint."
  }
}

run "replace_endpoint_on_subnet_move" {
  variables {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/virtualNetworks/vnet-other/subnets/PrivateEndpoints"
  }

  assert {
    condition = (
      output.id != run.create.id &&
      azurerm_private_endpoint.this.subnet_id == var.subnet_id
    )
    error_message = "Moving to a different subnet must replace the Private Endpoint in the new subnet."
  }
}
