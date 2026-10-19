mock_provider "azurerm" {}

variables {
  name                       = "func-runtime-test"
  service_plan_name          = "asp-runtime-test"
  resource_group_name        = "rg-runtime-test"
  location                   = "swedencentral"
  storage_account_name       = "struntimetest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "function-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-runtime-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
}

run "default_python" {
  command = plan

  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "python" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].python_version == "3.11" &&
      length(azurerm_linux_function_app.this) == 1 &&
      length(azurerm_windows_function_app.this) == 0 &&
      azurerm_service_plan.this.os_type == "Linux" &&
      azurerm_service_plan.this.sku_name == "EP1"
    )
    error_message = "Default Linux/Python 3.11 Elastic Premium configuration must be preserved."
  }
}

run "python_version" {
  command = plan
  variables {
    runtime = { name = "python", version = "3.12" }
  }
  assert {
    condition     = azurerm_linux_function_app.this[0].site_config[0].application_stack[0].python_version == "3.12"
    error_message = "Python version must be configurable."
  }
}

run "node" {
  command = plan
  variables {
    runtime = { name = "node", version = "22" }
  }
  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "node" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].node_version == "22" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].python_version == null
    )
    error_message = "Node must configure only the Node stack and matching worker."
  }
}

run "dotnet_isolated" {
  command = plan
  variables {
    runtime = { name = "dotnet-isolated", version = "8.0" }
  }
  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet-isolated" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].dotnet_version == "8.0" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].use_dotnet_isolated_runtime
    )
    error_message = ".NET isolated must set its worker, version, and isolated flag."
  }
}

run "dotnet_in_process" {
  command = plan
  variables {
    runtime = { name = "dotnet", version = "8.0" }
  }
  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet" &&
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_INPROC_NET8_ENABLED"] == "1" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].dotnet_version == "8.0" &&
      !azurerm_linux_function_app.this[0].site_config[0].application_stack[0].use_dotnet_isolated_runtime
    )
    error_message = ".NET in-process must not enable isolated mode."
  }
}

run "reject_linux_in_process_dotnet7" {
  command = plan
  variables {
    runtime = { name = "dotnet", version = "7.0" }
  }
  expect_failures = [var.runtime]
}

run "reject_linux_in_process_dotnet9" {
  command = plan
  variables {
    runtime = { name = "dotnet", version = "9.0" }
  }
  expect_failures = [var.runtime]
}

run "java" {
  command = plan
  variables {
    runtime = { name = "java", version = "21" }
  }
  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "java" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].java_version == "21"
    )
    error_message = "Java worker and version must match."
  }
}

run "powershell" {
  command = plan
  variables {
    runtime = { name = "powershell", version = "7.4" }
  }
  assert {
    condition = (
      azurerm_linux_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "powershell" &&
      azurerm_linux_function_app.this[0].site_config[0].application_stack[0].powershell_core_version == "7.4"
    )
    error_message = "PowerShell worker and version must match."
  }
}

run "invalid_language" {
  command = plan
  variables {
    runtime = { name = "ruby", version = "3.3" }
  }
  expect_failures = [var.runtime]
}

# Temporarily disabled with the exact runtime-version allowlist.
/*
run "mismatched_version" {
  command = plan
  variables {
    runtime = { name = "node", version = "3.11" }
  }
  expect_failures = [var.runtime]
}
*/

run "invalid_plan" {
  command = plan
  variables {
    service_plan_sku_name = "Y1"
  }
  expect_failures = [var.service_plan_sku_name]
}
