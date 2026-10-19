variable "name" {
  description = "NAT Gateway name."
  type        = string
}

variable "public_ip_name" {
  description = "Standard static public IP name."
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

variable "subnet_ids" {
  description = "Subnet IDs associated with the NAT Gateway, keyed by stable logical name."
  type        = map(string)
}

variable "idle_timeout_in_minutes" {
  description = "TCP idle timeout in minutes."
  type        = number
  default     = 4

  validation {
    condition = (
      var.idle_timeout_in_minutes >= 4 &&
      var.idle_timeout_in_minutes <= 120 &&
      var.idle_timeout_in_minutes == floor(var.idle_timeout_in_minutes)
    )
    error_message = "idle_timeout_in_minutes must be a whole number from 4 through 120."
  }
}

variable "tags" {
  description = "Tags applied to the NAT Gateway and public IP."
  type        = map(string)
  default     = {}
}

resource "azurerm_public_ip" "this" {
  name                = var.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  ip_version          = "IPv4"
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ip_tags]
  }
}

resource "azurerm_nat_gateway" "this" {
  name                    = var.name
  resource_group_name     = var.resource_group_name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.this.id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = var.subnet_ids

  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.this.id

  depends_on = [azurerm_nat_gateway_public_ip_association.this]
}

output "id" {
  description = "NAT Gateway ID."
  value       = azurerm_nat_gateway.this.id
}

output "public_ip_id" {
  description = "NAT Gateway public IP resource ID."
  value       = azurerm_public_ip.this.id
}

output "public_ip_address" {
  description = "NAT Gateway public IPv4 address."
  value       = azurerm_public_ip.this.ip_address
}
