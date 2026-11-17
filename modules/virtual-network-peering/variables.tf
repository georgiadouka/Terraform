variable "name" {
  description = "Peering name, unique within the local virtual network."
  type        = string

  # Disabled: the root module generates and validates this value.
  # validation {
  #   condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_.-]{0,78}[a-zA-Z0-9_])?$", var.name))
  #   error_message = "name must be 1-80 characters, start with a letter or digit, end with a letter, digit, or underscore, and contain only letters, digits, underscores, periods, or hyphens."
  # }
}

variable "resource_group_name" {
  description = "Resource group of the local virtual network."
  type        = string
}

variable "virtual_network_name" {
  description = "Local virtual network that owns this side of the peering."
  type        = string
}

variable "remote_virtual_network_id" {
  description = "Resource ID of the remote virtual network."
  type        = string

  # Disabled: the root module generates and validates this value.
  # validation {
  #   condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.remote_virtual_network_id))
  #   error_message = "remote_virtual_network_id must be a virtual network resource ID: /subscriptions/<id>/resourceGroups/<name>/providers/Microsoft.Network/virtualNetworks/<name>."
  # }
}

variable "allow_virtual_network_access" {
  description = "Whether resources in the local virtual network can reach the remote virtual network."
  type        = bool
  default     = true
}

variable "allow_forwarded_traffic" {
  description = "Whether traffic forwarded by the remote virtual network (for example by a hub firewall or NVA) is accepted."
  type        = bool
  default     = true
}

variable "allow_gateway_transit" {
  description = "Whether the remote virtual network can use this virtual network's VPN or ExpressRoute gateway. Set on the hub side."
  type        = bool
  default     = false
}

variable "use_remote_gateways" {
  description = "Whether this virtual network uses the remote virtual network's gateway. Set on the spoke side; the remote side must allow gateway transit and have a gateway."
  type        = bool
  default     = false

  validation {
    condition     = !(var.use_remote_gateways && var.allow_gateway_transit)
    error_message = "use_remote_gateways and allow_gateway_transit cannot both be true on the same peering."
  }
}

variable "triggers" {
  description = "Values whose change re-syncs the peering, typically the remote virtual network's address space."
  type        = map(string)
  default     = null
}
