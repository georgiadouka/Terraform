variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "virtual_network_id" {
  description = "Virtual network linked to every private DNS zone."
  type        = string
}

variable "zone_names" {
  description = "Private DNS zone names."
  type        = set(string)
}

variable "virtual_network_link_names" {
  description = "VNet link names keyed by Private DNS zone name."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to private DNS zones."
  type        = map(string)
  default     = {}
}
