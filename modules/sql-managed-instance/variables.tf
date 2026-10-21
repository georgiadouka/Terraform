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
