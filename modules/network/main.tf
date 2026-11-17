locals {
  deployed_subnet_address_prefixes = {
    for subnet_key, subnet in var.subnets :
    subnet_key => subnet.address_prefixes
  }

  subnet_address_prefixes_for_validation = merge(
    var.planned_subnet_address_prefixes,
    local.deployed_subnet_address_prefixes
  )

  address_space_inputs = [
    for prefix in var.address_space : {
      cidr          = prefix
      address       = split("/", prefix)[0]
      prefix_length = tonumber(split("/", prefix)[1])
    }
  ]

  address_space_networks = [
    for item in local.address_space_inputs : merge(item, {
      address_number = sum([
        for index, octet in split(".", item.address) :
        tonumber(octet) * pow(256, 3 - index)
      ])
      block_size = pow(2, 32 - item.prefix_length)
    })
  ]

  address_space_ranges = [
    for item in local.address_space_networks : merge(item, {
      range_start = floor(item.address_number / item.block_size) * item.block_size
      range_end   = floor(item.address_number / item.block_size) * item.block_size + item.block_size - 1
    })
  ]

  subnet_prefix_inputs = flatten([
    for subnet_key, address_prefixes in local.subnet_address_prefixes_for_validation : [
      for prefix_index, prefix in address_prefixes : {
        key           = "${subnet_key}-${prefix_index}"
        cidr          = prefix
        address       = split("/", prefix)[0]
        prefix_length = tonumber(split("/", prefix)[1])
      }
    ]
  ])

  subnet_networks = [
    for item in local.subnet_prefix_inputs : merge(item, {
      address_number = sum([
        for index, octet in split(".", item.address) :
        tonumber(octet) * pow(256, 3 - index)
      ])
      block_size = pow(2, 32 - item.prefix_length)
    })
  ]

  subnet_ranges = [
    for item in local.subnet_networks : merge(item, {
      range_start = floor(item.address_number / item.block_size) * item.block_size
      range_end   = floor(item.address_number / item.block_size) * item.block_size + item.block_size - 1
    })
  ]

  subnet_prefix_pairs = flatten([
    for first_index, first_range in local.subnet_ranges : [
      for second_index, second_range in local.subnet_ranges : {
        first  = first_range
        second = second_range
      } if first_index < second_index
    ]
  ])
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags

  lifecycle {
    precondition {
      condition = length(var.planned_subnet_address_prefixes) == 0 || alltrue([
        for subnet_key, address_prefixes in local.deployed_subnet_address_prefixes :
        contains(keys(var.planned_subnet_address_prefixes), subnet_key) &&
        try(toset(var.planned_subnet_address_prefixes[subnet_key]) == toset(address_prefixes), false)
      ])
      error_message = "Every deployed subnet must exist in planned_subnet_address_prefixes with the same address prefixes."
    }

    precondition {
      condition = alltrue([
        for subnet_range in local.subnet_ranges : anytrue([
          for address_space_range in local.address_space_ranges :
          subnet_range.range_start >= address_space_range.range_start &&
          subnet_range.range_end <= address_space_range.range_end
        ])
      ])
      error_message = "Every subnet prefix must be fully contained in one of the virtual network address spaces."
    }

    precondition {
      condition = alltrue([
        for pair in local.subnet_prefix_pairs :
        pair.first.range_end < pair.second.range_start ||
        pair.second.range_end < pair.first.range_start
      ])
      error_message = "Subnet address prefixes must not overlap."
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = each.value.name
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = each.value.address_prefixes
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
  service_endpoints                 = each.value.service_endpoints
  default_outbound_access_enabled   = each.value.default_outbound_access_enabled

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}
