variable "name" {
  description = "App Service Plan name."
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

variable "os_type" {
  description = "Plan operating system: Linux or Windows. Every app on the plan must use the same OS."
  type        = string
  default     = "Linux"
  nullable    = false

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "sku_name" {
  description = "Plan SKU. Basic, Standard and Premium SKUs host Web Apps; Elastic Premium (EP1-EP3) hosts Function Apps. Every listed SKU supports Private Link and regional VNet integration."
  type        = string
  default     = "B1"
  nullable    = false

  validation {
    condition = contains([
      "B1", "B2", "B3",
      "S1", "S2", "S3",
      "P1v2", "P2v2", "P3v2",
      "P0v3", "P1v3", "P2v3", "P3v3",
      "P1mv3", "P2mv3", "P3mv3", "P4mv3", "P5mv3",
      "P0v4", "P1v4", "P2v4", "P3v4",
      "P1mv4", "P2mv4", "P3mv4", "P4mv4", "P5mv4",
      "EP1", "EP2", "EP3"
    ], var.sku_name)
    error_message = "sku_name must be a Basic, Standard, Premium or Elastic Premium (EP1-EP3) App Service SKU that supports Private Link and VNet integration."
  }
}

variable "tags" {
  description = "Tags applied to the App Service Plan."
  type        = map(string)
  default     = {}
}
