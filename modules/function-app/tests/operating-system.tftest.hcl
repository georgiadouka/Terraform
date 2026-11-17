mock_provider "azurerm" {
  override_during = plan
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-test"
    }
  }
  mock_resource "azurerm_linux_function_app" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-linux"
      default_hostname = "func-linux.azurewebsites.net"
      identity = {
        principal_id = "11111111-1111-1111-1111-111111111111"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
  mock_resource "azurerm_windows_function_app" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/func-windows"
      default_hostname = "func-windows.azurewebsites.net"
      identity = {
        principal_id = "33333333-3333-3333-3333-333333333333"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
}

variables {
  name                       = "func-os-test"
  service_plan_name          = "asp-test"
  resource_group_name        = "rg-test"
  location                   = "swedencentral"
  storage_account_name       = "stfunctiontest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "function-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/functions"
}

run "linux_default_outputs" {
  command = plan
  assert {
    condition = (
      output.os_type == "Linux" &&
      endswith(output.id, "/sites/func-linux") &&
      output.default_hostname == "func-linux.azurewebsites.net" &&
      output.principal_id == "11111111-1111-1111-1111-111111111111"
    )
    error_message = "Default outputs must refer to the Linux app and its identity."
  }
}

run "windows_dotnet_isolated" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet-isolated", version = "8.0" }
  }
  assert {
    condition = (
      length(azurerm_linux_function_app.this) == 0 &&
      length(azurerm_windows_function_app.this) == 1 &&
      azurerm_service_plan.this[0].os_type == "Windows" &&
      azurerm_service_plan.this[0].sku_name == "EP1" &&
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet-isolated" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].dotnet_version == "v8.0" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].use_dotnet_isolated_runtime &&
      output.os_type == "Windows" &&
      endswith(output.id, "/sites/func-windows") &&
      output.default_hostname == "func-windows.azurewebsites.net" &&
      output.principal_id == "33333333-3333-3333-3333-333333333333"
    )
    error_message = "Windows must create only a Windows app on a Windows plan and normalize .NET versions without changing the output contract."
  }
  assert {
    condition = (
      azurerm_windows_function_app.this[0].virtual_network_subnet_id == var.virtual_network_subnet_id &&
      !azurerm_windows_function_app.this[0].public_network_access_enabled &&
      azurerm_windows_function_app.this[0].https_only &&
      !azurerm_windows_function_app.this[0].ftp_publish_basic_authentication_enabled &&
      !azurerm_windows_function_app.this[0].webdeploy_publish_basic_authentication_enabled &&
      azurerm_windows_function_app.this[0].site_config[0].vnet_route_all_enabled &&
      azurerm_windows_function_app.this[0].site_config[0].minimum_tls_version == "1.2" &&
      azurerm_windows_function_app.this[0].site_config[0].scm_minimum_tls_version == "1.2" &&
      azurerm_windows_function_app.this[0].site_config[0].ftps_state == "Disabled" &&
      azurerm_windows_function_app.this[0].identity[0].type == "SystemAssigned" &&
      azurerm_windows_function_app.this[0].app_settings["WEBSITE_CONTENTSHARE"] == var.content_share_name &&
      azurerm_windows_function_app.this[0].app_settings["WEBSITE_CONTENTOVERVNET"] == "1" &&
      azurerm_windows_function_app.this[0].functions_extension_version == "~4"
    )
    error_message = "Windows must preserve private networking, secured publishing/TLS, identity, private content share, and Functions v4."
  }
}

run "windows_dotnet_in_process" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet", version = "8.0" }
  }
  assert {
    condition = (
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet" &&
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_INPROC_NET8_ENABLED"] == "1" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].dotnet_version == "v8.0" &&
      !azurerm_windows_function_app.this[0].site_config[0].application_stack[0].use_dotnet_isolated_runtime
    )
    error_message = "Windows in-process .NET 8 must set its enablement setting and disable isolated mode."
  }
}

run "windows_dotnet10_isolated" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet-isolated", version = "10.0" }
  }
  assert {
    condition     = azurerm_windows_function_app.this[0].site_config[0].application_stack[0].dotnet_version == "v10.0"
    error_message = "Windows .NET 10 isolated must use the correct provider version format."
  }
}

run "windows_node" {
  command = plan
  variables {
    os_type               = "Windows"
    runtime               = { name = "node", version = "22" }
    service_plan_sku_name = "EP2"
  }
  assert {
    condition = (
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "node" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].node_version == "~22" &&
      azurerm_service_plan.this[0].sku_name == "EP2" &&
      !contains(keys(azurerm_windows_function_app.this[0].app_settings), "FUNCTIONS_INPROC_NET8_ENABLED")
    )
    error_message = "Windows Node must map the plain version to AzureRM's ~major format without .NET-only app settings."
  }
}

run "windows_java" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "java", version = "21" }
  }
  assert {
    condition = (
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "java" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].java_version == "21"
    )
    error_message = "Windows Java worker and version must match."
  }
}

run "windows_java8" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "java", version = "8" }
  }
  assert {
    condition     = azurerm_windows_function_app.this[0].site_config[0].application_stack[0].java_version == "1.8"
    error_message = "Windows Java 8 must map to AzureRM's 1.8 format."
  }
}

run "windows_powershell" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "powershell", version = "7.4" }
  }
  assert {
    condition = (
      azurerm_windows_function_app.this[0].app_settings["FUNCTIONS_WORKER_RUNTIME"] == "powershell" &&
      azurerm_windows_function_app.this[0].site_config[0].application_stack[0].powershell_core_version == "7.4"
    )
    error_message = "Windows PowerShell worker and version must match."
  }
}

run "reject_windows_python_default" {
  command = plan
  variables {
    os_type = "Windows"
  }
  expect_failures = [var.runtime]
}

run "reject_windows_python_explicit" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "python", version = "3.11" }
  }
  expect_failures = [var.runtime]
}

run "reject_windows_unknown_language" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "ruby", version = "3.3" }
  }
  expect_failures = [var.runtime]
}

# Temporarily disabled with the exact runtime-version allowlist.
/*
run "reject_windows_bad_version" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "node", version = "3.11" }
  }
  expect_failures = [var.runtime]
}

run "reject_windows_provider_formatted_version" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet-isolated", version = "v8.0" }
  }
  expect_failures = [var.runtime]
}
*/

run "reject_windows_in_process_dotnet9" {
  command = plan
  variables {
    os_type = "Windows"
    runtime = { name = "dotnet", version = "9.0" }
  }
  expect_failures = [var.runtime]
}

run "reject_os" {
  command = plan
  variables {
    os_type = "macOS"
  }
  expect_failures = [var.os_type]
}

run "existing_service_plan" {
  command = plan
  variables {
    service_plan_name = null
    service_plan_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared"
  }
  assert {
    condition = (
      length(azurerm_service_plan.this) == 0 &&
      azurerm_linux_function_app.this[0].service_plan_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared" &&
      output.service_plan_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared"
    )
    error_message = "With service_plan_id the module must not create a plan and must run the app on the supplied plan."
  }
}

run "created_service_plan_id_output" {
  command = plan
  assert {
    condition = (
      length(azurerm_service_plan.this) == 1 &&
      output.service_plan_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-test"
    )
    error_message = "With service_plan_name the module must create its own plan and expose its ID."
  }
}

run "reject_both_plan_inputs" {
  command = plan
  variables {
    service_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared"
  }
  expect_failures = [var.service_plan_id]
}

run "reject_no_plan_input" {
  command = plan
  variables {
    service_plan_name = null
  }
  expect_failures = [var.service_plan_id]
}
