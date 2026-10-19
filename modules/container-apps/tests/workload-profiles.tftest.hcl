mock_provider "azurerm" {
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
    }
  }
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/cae-test"
      default_domain    = "test.azurecontainerapps.io"
      static_ip_address = "10.42.2.4"
    }
  }
}

variables {
  environment_name             = "cae-test"
  app_name                     = "ca-test"
  resource_group_name          = "rg-test"
  location                     = "swedencentral"
  infrastructure_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps"
  virtual_network_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  log_analytics_workspace_name = "log-test"
  private_dns_link_name        = "link-test"
  container_name               = "ctr-test"
}

run "consumption_default" {
  command = plan
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 1 &&
      one(azurerm_container_app_environment.this.workload_profile).name == "Consumption" &&
      output.app_workload_profile_name == "Consumption" &&
      length(output.dedicated_workload_profile_names) == 0 &&
      output.dedicated_workload_profile_name == null
    )
    error_message = "Default configuration must retain only Consumption."
  }
}

run "one_dedicated_profile" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      general = { name = "wp-general", workload_profile_type = "D4" }
    }
    app_workload_profile = "general"
  }
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 2 &&
      output.dedicated_workload_profile_names["general"] == "wp-general" &&
      output.dedicated_workload_profile_name == "wp-general" &&
      output.app_workload_profile_name == "wp-general" &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-general"]).minimum_count == 0 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-general"]).maximum_count == 3
    )
    error_message = "The app selector must resolve the logical key to its Azure profile name."
  }
}

run "multiple_profiles" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      general = { name = "wp-general", workload_profile_type = "D4", minimum_count = 0, maximum_count = 3 }
      memory  = { name = "wp-memory", workload_profile_type = "E4", minimum_count = 1, maximum_count = 2 }
    }
    app_workload_profile = "memory"
  }
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 3 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "Consumption"]).workload_profile_type == "Consumption" &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-general"]).maximum_count == 3 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-memory"]).minimum_count == 1 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-memory"]).workload_profile_type == "E4" &&
      output.app_workload_profile_name == "wp-memory" &&
      length(output.dedicated_workload_profile_names) == 2 &&
      output.dedicated_workload_profile_name == null &&
      azurerm_container_app.this.template[0].min_replicas == 0 &&
      azurerm_container_app.this.template[0].max_replicas == 1 &&
      azurerm_container_app.this.template[0].container[0].cpu == 0.25 &&
      azurerm_container_app.this.template[0].container[0].memory == "0.5Gi"
    )
    error_message = "Multiple dedicated profiles must preserve their types/scaling, retain Consumption, and place the app on only the selected profile."
  }
}

run "multiple_profiles_same_type" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      frontend = { name = "wp-frontend", workload_profile_type = "D4" }
      backend  = { name = "wp-backend", workload_profile_type = "D4" }
    }
    app_workload_profile = "backend"
  }
  assert {
    condition = (
      length([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.workload_profile_type == "D4"]) == 2 &&
      output.app_workload_profile_name == "wp-backend"
    )
    error_message = "Distinct profiles may share a workload profile type."
  }
}

run "profiles_with_app_on_consumption" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      general = { name = "wp-general" }
    }
    app_workload_profile = "Consumption"
  }
  assert {
    condition     = length(azurerm_container_app_environment.this.workload_profile) == 2 && output.app_workload_profile_name == "Consumption"
    error_message = "Dedicated capacity and Consumption app placement must be independent."
  }
}

run "no_selector_defaults_to_consumption" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general" } }
  }
  assert {
    condition     = output.app_workload_profile_name == "Consumption"
    error_message = "Adding profiles must not implicitly move the app off Consumption."
  }
}

run "legacy_single_profile" {
  command = plan
  variables {
    dedicated_workload_profile = { enabled = true, name = "wp-lab-test1", use_for_app = true }
  }
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 2 &&
      output.app_workload_profile_name == "wp-lab-test1" &&
      output.dedicated_workload_profile_name == "wp-lab-test1" &&
      output.dedicated_workload_profile_names["legacy"] == "wp-lab-test1"
    )
    error_message = "Legacy callers must preserve their existing profile name and placement without migration."
  }
}

run "legacy_consumption_placement" {
  command = plan
  variables {
    dedicated_workload_profile = { enabled = true, name = "wp-lab-test1", use_for_app = false }
  }
  assert {
    condition     = output.app_workload_profile_name == "Consumption" && length(azurerm_container_app_environment.this.workload_profile) == 2
    error_message = "Legacy use_for_app=false must retain Consumption placement."
  }
}

run "reject_missing_selector" {
  command = plan
  variables {
    app_workload_profile = "missing"
  }
  expect_failures = [var.app_workload_profile]
}

run "reject_unknown_selector_with_profiles" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general" } }
    app_workload_profile        = "memory"
  }
  expect_failures = [var.app_workload_profile]
}

run "reject_blank_selector" {
  command = plan
  variables {
    app_workload_profile = ""
  }
  expect_failures = [var.app_workload_profile]
}

run "reject_mixed_interfaces" {
  command = plan
  variables {
    dedicated_workload_profile  = { enabled = true, name = "wp-legacy" }
    dedicated_workload_profiles = { general = { name = "wp-general" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_legacy_with_new_selector" {
  command = plan
  variables {
    dedicated_workload_profile = { enabled = true, name = "wp-legacy" }
    app_workload_profile       = "Consumption"
  }
  expect_failures = [var.app_workload_profile]
}

run "reject_duplicate_names" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      general = { name = "wp-shared" }
      memory  = { name = "WP-SHARED" }
    }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_reserved_name" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "Consumption" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_reserved_key" {
  command = plan
  variables {
    dedicated_workload_profiles = { consumption = { name = "wp-general" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_invalid_key" {
  command = plan
  variables {
    dedicated_workload_profiles = { "bad_key" = { name = "wp-general" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_overlong_name" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "sixteen-charname" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_consumption_type" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", workload_profile_type = "Consumption" } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_blank_type" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", workload_profile_type = " " } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_negative_minimum" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", minimum_count = -1 } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_fractional_count" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", maximum_count = 1.5 } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_fractional_minimum" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", minimum_count = 0.5 } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_zero_maximum" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", maximum_count = 0 } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_inverted_counts" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general", minimum_count = 3, maximum_count = 2 } }
  }
  expect_failures = [var.dedicated_workload_profiles]
}

run "reject_empty_image" {
  command = plan
  variables {
    image = " "
  }
  expect_failures = [var.image]
}

run "reject_target_port_below_minimum" {
  command = plan
  variables {
    target_port = 0
  }
  expect_failures = [var.target_port]
}

run "reject_target_port_above_maximum" {
  command = plan
  variables {
    target_port = 65536
  }
  expect_failures = [var.target_port]
}

run "reject_fractional_target_port" {
  command = plan
  variables {
    target_port = 80.5
  }
  expect_failures = [var.target_port]
}
