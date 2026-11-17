output "environment_id" {
  description = "Container Apps environment ID."
  value       = azurerm_container_app_environment.this.id
}

output "environment_name" {
  description = "Container Apps environment name."
  value       = azurerm_container_app_environment.this.name
}

output "default_domain" {
  description = "Environment default domain, which is also the name of its private DNS zone."
  value       = azurerm_container_app_environment.this.default_domain
}

output "static_ip_address" {
  description = "Internal Container Apps environment IP address."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "dedicated_workload_profile_names" {
  description = "Azure profile names keyed by logical label."
  value       = local.dedicated_workload_profile_names
}

output "apps" {
  description = "Container Apps keyed by logical name."
  value = {
    for key, app in azurerm_container_app.this : key => {
      id                    = app.id
      name                  = app.name
      fqdn                  = app.ingress[0].fqdn
      workload_profile_name = app.workload_profile_name
    }
  }
}
