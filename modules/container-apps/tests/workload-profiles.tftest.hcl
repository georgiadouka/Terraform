mock_provider "azurerm" {
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/cae-test"
      default_domain    = "test.azurecontainerapps.io"
      static_ip_address = "10.42.2.4"
    }
  }
}

variables {
  environment_name           = "cae-test"
  resource_group_name        = "rg-test"
  location                   = "swedencentral"
  infrastructure_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/apps"
  virtual_network_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
  private_dns_link_name      = "link-test"
  apps = {
    hello = { name = "ca-test", container_name = "ctr-test" }
  }
}

run "consumption_default" {
  command = plan
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 1 &&
      one(azurerm_container_app_environment.this.workload_profile).name == "Consumption" &&
      azurerm_container_app_environment.this.log_analytics_workspace_id == var.log_analytics_workspace_id &&
      output.apps["hello"].workload_profile_name == "Consumption" &&
      length(output.dedicated_workload_profile_names) == 0
    )
    error_message = "Default configuration must retain only Consumption and send logs to the supplied workspace."
  }
}

run "environment_without_apps" {
  command = plan
  variables {
    apps = {}
  }
  assert {
    condition     = length(azurerm_container_app.this) == 0 && length(output.apps) == 0
    error_message = "An environment may be created without apps."
  }
}

run "multiple_apps" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-hello-test", container_name = "ctr-test" }
      api   = { name = "ca-api-test", container_name = "ctr-test", image = "mcr.microsoft.com/k8se/quickstart:latest", target_port = 8080 }
    }
  }
  assert {
    condition = (
      length(azurerm_container_app.this) == 2 &&
      azurerm_container_app.this["hello"].name == "ca-hello-test" &&
      azurerm_container_app.this["api"].name == "ca-api-test" &&
      azurerm_container_app.this["api"].ingress[0].target_port == 8080 &&
      azurerm_container_app.this["api"].template[0].container[0].image == "mcr.microsoft.com/k8se/quickstart:latest" &&
      azurerm_container_app.this["hello"].ingress[0].target_port == 80 &&
      azurerm_container_app.this["hello"].template[0].container[0].image == "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    )
    error_message = "Each app must be created with its own name, image, and port."
  }
}

run "one_dedicated_profile" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      general = { name = "wp-general", workload_profile_type = "D4" }
    }
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", workload_profile = "general" }
    }
  }
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 2 &&
      output.dedicated_workload_profile_names["general"] == "wp-general" &&
      output.apps["hello"].workload_profile_name == "wp-general" &&
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
    apps = {
      hello = { name = "ca-hello-test", container_name = "ctr-test", workload_profile = "memory" }
      api   = { name = "ca-api-test", container_name = "ctr-test", workload_profile = "general" }
      jobs  = { name = "ca-jobs-test", container_name = "ctr-test" }
    }
  }
  assert {
    condition = (
      length(azurerm_container_app_environment.this.workload_profile) == 3 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "Consumption"]).workload_profile_type == "Consumption" &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-general"]).maximum_count == 3 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-memory"]).minimum_count == 1 &&
      one([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.name == "wp-memory"]).workload_profile_type == "E4" &&
      output.apps["hello"].workload_profile_name == "wp-memory" &&
      output.apps["api"].workload_profile_name == "wp-general" &&
      output.apps["jobs"].workload_profile_name == "Consumption" &&
      length(output.dedicated_workload_profile_names) == 2 &&
      azurerm_container_app.this["hello"].template[0].min_replicas == 0 &&
      azurerm_container_app.this["hello"].template[0].max_replicas == 1 &&
      azurerm_container_app.this["hello"].template[0].container[0].cpu == 0.25 &&
      azurerm_container_app.this["hello"].template[0].container[0].memory == "0.5Gi"
    )
    error_message = "Multiple dedicated profiles must preserve their types/scaling, retain Consumption, and place each app on its own selected profile."
  }
}

run "multiple_profiles_same_type" {
  command = plan
  variables {
    dedicated_workload_profiles = {
      frontend = { name = "wp-frontend", workload_profile_type = "D4" }
      backend  = { name = "wp-backend", workload_profile_type = "D4" }
    }
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", workload_profile = "backend" }
    }
  }
  assert {
    condition = (
      length([for profile in azurerm_container_app_environment.this.workload_profile : profile if profile.workload_profile_type == "D4"]) == 2 &&
      output.apps["hello"].workload_profile_name == "wp-backend"
    )
    error_message = "Distinct profiles may share a workload profile type."
  }
}

run "no_selector_defaults_to_consumption" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general" } }
  }
  assert {
    condition     = length(azurerm_container_app_environment.this.workload_profile) == 2 && output.apps["hello"].workload_profile_name == "Consumption"
    error_message = "Adding profiles must not implicitly move an app off Consumption."
  }
}

run "reject_missing_selector" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", workload_profile = "missing" }
    }
  }
  expect_failures = [var.apps]
}

run "reject_unknown_selector_with_profiles" {
  command = plan
  variables {
    dedicated_workload_profiles = { general = { name = "wp-general" } }
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", workload_profile = "memory" }
    }
  }
  expect_failures = [var.apps]
}

run "reject_blank_selector" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", workload_profile = "" }
    }
  }
  expect_failures = [var.apps]
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_duplicate_app_names" {
#   command = plan
#   variables {
#     apps = {
#       hello = { name = "ca-test", container_name = "ctr-test" }
#       api   = { name = "ca-test", container_name = "ctr-test" }
#     }
#   }
#   expect_failures = [var.apps]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_overlong_app_name" {
#   command = plan
#   variables {
#     apps = {
#       hello = { name = "ca-thirty-three-characters-long-x", container_name = "ctr-test" }
#     }
#   }
#   expect_failures = [var.apps]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_app_name_with_consecutive_hyphens" {
#   command = plan
#   variables {
#     apps = {
#       hello = { name = "ca--test", container_name = "ctr-test" }
#     }
#   }
#   expect_failures = [var.apps]
# }

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

# Disabled: the validation it tests is disabled (azurerm rejects empty values at plan time).
# run "reject_empty_image" {
#   command = plan
#   variables {
#     apps = {
#       hello = { name = "ca-test", container_name = "ctr-test", image = " " }
#     }
#   }
#   expect_failures = [var.apps]
# }

run "reject_target_port_below_minimum" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", target_port = 0 }
    }
  }
  expect_failures = [var.apps]
}

run "reject_target_port_above_maximum" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", target_port = 65536 }
    }
  }
  expect_failures = [var.apps]
}

run "reject_fractional_target_port" {
  command = plan
  variables {
    apps = {
      hello = { name = "ca-test", container_name = "ctr-test", target_port = 80.5 }
    }
  }
  expect_failures = [var.apps]
}
