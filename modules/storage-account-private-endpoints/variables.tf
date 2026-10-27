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

variable "storage_account_id" {
  description = "Storage account ID exposed through Private Link."
  type        = string
}

variable "endpoints" {
  description = "Private Endpoints keyed by storage subresource: blob, file, queue, or table."
  type = map(object({
    name                            = string
    private_service_connection_name = string
    private_dns_zone_group_name     = string
    private_dns_zone_ids            = list(string)
  }))

  validation {
    condition     = alltrue([for subresource in keys(var.endpoints) : contains(["blob", "file", "queue", "table"], subresource)])
    error_message = "endpoints keys must be blob, file, queue, or table."
  }
}

variable "tags" {
  description = "Tags applied to the Private Endpoints."
  type        = map(string)
  default     = {}
}
