mock_provider "azurerm" {}

variables {
  name                = "nsg-test"
  resource_group_name = "rg-test"
  location            = "swedencentral"
  subnet_ids = {
    compute = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/Compute"
  }
  security_rules = {
    allow-https = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }
}

run "associates_each_subnet" {
  command = plan

  assert {
    condition = (
      length(azurerm_subnet_network_security_group_association.this) == 1 &&
      azurerm_subnet_network_security_group_association.this["compute"].subnet_id == var.subnet_ids["compute"] &&
      azurerm_network_security_rule.this["allow-https"].source_port_range == "*"
    )
    error_message = "Every subnet_ids entry must get one association, and unset port ranges must default to *."
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

run "reject_duplicate_priority" {
  command = plan

  variables {
    security_rules = {
      first = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
      second = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    }
  }

  expect_failures = [var.security_rules]
}

run "reject_both_address_forms" {
  command = plan

  variables {
    security_rules = {
      mixed = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_address_prefixes    = ["10.0.0.0/24"]
        destination_address_prefix = "*"
      }
    }
  }

  expect_failures = [var.security_rules]
}
