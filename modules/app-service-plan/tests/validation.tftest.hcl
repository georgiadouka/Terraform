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

run "windows_workflow_standard" {
  command = plan

  variables {
    os_type  = "Windows"
    sku_name = "WS1"
  }

  assert {
    condition     = azurerm_service_plan.this.os_type == "Windows" && azurerm_service_plan.this.sku_name == "WS1"
    error_message = "The plan must accept Windows Workflow Standard SKUs for Logic Apps."
  }
}

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_linux_workflow_standard" {
#   command = plan
#
#   variables {
#     sku_name = "WS2"
#   }
#
#   expect_failures = [var.sku_name]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_unsupported_os" {
#   command = plan
#
#   variables {
#     os_type = "WindowsContainer"
#   }
#
#   expect_failures = [var.os_type]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_consumption_sku" {
#   command = plan
#
#   variables {
#     sku_name = "Y1"
#   }
#
#   expect_failures = [var.sku_name]
# }

# Disabled: the validation it tests is disabled (the root module validates this value).
# run "reject_free_sku" {
#   command = plan
#
#   variables {
#     sku_name = "F1"
#   }
#
#   expect_failures = [var.sku_name]
# }
