mock_provider "azurerm" {}

variables {
  name                      = "peer-metlen-lab-test1-to-hub"
  resource_group_name       = "rg-test"
  virtual_network_name      = "vnet-test"
  remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
}

run "spoke_defaults" {
  command = plan

  assert {
    condition = (
      azurerm_virtual_network_peering.this.allow_virtual_network_access &&
      azurerm_virtual_network_peering.this.allow_forwarded_traffic &&
      !azurerm_virtual_network_peering.this.allow_gateway_transit &&
      !azurerm_virtual_network_peering.this.use_remote_gateways
    )
    error_message = "A peering should allow VNet access and forwarded traffic, without gateway transit, by default."
  }
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_invalid_remote_id" {
#   command = plan
#
#   variables {
#     remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub"
#   }
#
#   expect_failures = [var.remote_virtual_network_id]
# }

run "reject_transit_and_remote_gateways_together" {
  command = plan

  variables {
    allow_gateway_transit = true
    use_remote_gateways   = true
  }

  expect_failures = [var.use_remote_gateways]
}
