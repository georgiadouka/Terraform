locals {
  # Generated from the METLEN naming tokens, which are validated against
  # locals.naming-dictionary.tf, so tags carry the same approved codes as the
  # resource names. The standard's tag set (§7.2) is not approved yet; tags
  # without a naming token (owner, cost center, ...) come from var.tags.
  # Region is the Azure display name (the code is for names only); a region
  # missing from region_names falls back to var.location.
  # "Start Date" is the UTC date of the first apply (DD/MM/YYYY).
  default_tags = {
    Application  = var.naming_tokens.application
    BU           = var.naming_tokens.business_unit
    Department   = var.naming_tokens.department
    Environment  = var.naming_tokens.environment
    Region       = lookup(local.naming_dictionary.region_names, lower(replace(var.location, " ", "")), var.location)
    ManagedBy    = "Terraform"
    "Start Date" = terraform_data.start_date.input
  }

  # Azure tag names are case-insensitive, so a tag in var.tags replaces the
  # default with the same name in any casing (environment replaces
  # Environment). Sending both fails under Azure Policy with 409
  # AmbiguousPolicyEvaluationPaths.
  common_tags = merge(
    {
      for name, value in local.default_tags : name => value
      if !contains([for tag in keys(var.tags) : lower(tag)], lower(name))
    },
    var.tags
  )
}
