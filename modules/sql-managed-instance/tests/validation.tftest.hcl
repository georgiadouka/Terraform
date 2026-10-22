mock_provider "azurerm" {}

variables {
  name                        = "sqlmi-validation-test"
  resource_group_name         = "rg-validation-test"
  location                    = "swedencentral"
  subnet_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-validation-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/sql-managed-instance"
  network_security_group_name = "nsg-sqlmi-validation-test"
  route_table_name            = "rt-sqlmi-validation-test"
  azuread_administrator = {
    login_username = "Terraform SQL MI Admin"
    object_id      = "11111111-1111-1111-1111-111111111111"
  }
}

run "accept_minimum_storage_and_included_license" {
  command = plan
}

run "default_network_rules_and_routes" {
  command = plan

  assert {
    condition     = length(var.security_rules) == 1 && var.security_rules["allow-tds-inbound"].destination_port_range == "1433"
    error_message = "The default NSG must contain only the client TDS rule on port 1433."
  }

  assert {
    condition     = length(var.routes) == 0
    error_message = "The default route table must contain no user-defined routes."
  }
}

run "accept_custom_rules_and_routes" {
  command = plan
  variables {
    security_rules = {
      "allow-tds-from-apps" = {
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        destination_port_range     = "1433"
        source_address_prefixes    = ["10.42.1.0/24", "10.42.2.0/23"]
        destination_address_prefix = "*"
      }
    }
    routes = {
      "default-to-firewall" = {
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.0.4"
      }
    }
  }
}

run "reject_reserved_rule_prefix" {
  command = plan
  variables {
    security_rules = {
      "Microsoft.Sql-managedInstances_UseOnly_mi-custom" = {
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        destination_port_range     = "1433"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
      }
    }
  }
  expect_failures = [var.security_rules]
}

run "reject_reserved_route_prefix" {
  command = plan
  variables {
    routes = {
      "Microsoft.Sql-managedInstances_UseOnly_custom" = {
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "Internet"
      }
    }
  }
  expect_failures = [var.routes]
}

run "reject_storage_below_minimum" {
  command = plan
  variables {
    storage_size_in_gb = 0
  }
  expect_failures = [var.storage_size_in_gb]
}

run "reject_storage_outside_32_gib_increments" {
  command = plan
  variables {
    storage_size_in_gb = 48
  }
  expect_failures = [var.storage_size_in_gb]
}

run "reject_unsupported_license_type" {
  command = plan
  variables {
    license_type = "Unsupported"
  }
  expect_failures = [var.license_type]
}
