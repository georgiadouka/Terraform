mock_provider "azurerm" {}

variables {
  name                = "asp-test"
  resource_group_name = "rg-test"
  location            = "swedencentral"
}

run "linux_basic_default" {
  command = plan

  assert {
    condition = (
      azurerm_service_plan.this.os_type == "Linux" &&
      azurerm_service_plan.this.sku_name == "B1" &&
      output.name == "asp-test"
    )
    error_message = "The plan must default to Linux B1."
  }
}

run "windows_elastic_premium" {
  command = plan

  variables {
    os_type  = "Windows"
    sku_name = "EP2"
  }

  assert {
    condition     = azurerm_service_plan.this.os_type == "Windows" && azurerm_service_plan.this.sku_name == "EP2"
    error_message = "The plan must accept Windows and Elastic Premium SKUs."
  }
}

run "reject_unsupported_os" {
  command = plan

  variables {
    os_type = "WindowsContainer"
  }

  expect_failures = [var.os_type]
}

run "reject_consumption_sku" {
  command = plan

  variables {
    sku_name = "Y1"
  }

  expect_failures = [var.sku_name]
}

run "reject_free_sku" {
  command = plan

  variables {
    sku_name = "F1"
  }

  expect_failures = [var.sku_name]
}
