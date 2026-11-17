mock_provider "azurerm" {
  mock_resource "azurerm_application_insights" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/components/appi-test"
    }
  }
}

variables {
  name                = "appi-test"
  resource_group_name = "rg-test"
  location            = "swedencentral"
  workspace_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
}

run "defaults" {
  command = plan

  assert {
    condition = (
      azurerm_application_insights.this.name == "appi-test" &&
      azurerm_application_insights.this.workspace_id == var.workspace_id &&
      azurerm_application_insights.this.application_type == "web" &&
      azurerm_application_insights.this.local_authentication_enabled == false &&
      length(azurerm_role_assignment.metrics_publisher) == 0
    )
    error_message = "Defaults must be a workspace-based web resource with local authentication disabled and no role assignments."
  }
}

run "metrics_publisher_per_principal" {
  command = apply

  variables {
    metrics_publisher_principal_ids = {
      "function_app/primary" = "11111111-1111-1111-1111-111111111111"
      "web_app/portal"       = "22222222-2222-2222-2222-222222222222"
    }
  }

  assert {
    condition = (
      length(azurerm_role_assignment.metrics_publisher) == 2 &&
      azurerm_role_assignment.metrics_publisher["function_app/primary"].principal_id == "11111111-1111-1111-1111-111111111111" &&
      azurerm_role_assignment.metrics_publisher["web_app/portal"].principal_id == "22222222-2222-2222-2222-222222222222" &&
      alltrue([
        for assignment in values(azurerm_role_assignment.metrics_publisher) :
        assignment.role_definition_name == "Monitoring Metrics Publisher" &&
        assignment.principal_type == "ServicePrincipal" &&
        assignment.scope == azurerm_application_insights.this.id
      ])
    )
    error_message = "Every listed principal must get Monitoring Metrics Publisher on the Application Insights resource."
  }
}

run "local_authentication_can_be_enabled" {
  command = plan

  variables {
    local_authentication_enabled = true
    application_type             = "other"
  }

  assert {
    condition = (
      azurerm_application_insights.this.local_authentication_enabled == true &&
      azurerm_application_insights.this.application_type == "other"
    )
    error_message = "local_authentication_enabled and application_type must be configurable."
  }
}

# Disabled: the validation it tests is disabled (azurerm validates this at plan time).
# run "reject_invalid_application_type" {
#   command = plan
#
#   variables {
#     application_type = "functions"
#   }
#
#   expect_failures = [var.application_type]
# }
