variable "name" {
  description = "Private Endpoint name."
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

variable "subnet_id" {
  description = "Private Endpoint subnet ID."
  type        = string
}

variable "private_connection_resource_id" {
  description = "Resource ID exposed through Private Link."
  type        = string
}

variable "subresource_names" {
  description = "Private Link subresources, such as blob, vault, or sqlServer."
  type        = list(string)
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs associated with the endpoint."
  type        = list(string)
}

variable "private_service_connection_name" {
  description = "Private service connection name."
  type        = string
}

variable "private_dns_zone_group_name" {
  description = "Private DNS zone group name."
  type        = string
}

variable "tags" {
  description = "Tags applied to the Private Endpoint."
  type        = map(string)
  default     = {}
}
