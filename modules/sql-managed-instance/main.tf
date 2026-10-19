variable "name" {
  description = "Globally unique SQL Managed Instance name."
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
  description = "Dedicated delegated subnet ID."
  type        = string
}

variable "subnet_address_prefix" {
  description = "Dedicated subnet CIDR used by mandatory NSG rules."
  type        = string
}

variable "network_security_group_name" {
  description = "Network security group name."
  type        = string
}

variable "route_table_name" {
  description = "Route table name."
  type        = string
}

variable "sku_name" {
  description = "SQL Managed Instance SKU."
  type        = string
  default     = "GP_Gen5"
}

variable "vcores" {
  description = "SQL Managed Instance vCore count."
  type        = number
  default     = 4
}

variable "storage_size_in_gb" {
  description = "SQL Managed Instance storage in GiB, in increments of 32."
  type        = number
  default     = 32

  validation {
    condition     = var.storage_size_in_gb >= 32 && var.storage_size_in_gb % 32 == 0
    error_message = "storage_size_in_gb must be at least 32 and a multiple of 32."
  }
}

variable "license_type" {
  description = "LicenseIncluded or BasePrice for eligible Azure Hybrid Benefit licenses."
  type        = string
  default     = "LicenseIncluded"

  validation {
    condition     = contains(["LicenseIncluded", "BasePrice"], var.license_type)
    error_message = "license_type must be LicenseIncluded or BasePrice."
  }
}

variable "azuread_administrator" {
  description = "Microsoft Entra administrator. Authentication is Entra-only."
  type = object({
    login_username = string
    object_id      = string
    principal_type = optional(string, "User")
    tenant_id      = optional(string)
  })

  validation {
    condition     = contains(["Application", "Group", "User"], var.azuread_administrator.principal_type)
    error_message = "principal_type must be Application, Group, or User."
  }
}

variable "tags" {
  description = "Tags applied to SQL Managed Instance resources."
  type        = map(string)
  default     = {}
}

resource "azurerm_network_security_group" "this" {
  name                = var.network_security_group_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  security_rule {
    name                       = "allow-management-inbound"
    priority                   = 106
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["9000", "9003", "1438", "1440", "1452"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-mi-subnet-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-health-probe-inbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-tds-inbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-management-outbound"
    priority                   = 102
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "12000"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-mi-subnet-outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_address_prefix
  }

  security_rule {
    name                       = "deny-all-outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_route_table" "this" {
  name                          = var.route_table_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_subnet_route_table_association" "this" {
  subnet_id      = var.subnet_id
  route_table_id = azurerm_route_table.this.id
}

resource "azurerm_mssql_managed_instance" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  license_type                 = var.license_type
  sku_name                     = var.sku_name
  storage_size_in_gb           = var.storage_size_in_gb
  subnet_id                    = var.subnet_id
  vcores                       = var.vcores
  minimum_tls_version          = "1.2"
  public_data_endpoint_enabled = false
  proxy_override               = "Redirect"
  storage_account_type         = "LRS"
  zone_redundant_enabled       = false
  tags                         = var.tags

  azure_active_directory_administrator {
    login_username                      = var.azuread_administrator.login_username
    object_id                           = var.azuread_administrator.object_id
    principal_type                      = var.azuread_administrator.principal_type
    tenant_id                           = var.azuread_administrator.tenant_id
    azuread_authentication_only_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.this,
    azurerm_subnet_route_table_association.this
  ]

  timeouts {
    create = "6h"
    update = "6h"
    delete = "6h"
  }
}

output "id" {
  description = "SQL Managed Instance ID."
  value       = azurerm_mssql_managed_instance.this.id
}

output "fqdn" {
  description = "SQL Managed Instance fully qualified domain name."
  value       = azurerm_mssql_managed_instance.this.fqdn
}

output "principal_id" {
  description = "SQL Managed Instance system-assigned identity principal ID."
  value       = azurerm_mssql_managed_instance.this.identity[0].principal_id
}
