mock_provider "azurerm" {}

variables {
  name                = "rt-test"
  resource_group_name = "rg-test"
  location            = "swedencentral"
  subnet_ids = {
    compute = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/Compute"
  }
  routes = {
    default-to-firewall = {
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = "10.0.0.4"
    }
  }
}

run "associates_each_subnet" {
  command = plan

  assert {
    condition = (
      length(azurerm_subnet_route_table_association.this) == 1 &&
      azurerm_subnet_route_table_association.this["compute"].subnet_id == var.subnet_ids["compute"] &&
      azurerm_route.this["default-to-firewall"].next_hop_in_ip_address == "10.0.0.4"
    )
    error_message = "Every subnet_ids entry must get one association, with the configured routes."
  }
}

# Azure can return subnet IDs with different casing; the association is
# replaced only when the lowercase ID changes.
run "tracks_subnet_id_case_insensitively" {
  command = plan

  assert {
    condition = (
      terraform_data.subnet_id["compute"].input == "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-test/providers/microsoft.network/virtualnetworks/vnet-test/subnets/compute"
    )
    error_message = "The replacement trigger must hold the lowercase subnet ID."
  }
}

run "reject_appliance_route_without_next_hop" {
  command = plan

  variables {
    routes = {
      default-to-firewall = {
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "VirtualAppliance"
      }
    }
  }

  expect_failures = [var.routes]
}

run "reject_next_hop_for_internet_route" {
  command = plan

  variables {
    routes = {
      internet = {
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "Internet"
        next_hop_in_ip_address = "10.0.0.4"
      }
    }
  }

  expect_failures = [var.routes]
}

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_invalid_next_hop_type" {
#   command = plan
#
#   variables {
#     routes = {
#       bad = {
#         address_prefix = "10.1.0.0/16"
#         next_hop_type  = "Firewall"
#       }
#     }
#   }
#
#   expect_failures = [var.routes]
# }
