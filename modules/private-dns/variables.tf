variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "virtual_network_id" {
  description = "Single virtual network linked to every private DNS zone that has a name in virtual_network_link_names. Null when the links come from virtual_network_links."
  type        = string
  default     = null
}

variable "zone_names" {
  description = "Private DNS zone names."
  type        = set(string)
}

variable "virtual_network_link_names" {
  description = "VNet link names keyed by Private DNS zone name, used with virtual_network_id."
  type        = map(string)
  default     = {}
}

variable "virtual_network_links" {
  description = "Virtual networks linked to every private DNS zone, keyed by a stable label. name is the link name, which must be unique per zone."
  type = map(object({
    virtual_network_id = string
    name               = string
  }))
  default  = {}
  nullable = false
}

variable "tags" {
  description = "Tags applied to private DNS zones."
  type        = map(string)
  default     = {}
}
