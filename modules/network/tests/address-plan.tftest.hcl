mock_provider "azurerm" {}

variables {
  name                = "vnet-test"
  resource_group_name = "rg-test"
  location            = "swedencentral"
  address_space       = ["10.42.0.0/20"]
  subnets = {
    workloads = {
      name             = "snet-workloads"
      address_prefixes = ["10.42.1.0/24"]
    }
  }
}

run "matching_deployed_and_planned_subnets" {
  command = plan

  variables {
    planned_subnet_address_prefixes = {
      workloads = ["10.42.1.0/24"]
      future    = ["10.42.2.0/24"]
    }
  }

  assert {
    condition     = length(azurerm_subnet.this) == 1
    error_message = "Only deployed subnets should be created while the complete address plan is validated."
  }
}

run "reject_deployed_subnet_missing_from_plan" {
  command = plan

  variables {
    planned_subnet_address_prefixes = {
      future = ["10.42.2.0/24"]
    }
  }

  expect_failures = [azurerm_virtual_network.this]
}

run "reject_deployed_subnet_differing_from_plan" {
  command = plan

  variables {
    planned_subnet_address_prefixes = {
      workloads = ["10.42.3.0/24"]
    }
  }

  expect_failures = [azurerm_virtual_network.this]
}

run "reject_deployed_subnet_outside_vnet" {
  command = plan

  variables {
    subnets = {
      workloads = {
        name             = "snet-workloads"
        address_prefixes = ["10.43.1.0/24"]
      }
    }
  }

  expect_failures = [azurerm_virtual_network.this]
}

run "reject_overlapping_deployed_subnets" {
  command = plan

  variables {
    subnets = {
      workloads = {
        name             = "snet-workloads"
        address_prefixes = ["10.42.1.0/24"]
      }
      data = {
        name             = "snet-data"
        address_prefixes = ["10.42.1.128/25"]
      }
    }
  }

  expect_failures = [azurerm_virtual_network.this]
}

run "reject_future_plan_overlap_with_deployed_subnet" {
  command = plan

  variables {
    planned_subnet_address_prefixes = {
      workloads = ["10.42.1.0/24"]
      future    = ["10.42.1.128/25"]
    }
  }

  expect_failures = [azurerm_virtual_network.this]
}
