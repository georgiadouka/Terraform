mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-web-test"
    }
  }

  mock_resource "azurerm_linux_web_app" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-linux"
      default_hostname = "app-linux.azurewebsites.net"
      identity = {
        principal_id = "11111111-1111-1111-1111-111111111111"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }

  mock_resource "azurerm_windows_web_app" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/sites/app-windows"
      default_hostname = "app-windows.azurewebsites.net"
      identity = {
        principal_id = "33333333-3333-3333-3333-333333333333"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
}

variables {
  name                      = "app-test"
  service_plan_name         = "asp-web-test"
  resource_group_name       = "rg-test"
  location                  = "swedencentral"
  virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/web-app"
}

run "linux_code_default" {
  command = plan

  assert {
    condition = (
      length(azurerm_linux_web_app.this) == 1 &&
      length(azurerm_windows_web_app.this) == 0 &&
      azurerm_service_plan.this.os_type == "Linux" &&
      azurerm_service_plan.this.sku_name == "B1" &&
      azurerm_linux_web_app.this[0].site_config[0].application_stack[0].node_version == "22-lts" &&
      !azurerm_linux_web_app.this[0].public_network_access_enabled &&
      azurerm_linux_web_app.this[0].https_only &&
      azurerm_linux_web_app.this[0].site_config[0].vnet_route_all_enabled &&
      output.mode == "linux" &&
      output.default_hostname == "app-linux.azurewebsites.net"
    )
    error_message = "Linux mode must create a private Node 22 Web App on the default B1 plan."
  }
}

run "windows_code" {
  command = plan

  variables {
    mode    = "windows"
    runtime = { name = "dotnet", version = "8.0" }
  }

  assert {
    condition = (
      length(azurerm_linux_web_app.this) == 0 &&
      length(azurerm_windows_web_app.this) == 1 &&
      azurerm_service_plan.this.os_type == "Windows" &&
      azurerm_windows_web_app.this[0].site_config[0].application_stack[0].current_stack == "dotnet" &&
      azurerm_windows_web_app.this[0].site_config[0].application_stack[0].dotnet_version == "v8.0" &&
      !azurerm_windows_web_app.this[0].ftp_publish_basic_authentication_enabled &&
      !azurerm_windows_web_app.this[0].webdeploy_publish_basic_authentication_enabled &&
      output.mode == "windows" &&
      output.default_hostname == "app-windows.azurewebsites.net"
    )
    error_message = "Windows mode must create only a private Windows .NET Web App."
  }
}

run "linux_container" {
  command = plan

  variables {
    mode = "container"
  }

  assert {
    condition = (
      length(azurerm_linux_web_app.this) == 1 &&
      length(azurerm_windows_web_app.this) == 0 &&
      azurerm_linux_web_app.this[0].site_config[0].application_stack[0].docker_registry_url == "https://mcr.microsoft.com" &&
      azurerm_linux_web_app.this[0].site_config[0].application_stack[0].docker_image_name == "appsvc/staticsite:latest" &&
      azurerm_linux_web_app.this[0].app_settings["WEBSITES_PORT"] == "80" &&
      output.mode == "container"
    )
    error_message = "Container mode must create a Linux Web App with the public sample image and configured container port."
  }
}

run "reject_unsupported_mode" {
  command = plan

  variables {
    mode = "freebsd"
  }

  expect_failures = [var.mode]
}

run "reject_windows_python" {
  command = plan

  variables {
    mode    = "windows"
    runtime = { name = "python", version = "3.11" }
  }

  expect_failures = [var.runtime]
}

run "reject_unsupported_plan_sku" {
  command = plan

  variables {
    service_plan_sku_name = "Y1"
  }

  expect_failures = [var.service_plan_sku_name]
}

run "reject_insecure_container_registry" {
  command = plan

  variables {
    container = { registry_url = "http://mcr.microsoft.com" }
  }

  expect_failures = [var.container]
}

run "reject_invalid_container_port" {
  command = plan

  variables {
    container = { port = 0 }
  }

  expect_failures = [var.container]
}
