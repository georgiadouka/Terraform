# A storage account processes one Private Endpoint connection at a time and
# rejects concurrent ones with StorageAccountOperationInProgress, so endpoints
# are created in a fixed order: blob, file, queue, table. Each subresource has
# its own module call so adding one never changes another's address.

module "blob" {
  count  = contains(keys(var.endpoints), "blob") ? 1 : 0
  source = "../private-endpoint"

  name                            = var.endpoints["blob"].name
  private_service_connection_name = var.endpoints["blob"].private_service_connection_name
  private_dns_zone_group_name     = var.endpoints["blob"].private_dns_zone_group_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  private_connection_resource_id  = var.storage_account_id
  subresource_names               = ["blob"]
  private_dns_zone_ids            = var.endpoints["blob"].private_dns_zone_ids
  tags                            = var.tags
}

module "file" {
  count  = contains(keys(var.endpoints), "file") ? 1 : 0
  source = "../private-endpoint"

  name                            = var.endpoints["file"].name
  private_service_connection_name = var.endpoints["file"].private_service_connection_name
  private_dns_zone_group_name     = var.endpoints["file"].private_dns_zone_group_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  private_connection_resource_id  = var.storage_account_id
  subresource_names               = ["file"]
  private_dns_zone_ids            = var.endpoints["file"].private_dns_zone_ids
  tags                            = var.tags

  depends_on = [module.blob]
}

module "queue" {
  count  = contains(keys(var.endpoints), "queue") ? 1 : 0
  source = "../private-endpoint"

  name                            = var.endpoints["queue"].name
  private_service_connection_name = var.endpoints["queue"].private_service_connection_name
  private_dns_zone_group_name     = var.endpoints["queue"].private_dns_zone_group_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  private_connection_resource_id  = var.storage_account_id
  subresource_names               = ["queue"]
  private_dns_zone_ids            = var.endpoints["queue"].private_dns_zone_ids
  tags                            = var.tags

  # Every earlier subresource is listed so the order holds when one is skipped.
  depends_on = [module.blob, module.file]
}

module "table" {
  count  = contains(keys(var.endpoints), "table") ? 1 : 0
  source = "../private-endpoint"

  name                            = var.endpoints["table"].name
  private_service_connection_name = var.endpoints["table"].private_service_connection_name
  private_dns_zone_group_name     = var.endpoints["table"].private_dns_zone_group_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  private_connection_resource_id  = var.storage_account_id
  subresource_names               = ["table"]
  private_dns_zone_ids            = var.endpoints["table"].private_dns_zone_ids
  tags                            = var.tags

  depends_on = [module.blob, module.file, module.queue]
}
