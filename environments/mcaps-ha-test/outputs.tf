output "resource_group_name" {
  value = module.lab.resource_group_name
}

output "resource_group_id" {
  value = module.lab.resource_group_id
}

output "vm_name" {
  value = module.lab.virtual_machines["primary"].name
}

output "vm_private_ip_address" {
  value = module.lab.virtual_machines["primary"].private_ip_address
}

output "vm_windows_admin_password" {
  value     = module.lab.vm_windows_admin_passwords["primary"]
  sensitive = true
}

output "postgresql_fqdn" {
  value = module.lab.postgresql_fqdn
}

output "mysql_fqdn" {
  value = module.lab.mysql_servers["primary"].fqdn
}

output "nat_gateway_public_ip_address" {
  value = module.lab.nat_gateway_public_ip_address
}
