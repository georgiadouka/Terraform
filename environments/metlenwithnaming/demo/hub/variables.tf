variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "location" {
  description = "Azure region of the hub; use the region of the demo environment."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Name of the hub resource group."
  type        = string
  default     = "rg-metlen-demo-hub"
}

variable "virtual_network_name" {
  description = "Name of the hub VNet. Peering names are <spoke VNet name>-to-<hub VNet name>, at most 80 characters, so keep it short."
  type        = string
  default     = "vnet-hub-demo"
}

variable "address_space" {
  description = "Address space of the hub VNet; it must not overlap the demo VNets (10.71.0.0/20 and 10.72.0.0/22)."
  type        = list(string)
  default     = ["10.70.0.0/22"]
}

variable "tags" {
  description = "Tags for the hub resources."
  type        = map(string)
  default     = {}
}

# The hub reads the same demo/environment.tfvars as the demo itself. This
# variable only accepts the hub_peering value set there, so Terraform does not
# warn about an undeclared variable; the hub does not use it.
variable "hub_peering" {
  description = "Not used by the hub; declared so demo/environment.tfvars can be shared."
  type        = any
  default     = null
}
