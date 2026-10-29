variable "name" {
  description = "Azure Databricks workspace name, unique per resource group."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{1,62}[A-Za-z0-9]$", var.name))
    error_message = "name must be 3-64 letters, digits, underscores or hyphens and start and end with a letter or digit."
  }
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku" {
  description = "Workspace pricing tier. New Standard tier workspaces cannot be created since 1 April 2026; trial is a 14-day Premium trial."
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["premium", "trial"], var.sku)
    error_message = "sku must be premium or trial."
  }
}

variable "managed_resource_group_name" {
  description = "Name of the resource group that Azure Databricks creates and locks for the workspace's managed resources. It must not exist yet."
  type        = string

  validation {
    condition     = can(regex("^[-\\w._()]{0,89}[-\\w_()]$", var.managed_resource_group_name))
    error_message = "managed_resource_group_name must be 1-90 letters, digits, underscores, hyphens, periods or parentheses and must not end with a period."
  }
}

variable "root_storage_account_name" {
  description = "Name of the workspace root (DBFS) storage account in the managed resource group: 3-24 lowercase letters and digits, globally unique. Null lets Azure Databricks generate the name."
  type        = string
  default     = null

  validation {
    condition     = var.root_storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.root_storage_account_name))
    error_message = "root_storage_account_name must be null or 3-24 lowercase letters and digits."
  }
}

variable "virtual_network_id" {
  description = "ID of the virtual network the workspace is injected into."
  type        = string
}

variable "host_subnet" {
  description = "Host (public) subnet of the workspace: name and ID. It must be delegated to Microsoft.Databricks/workspaces and used by no other workspace."
  type = object({
    name = string
    id   = string
  })
}

variable "container_subnet" {
  description = "Container (private) subnet of the workspace: name and ID. It must be delegated to Microsoft.Databricks/workspaces and used by no other workspace."
  type = object({
    name = string
    id   = string
  })
}

variable "network_security_group_name" {
  description = "Name of the network security group the module creates and attaches to both workspace subnets. Azure Databricks adds and manages its own rules in it."
  type        = string
}

variable "network_access" {
  description = "private: no public access; users and clusters reach the control plane through the databricks_ui_api Private Endpoint (front-end and back-end Private Link). backend_private: users reach the workspace over the internet, clusters through the Private Endpoint (back-end Private Link only). public: users and clusters reach the control plane over the internet. The caller creates the Private Endpoint for private and backend_private. Clusters never get public IP addresses (secure cluster connectivity)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "backend_private", "public"], var.network_access)
    error_message = "network_access must be private, backend_private, or public."
  }
}

variable "access_connector_name" {
  description = "Name of the Access Connector for Azure Databricks (system-assigned managed identity that Unity Catalog uses to reach storage). Null creates no Access Connector."
  type        = string
  default     = null

  validation {
    condition     = var.access_connector_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{1,62}[A-Za-z0-9]$", var.access_connector_name))
    error_message = "access_connector_name must be null or 3-64 letters, digits, underscores or hyphens that start and end with a letter or digit."
  }
}

variable "access_connector_storage_account_ids" {
  description = "Storage accounts on which the Access Connector identity gets Storage Blob Data Contributor, keyed by a stable logical name. Requires access_connector_name."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.access_connector_storage_account_ids) == 0 || var.access_connector_name != null
    error_message = "access_connector_storage_account_ids requires access_connector_name."
  }
}

variable "diagnostics" {
  description = "Diagnostic setting that sends the workspace resource logs to log_analytics_workspace_id: every category (the allLogs category group, the only group Azure Databricks supports) when categories is empty, otherwise only the listed categories, for example [\"accounts\", \"clusters\", \"jobs\", \"unityCatalog\"]. Null creates no diagnostic setting."
  type = object({
    name                       = string
    log_analytics_workspace_id = string
    categories                 = optional(list(string), [])
  })
  default = null

  validation {
    condition = var.diagnostics == null || (
      length(distinct(try(var.diagnostics.categories, []))) == length(try(var.diagnostics.categories, [])) &&
      alltrue([for category in try(var.diagnostics.categories, []) : can(regex("^[A-Za-z][A-Za-z0-9]*$", category))])
    )
    error_message = "diagnostics.categories must be unique log category names such as clusters or unityCatalog."
  }
}

variable "tags" {
  description = "Tags applied to the workspace, its network security group, and the Access Connector. Azure Databricks also applies the workspace tags to its managed resources."
  type        = map(string)
  default     = {}
}
