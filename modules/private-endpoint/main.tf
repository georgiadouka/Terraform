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

resource "azurerm_private_endpoint" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = var.private_service_connection_name
    private_connection_resource_id = var.private_connection_resource_id
    is_manual_connection           = false
    subresource_names              = var.subresource_names
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) == 0 ? [] : [1]

    content {
      name                 = var.private_dns_zone_group_name
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }
}

output "id" {
  description = "Private Endpoint ID."
  value       = azurerm_private_endpoint.this.id
}
