variable "name" {
  description = "Load balancer name."
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
  description = "Subnet that hosts the internal frontend IP address."
  type        = string
}

variable "frontend_ip_configuration_name" {
  description = "Frontend IP configuration name."
  type        = string
}

variable "backend_address_pool_name" {
  description = "Backend address pool name."
  type        = string
}

variable "private_ip_address" {
  description = "Static frontend IP address within the subnet. Null allocates one dynamically."
  type        = string
  default     = null
}

variable "zones" {
  description = "Availability zones for the frontend IP. Several zones make it zone-redundant; an empty set leaves it non-zonal for regions without zones. Changing this replaces the load balancer."
  type        = set(string)
  default     = ["1", "2", "3"]
  nullable    = false

  validation {
    condition     = alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "zones may contain only \"1\", \"2\", and \"3\"."
  }
}

variable "probes" {
  description = "Health probes keyed by logical name. Names are Azure resource names; request_path is required for Http and Https and must be null for Tcp."
  type = map(object({
    name                = string
    protocol            = optional(string, "Tcp")
    port                = number
    request_path        = optional(string)
    interval_in_seconds = optional(number, 5)
    probe_threshold     = optional(number, 1)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for probe in values(var.probes) : try(
        contains(["Tcp", "Http", "Https"], probe.protocol) &&
        probe.port >= 1 && probe.port <= 65535 && probe.port == floor(probe.port) &&
        probe.interval_in_seconds >= 5 && probe.interval_in_seconds == floor(probe.interval_in_seconds) &&
        probe.probe_threshold >= 1 && probe.probe_threshold == floor(probe.probe_threshold) &&
        (probe.protocol == "Tcp" ? probe.request_path == null : can(regex("^/", probe.request_path))),
        false
      )
    ])
    error_message = "Every probe needs protocol Tcp, Http, or Https; a whole-number port from 1 through 65535; interval_in_seconds of at least 5; probe_threshold of at least 1; and a request_path starting with / for Http or Https (none for Tcp)."
  }
}

variable "rules" {
  description = "Load-balancing rules keyed by logical name. probe is a key in probes. Protocol All with ports 0 is an HA ports rule."
  type = map(object({
    name                    = string
    probe                   = string
    protocol                = optional(string, "Tcp")
    frontend_port           = number
    backend_port            = number
    idle_timeout_in_minutes = optional(number, 4)
    load_distribution       = optional(string, "Default")
    floating_ip_enabled     = optional(bool, false)
    tcp_reset_enabled       = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for rule in values(var.rules) : try(contains(keys(var.probes), rule.probe), false)
    ])
    error_message = "Every rule probe must be a key in probes."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) : try(
        contains(["Tcp", "Udp", "All"], rule.protocol) &&
        (
          rule.protocol == "All"
          ? rule.frontend_port == 0 && rule.backend_port == 0
          : alltrue([
            for port in [rule.frontend_port, rule.backend_port] :
            port >= 1 && port <= 65535 && port == floor(port)
          ])
        ),
        false
      )
    ])
    error_message = "Every rule protocol must be Tcp, Udp, or All. Tcp and Udp rules need whole-number ports from 1 through 65535; All (HA ports) needs frontend_port and backend_port 0."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) : try(
        rule.idle_timeout_in_minutes >= 4 &&
        rule.idle_timeout_in_minutes <= 100 &&
        rule.idle_timeout_in_minutes == floor(rule.idle_timeout_in_minutes) &&
        contains(["Default", "SourceIP", "SourceIPProtocol"], rule.load_distribution),
        false
      )
    ])
    error_message = "Every rule needs a whole-number idle_timeout_in_minutes from 4 through 100 and load_distribution Default, SourceIP, or SourceIPProtocol."
  }

  validation {
    condition = length(distinct([
      for rule in values(var.rules) : "${rule.protocol}/${rule.frontend_port}"
    ])) == length(var.rules)
    error_message = "Rules on the same frontend must not share a protocol and frontend_port."
  }
}

variable "tags" {
  description = "Tags applied to the load balancer."
  type        = map(string)
  default     = {}
}

resource "azurerm_lb" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  sku_tier            = "Regional"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = var.frontend_ip_configuration_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
    private_ip_address_version    = "IPv4"
    zones                         = length(var.zones) > 0 ? var.zones : null
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = var.backend_address_pool_name
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  for_each = var.probes

  name                = each.value.name
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = each.value.protocol
  port                = each.value.port
  request_path        = each.value.request_path
  interval_in_seconds = each.value.interval_in_seconds
  probe_threshold     = each.value.probe_threshold
}

resource "azurerm_lb_rule" "this" {
  for_each = var.rules

  name                           = each.value.name
  loadbalancer_id                = azurerm_lb.this.id
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this[each.value.probe].id
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  load_distribution              = each.value.load_distribution
  floating_ip_enabled            = each.value.floating_ip_enabled
  tcp_reset_enabled              = each.value.tcp_reset_enabled
}

output "id" {
  description = "Load balancer ID."
  value       = azurerm_lb.this.id
}

output "name" {
  description = "Load balancer name."
  value       = azurerm_lb.this.name
}

output "frontend_private_ip_address" {
  description = "Private IP address of the internal frontend."
  value       = azurerm_lb.this.frontend_ip_configuration[0].private_ip_address
}

output "backend_address_pool_id" {
  description = "Backend address pool ID that VM NICs and scale sets join."
  value       = azurerm_lb_backend_address_pool.this.id
}

output "probe_ids" {
  description = "Health probe IDs keyed by logical name."
  value       = { for key, probe in azurerm_lb_probe.this : key => probe.id }
}

output "rule_ids" {
  description = "Load-balancing rule IDs keyed by logical name."
  value       = { for key, rule in azurerm_lb_rule.this : key => rule.id }
}
