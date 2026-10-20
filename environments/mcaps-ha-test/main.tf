terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

module "lab" {
  source = "../lab"

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  location        = var.location
  project_name    = "metlen"
  environment     = "hatest"
  naming          = { unique_suffix = var.unique_suffix }

  address_space = ["10.43.0.0/20"]
  subnet_cidrs = {
    private_endpoints    = "10.43.0.0/24"
    virtual_machines     = "10.43.1.0/24"
    web_app_integration  = "10.43.8.0/26"
    function_integration = "10.43.4.0/24"
    postgresql           = "10.43.5.0/24"
    mysql                = "10.43.6.0/24"
    sql_managed_instance = "10.43.7.0/27"
  }

  services = {
    postgresql = true
  }

  virtual_machines = {
    primary = var.virtual_machine
  }
  postgresql = var.postgresql
  mysql_servers = {
    primary = var.mysql
  }
  tags = var.tags
}
