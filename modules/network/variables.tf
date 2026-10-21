variable "name" {
  description = "Virtual network name."
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

variable "address_space" {
  description = "Virtual network address spaces."
  type        = list(string)
}

variable "subnets" {
  description = "Subnet definitions keyed by logical name."
  type = map(object({
    name                              = string
    address_prefixes                  = list(string)
    private_endpoint_network_policies = optional(string, "Enabled")
    service_endpoints                 = optional(list(string), [])
    delegation = optional(object({
      name    = string
      service = string
      actions = list(string)
    }))
  }))
}

variable "planned_subnet_address_prefixes" {
  description = "Complete planned subnet address map used for containment and overlap validation, including subnets not currently deployed."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Tags applied to network resources."
  type        = map(string)
  default     = {}
}
