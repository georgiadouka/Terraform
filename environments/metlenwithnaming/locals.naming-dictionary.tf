# Controlled METLEN naming dictionary (METLEN Azure Naming Standard v0.2).
# Only values listed here can be used in resource names; Terraform rejects any
# other value at plan time. Changes to this file are changes to the standard and
# should go through review.
locals {
  naming_dictionary = {
    # Approved token values (§3.1). Extend only with values approved by the
    # token owners.
    business_units = ["IT"]
    departments    = ["PPA"]
    applications   = ["ECM", "GEO"]
    environments   = ["DEV", "UAT", "PRD"]

    # Network exposure classifier for the network naming family (§3.1).
    network_classifications = ["PUB", "PRV"]

    # Azure location -> METLEN region code (§3.1, decision D-02 pending).
    region_codes = {
      westeurope         = "WEU"
      swedencentral      = "SWE"
      germanywestcentral = "GWC"
    }

    # Three-character resource-type codes (§4).
    resource_codes = {
      subscription           = "SBS" # CONFIRMED
      resource_group         = "RGP" # CONFIRMED
      virtual_network        = "VNT" # WORKING
      network_security_group = "NSG" # WORKING
      route_table            = "UDR" # WORKING
      storage_account        = "SOA" # WORKING, compact family
      key_vault              = "KVA" # CONFLICT, compact family pending approval (D-03)
      azure_sql_server       = "SQL" # PROPOSED lowercase variant
      azure_sql_database     = "SQL" # VALIDATE (D-04); unused: database names are chosen by the application
      azure_sql_elastic_pool = "SEL" # Agreed 2026-10-28, not in register v0.2 yet
      sql_managed_instance   = "SMI" # Agreed 2026-10-28, not in register v0.2 yet; lowercase variant
      app_service            = "APP" # WORKING
      app_service_plan       = "ASP" # WORKING
      function_app           = "FUN" # WORKING, full family without NN
      container_app          = "CAP" # CONFLICT, lowercase variant (2-32 characters)
      container_apps_env     = "CEV" # VALIDATE
      load_balancer          = "LBL" # WORKING
      nat_gateway            = "NGW" # Agreed 2026-10-28, not in register v0.2 yet
      public_ip              = "PIP" # Agreed 2026-10-28, not in register v0.2 yet
      log_analytics          = "LAW" # Agreed 2026-10-28, not in register v0.2 yet
      # Not in the METLEN register yet: working assumptions, as suggested in
      # the review of the standard (three characters, no exception needed).
      postgresql_server = "PGS"
      mysql_server      = "MYS"
      # Not in the METLEN register yet: working assumption, compact family.
      container_registry = "ACR"
      # Not in the METLEN register yet: working assumption. Account uses the
      # lowercase variant, database and container the compact family.
      cosmos_db_account = "CDB"
    }
  }
}
