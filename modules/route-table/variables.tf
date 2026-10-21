variable "name" {
  description = "Route table name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "bgp_route_propagation_enabled" {
  description = "Whether routes learned by BGP (for example from a VPN or ExpressRoute gateway) propagate to associated subnets."
  type        = bool
  default     = true
}

variable "routes" {
  description = "User-defined routes keyed by route name. next_hop_in_ip_address is required only when next_hop_type is VirtualAppliance."
  type = map(object({
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for route_name in keys(var.routes) :
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_.-]{0,78}[a-zA-Z0-9_])?$", route_name))
    ])
    error_message = "routes keys must be 1-80 characters, start with a letter or digit, end with a letter, digit, or underscore, and contain only letters, digits, underscores, periods, or hyphens."
  }

  validation {
    condition = alltrue([
      for route in values(var.routes) :
      (
        can(cidrnetmask(route.address_prefix)) &&
        try(cidrhost(route.address_prefix, 0) == split("/", route.address_prefix)[0], false)
      ) || can(regex("^[A-Za-z][A-Za-z0-9.]*$", route.address_prefix))
    ])
    error_message = "Every route address_prefix must be an IPv4 CIDR written with its network address or an Azure service tag."
  }

  validation {
    condition = alltrue([
      for route in values(var.routes) :
      contains(["VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"], route.next_hop_type)
    ])
    error_message = "Every route next_hop_type must be VirtualNetworkGateway, VnetLocal, Internet, VirtualAppliance, or None."
  }

  validation {
    condition = alltrue([
      for route in values(var.routes) :
      route.next_hop_type == "VirtualAppliance"
      ? can(cidrhost("${coalesce(route.next_hop_in_ip_address, "-")}/32", 0))
      : route.next_hop_in_ip_address == null
    ])
    error_message = "next_hop_in_ip_address must be a valid IPv4 address when next_hop_type is VirtualAppliance and must be omitted otherwise."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs associated with the route table, keyed by stable logical name."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the route table."
  type        = map(string)
  default     = {}
}
