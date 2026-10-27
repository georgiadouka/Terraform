locals {
  common_tags = merge(
    {
      environment = var.environment
      managedBy   = "terraform"
      project     = var.project_name
      lifecycle   = "ephemeral"
    },
    var.tags
  )
}
