mock_provider "azurerm" {}

variables {
  name                           = "lbi-test"
  resource_group_name            = "rg-test"
  location                       = "swedencentral"
  subnet_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/lb"
  frontend_ip_configuration_name = "lbfe-test"
  backend_address_pool_name      = "lbbe-test"
  probes = {
    http = { name = "lbprobe-http", protocol = "Http", port = 80, request_path = "/" }
  }
  rules = {
    http = { name = "lbrule-http", probe = "http", frontend_port = 80, backend_port = 80 }
  }
}

run "internal_standard_defaults" {
  command = plan
  assert {
    condition = (
      azurerm_lb.this.sku == "Standard" &&
      azurerm_lb.this.sku_tier == "Regional" &&
      azurerm_lb.this.frontend_ip_configuration[0].subnet_id == var.subnet_id &&
      azurerm_lb.this.frontend_ip_configuration[0].private_ip_address_allocation == "Dynamic" &&
      azurerm_lb.this.frontend_ip_configuration[0].public_ip_address_id == null &&
      toset(azurerm_lb.this.frontend_ip_configuration[0].zones) == toset(["1", "2", "3"]) &&
      azurerm_lb_probe.this["http"].protocol == "Http" &&
      azurerm_lb_probe.this["http"].interval_in_seconds == 5 &&
      azurerm_lb_probe.this["http"].probe_threshold == 1 &&
      azurerm_lb_rule.this["http"].protocol == "Tcp" &&
      azurerm_lb_rule.this["http"].frontend_ip_configuration_name == "lbfe-test" &&
      azurerm_lb_rule.this["http"].tcp_reset_enabled == true &&
      azurerm_lb_rule.this["http"].floating_ip_enabled == false &&
      azurerm_lb_rule.this["http"].idle_timeout_in_minutes == 4
    )
    error_message = "Defaults must create an internal, zone-redundant Standard load balancer with a dynamic frontend IP, a 5-second probe, and a TCP rule with TCP reset."
  }
}

run "static_ip_without_zones" {
  command = plan
  variables {
    private_ip_address = "10.42.9.4"
    zones              = []
  }
  assert {
    condition = (
      azurerm_lb.this.frontend_ip_configuration[0].private_ip_address_allocation == "Static" &&
      azurerm_lb.this.frontend_ip_configuration[0].private_ip_address == "10.42.9.4" &&
      length(coalesce(azurerm_lb.this.frontend_ip_configuration[0].zones, [])) == 0
    )
    error_message = "A configured private_ip_address must be static, and an empty zone set must leave the frontend non-zonal."
  }
}

run "several_rules_share_probes" {
  command = plan
  variables {
    probes = {
      tcp  = { name = "lbprobe-tcp", port = 443 }
      http = { name = "lbprobe-http", protocol = "Http", port = 8080, request_path = "/healthz", interval_in_seconds = 10, probe_threshold = 2 }
    }
    rules = {
      https = { name = "lbrule-https", probe = "tcp", frontend_port = 443, backend_port = 443, load_distribution = "SourceIP" }
      http  = { name = "lbrule-http", probe = "http", frontend_port = 80, backend_port = 8080, idle_timeout_in_minutes = 30 }
      dns   = { name = "lbrule-dns", probe = "tcp", protocol = "Udp", frontend_port = 53, backend_port = 53 }
    }
  }
  assert {
    condition = (
      length(azurerm_lb_probe.this) == 2 &&
      length(azurerm_lb_rule.this) == 3 &&
      azurerm_lb_probe.this["tcp"].protocol == "Tcp" &&
      azurerm_lb_probe.this["tcp"].request_path == null &&
      azurerm_lb_probe.this["http"].request_path == "/healthz" &&
      azurerm_lb_probe.this["http"].interval_in_seconds == 10 &&
      azurerm_lb_rule.this["http"].backend_port == 8080 &&
      azurerm_lb_rule.this["http"].idle_timeout_in_minutes == 30 &&
      azurerm_lb_rule.this["https"].load_distribution == "SourceIP" &&
      azurerm_lb_rule.this["dns"].protocol == "Udp"
    )
    error_message = "Each rule must keep its own protocol, ports, and settings, and several rules may share one probe."
  }
}

run "ha_ports_rule" {
  command = plan
  variables {
    probes = { tcp = { name = "lbprobe-tcp", port = 22 } }
    rules = {
      all = { name = "lbrule-all", probe = "tcp", protocol = "All", frontend_port = 0, backend_port = 0, floating_ip_enabled = true }
    }
  }
  assert {
    condition = (
      azurerm_lb_rule.this["all"].protocol == "All" &&
      azurerm_lb_rule.this["all"].frontend_port == 0 &&
      azurerm_lb_rule.this["all"].floating_ip_enabled == true
    )
    error_message = "An HA ports rule must use protocol All with ports 0."
  }
}

run "no_rules" {
  command = plan
  variables {
    probes = {}
    rules  = {}
  }
  assert {
    condition     = length(azurerm_lb_probe.this) == 0 && length(azurerm_lb_rule.this) == 0
    error_message = "A load balancer may be created with only its frontend and backend pool."
  }
}

run "reject_unknown_probe" {
  command = plan
  variables {
    rules = {
      http = { name = "lbrule-http", probe = "missing", frontend_port = 80, backend_port = 80 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_ha_ports_with_nonzero_port" {
  command = plan
  variables {
    rules = {
      all = { name = "lbrule-all", probe = "http", protocol = "All", frontend_port = 80, backend_port = 80 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_zero_port_for_tcp" {
  command = plan
  variables {
    rules = {
      http = { name = "lbrule-http", probe = "http", frontend_port = 0, backend_port = 80 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_rule_protocol" {
  command = plan
  variables {
    rules = {
      http = { name = "lbrule-http", probe = "http", protocol = "Http", frontend_port = 80, backend_port = 80 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_duplicate_frontend_port" {
  command = plan
  variables {
    rules = {
      one = { name = "lbrule-one", probe = "http", frontend_port = 80, backend_port = 80 }
      two = { name = "lbrule-two", probe = "http", frontend_port = 80, backend_port = 8080 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_idle_timeout_out_of_range" {
  command = plan
  variables {
    rules = {
      http = { name = "lbrule-http", probe = "http", frontend_port = 80, backend_port = 80, idle_timeout_in_minutes = 101 }
    }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_load_distribution" {
  command = plan
  variables {
    rules = {
      http = { name = "lbrule-http", probe = "http", frontend_port = 80, backend_port = 80, load_distribution = "RoundRobin" }
    }
  }
  expect_failures = [var.rules]
}

run "reject_http_probe_without_path" {
  command = plan
  variables {
    probes = { http = { name = "lbprobe-http", protocol = "Http", port = 80 } }
  }
  expect_failures = [var.probes]
}

run "reject_tcp_probe_with_path" {
  command = plan
  variables {
    probes = { http = { name = "lbprobe-http", port = 80, request_path = "/" } }
  }
  expect_failures = [var.probes]
}

run "reject_short_probe_interval" {
  command = plan
  variables {
    probes = { http = { name = "lbprobe-http", protocol = "Http", port = 80, request_path = "/", interval_in_seconds = 4 } }
  }
  expect_failures = [var.probes]
}

run "reject_invalid_zone" {
  command = plan
  variables {
    zones = ["4"]
  }
  expect_failures = [var.zones]
}
