# Locks in hub-spoke peering wiring: which sides exist, which VNets opt in,
# which VNet and subscription the hub side targets, and the generated names.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}

mock_provider "azurerm" {
  alias = "hub"
}

variables {
  # Mock-only values; real passwords never go into committed files.
  vm_admin_password       = "MockOnly-Passw0rd!123"
  database_admin_password = "MockOnly-DbPassw0rd!456"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  tenant_id               = "22222222-2222-2222-2222-222222222222"
  naming                  = { unique_suffix = "test1" }
  project_name            = "metlen"
  environment             = "lab"
  naming_tokens           = { business_unit = "IT", department = "PPA", application = "ECM", environment = "DEV" }
  virtual_networks = {
    main = {
      address_space = ["10.42.0.0/20"]
    }
  }
  hub_peering = {
    hub_virtual_network_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  }
}

run "both_sides_by_default" {
  command = plan

  assert {
    condition = (
      length(module.spoke_to_hub_peering) == 1 &&
      length(module.hub_to_spoke_peering) == 1
    )
    error_message = "Both peering sides should be created by default."
  }

  assert {
    condition = local.hub_virtual_network == {
      subscription_id     = "33333333-3333-3333-3333-333333333333"
      resource_group_name = "rg-hub"
      name                = "vnet-hub"
    }
    error_message = "The hub subscription, resource group, and VNet name should be parsed from hub_virtual_network_id."
  }

  assert {
    condition = (
      module.spoke_to_hub_peering["main"].name == "M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE-to-vnet-hub" &&
      module.hub_to_spoke_peering["main"].name == "vnet-hub-to-M-AZU-VNT-IT-PPA-ECM-PRV-DEV-SWE"
    )
    error_message = "Peering names should be <local VNet name>-to-<remote VNet name>."
  }
}

run "spoke_side_only" {
  command = plan

  variables {
    hub_peering = {
      hub_virtual_network_id      = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      create_hub_to_spoke_peering = false
    }
  }

  assert {
    condition = (
      length(module.spoke_to_hub_peering) == 1 &&
      length(module.hub_to_spoke_peering) == 0
    )
    error_message = "Only the spoke side should be created when create_hub_to_spoke_peering is false."
  }
}

run "reject_invalid_hub_id" {
  command = plan

  variables {
    hub_peering = {
      hub_virtual_network_id = "vnet-hub"
    }
  }

  expect_failures = [var.hub_peering]
}

run "every_vnet_peers_by_default" {
  command = plan

  variables {
    virtual_networks = {
      main = { address_space = ["10.42.0.0/20"] }
      edge = { classification = "PUB", address_space = ["10.43.0.0/22"] }
    }
  }

  assert {
    condition = (
      toset(keys(module.spoke_to_hub_peering)) == toset(["edge", "main"]) &&
      toset(keys(module.hub_to_spoke_peering)) == toset(["edge", "main"]) &&
      module.spoke_to_hub_peering["edge"].name == "M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE-to-vnet-hub" &&
      module.hub_to_spoke_peering["edge"].name == "vnet-hub-to-M-AZU-VNT-IT-PPA-ECM-PUB-DEV-SWE"
    )
    error_message = "Without hub_peering.virtual_networks every VNet should be peered with the hub, each with names derived from its VNet name."
  }
}

run "vnets_opt_in" {
  command = plan

  variables {
    virtual_networks = {
      main = { address_space = ["10.42.0.0/20"] }
      edge = { classification = "PUB", address_space = ["10.43.0.0/22"] }
    }
    hub_peering = {
      hub_virtual_network_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      virtual_networks       = ["main"]
    }
  }

  assert {
    condition = (
      keys(module.spoke_to_hub_peering) == ["main"] &&
      keys(module.hub_to_spoke_peering) == ["main"] &&
      keys(output.hub_peering.virtual_networks) == ["main"]
    )
    error_message = "Only the VNets listed in hub_peering.virtual_networks should be peered with the hub."
  }
}

run "reject_unknown_hub_peering_vnet" {
  command = plan

  variables {
    hub_peering = {
      hub_virtual_network_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      virtual_networks       = ["missing"]
    }
  }

  expect_failures = [var.hub_peering]
}

# 32-character spoke name + "-to-" + 45-character hub name = 81 characters.
run "reject_peering_name_over_80_characters" {
  command = plan

  variables {
    hub_peering = {
      hub_virtual_network_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub-connectivity-shared-westeurope-00001"
    }
  }

  expect_failures = [var.hub_peering]
}
