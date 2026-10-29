resource "azurerm_application_insights" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  workspace_id                 = var.workspace_id
  application_type             = var.application_type
  local_authentication_enabled = var.local_authentication_enabled
  tags                         = var.tags
}

# With local authentication disabled, telemetry is accepted only from Entra
# identities that hold this role on the resource.
resource "azurerm_role_assignment" "metrics_publisher" {
  for_each = var.metrics_publisher_principal_ids

  scope                = azurerm_application_insights.this.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
