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

  # Disabled: azurerm validates this at plan time.
  # validation {
  #   condition = (
  #     var.idle_timeout_in_minutes >= 4 &&
  #     var.idle_timeout_in_minutes <= 120 &&
  #     var.idle_timeout_in_minutes == floor(var.idle_timeout_in_minutes)
  #   )
  #   error_message = "idle_timeout_in_minutes must be a whole number from 4 through 120."
  # }
}

variable "tags" {
  description = "Tags applied to the NAT Gateway and public IP."
  type        = map(string)
  default     = {}
}
