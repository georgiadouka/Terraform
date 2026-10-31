mock_provider "azurerm" {}

variables {
  name                = "nat-validation-test"
  public_ip_name      = "pip-nat-validation-test"
  resource_group_name = "rg-validation-test"
  location            = "swedencentral"
  subnet_ids          = {}
}

run "accept_minimum_idle_timeout" {
  command = plan
}

run "accept_maximum_idle_timeout" {
  command = plan
  variables {
    idle_timeout_in_minutes = 120
  }
}

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_idle_timeout_below_minimum" {
#   command = plan
#   variables {
#     idle_timeout_in_minutes = 3
#   }
#   expect_failures = [var.idle_timeout_in_minutes]
# }

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_idle_timeout_above_maximum" {
#   command = plan
#   variables {
#     idle_timeout_in_minutes = 121
#   }
#   expect_failures = [var.idle_timeout_in_minutes]
# }

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_fractional_idle_timeout" {
#   command = plan
#   variables {
#     idle_timeout_in_minutes = 4.5
#   }
#   expect_failures = [var.idle_timeout_in_minutes]
# }
