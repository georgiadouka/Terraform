# Azure can return the subnet ID with different casing than configured, for
# example a lowercase resource group name for endpoints created after a policy
# or SQL Managed Instance updated the subnet. Resource IDs are
# case-insensitive, so the endpoint compares the lowercase ID: it ignores
# subnet_id itself and is replaced only when the lowercase ID changes, which
# still moves it to a genuinely different subnet.
resource "terraform_data" "subnet_id" {
  input = lower(var.subnet_id)
}

resource "azurerm_private_endpoint" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = var.private_service_connection_name
    private_connection_resource_id = var.private_connection_resource_id
    is_manual_connection           = false
    subresource_names              = var.subresource_names
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) == 0 ? [] : [1]

    content {
      name                 = var.private_dns_zone_group_name
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }

  lifecycle {
    ignore_changes       = [subnet_id]
    replace_triggered_by = [terraform_data.subnet_id]
  }
}
