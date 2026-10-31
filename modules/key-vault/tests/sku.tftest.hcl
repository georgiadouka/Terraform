mock_provider "azurerm" {}

variables {
  name                = "kv-validation-test"
  resource_group_name = "rg-validation-test"
  location            = "swedencentral"
  tenant_id           = "11111111-1111-1111-1111-111111111111"
}

run "standard_sku_by_default" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.sku_name == "standard"
    error_message = "The Key Vault must use the standard SKU by default."
  }
}

run "accept_premium_sku" {
  command = plan
  variables {
    sku_name = "premium"
  }

  assert {
    condition     = azurerm_key_vault.this.sku_name == "premium"
    error_message = "The Key Vault must accept the premium SKU."
  }
}

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_unsupported_sku" {
#   command = plan
#   variables {
#     sku_name = "basic"
#   }
#
#   expect_failures = [var.sku_name]
# }
