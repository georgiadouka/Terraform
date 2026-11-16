# METLEN demo, step 4 of 8.
# Databases: Azure SQL, PostgreSQL, MySQL and Cosmos DB.
#
# Each step file describes the whole environment: the previous step plus
# the blocks marked with this step. Run it with demo/environment.tfvars;
# see demo/README.md.

naming_tokens = {
  business_unit = "IT"
  department    = "PPA"
  application   = "GEO"
  environment   = "DEV"
}

# Legacy names for resources the METLEN standard does not cover yet (VMs and
# their disks and NICs).
project_name = "metlen"
environment  = "demo"
naming       = { unique_suffix = "demo1" }

# Step 1: every subnet is listed up front, so later steps only add workloads.
# The key is the subnet role; number is the NN of its METLEN name. Every subnet
# has an NSG, and subnets whose resources need internet access use the NAT
# Gateway of their VNet.
virtual_networks = {
  main = {
    classification = "PRV"
    address_space  = ["10.71.0.0/20"]
    subnets = {
      private_endpoints     = { cidr = "10.71.0.0/24", number = 1, network_security_group = "workloads" }
      virtual_machines      = { cidr = "10.71.1.0/26", number = 2, network_security_group = "servers", route_table = "egress", nat_gateway = true }
      web_app_integration   = { cidr = "10.71.2.0/26", number = 3, network_security_group = "workloads", nat_gateway = true }
      function_integration  = { cidr = "10.71.2.64/26", number = 4, network_security_group = "workloads", nat_gateway = true }
      postgresql            = { cidr = "10.71.3.0/28", number = 5, network_security_group = "workloads" }
      mysql                 = { cidr = "10.71.3.16/28", number = 6, network_security_group = "workloads" }
      "container_apps/apps" = { cidr = "10.71.4.0/27", number = 9, network_security_group = "workloads", nat_gateway = true }
      logic_app_integration = { cidr = "10.71.2.128/26", number = 14, network_security_group = "workloads", nat_gateway = true }
    }
  }
  edge = {
    classification = "PUB"
    address_space  = ["10.72.0.0/22"]
    subnets = {
      private_endpoints = { cidr = "10.72.0.0/26", number = 1, network_security_group = "edge" }
      virtual_machines  = { cidr = "10.72.1.0/26", number = 2, network_security_group = "edge", nat_gateway = true }
    }
  }
}

# Step 1: rule sets only; subnets pick one with network_security_group. Two
# PRV groups need a sequence (NN) to get different names.
network_security_groups = {
  servers = {
    sequence = "01"
    security_rules = {
      allow-ssh-from-vnet = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        destination_port_range     = "22"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
      }
    }
  }
  workloads = { sequence = "02" }
  edge      = {}
}

# Step 1: a real spoke sends 0.0.0.0/0 to the hub firewall. The demo hub has no
# firewall, so this route only shows a route table on a subnet; internet
# traffic keeps using the NAT Gateway.
route_tables = {
  egress = {
    routes = {
      unused-range = {
        address_prefix = "192.168.250.0/24"
        next_hop_type  = "None"
      }
    }
  }
}

# Step 2: private Key Vault and Premium container registry.
key_vaults = {
  secrets = { sequence = "01" }
}

container_registries = {
  images = { sequence = "01" }
}

# Step 2: storage with blob and file Private Endpoints. Storage sequences are
# unique across every storage account, including the Function App and Logic
# App host storage added in step 5.
storage_accounts = {
  data = {
    sequence   = "01"
    containers = ["uploads", "archive"]
  }
}

premium_file_accounts = {
  shares = {
    sequence    = "02"
    file_shares = { team = { quota_gb = 100 } }
  }
}

# Step 3: one VM per VNet (passwords come from TF_VAR_vm_admin_password).
# Standard HDD keeps the demo cheap; production would use Premium SSD.
virtual_machines = {
  app = {
    os_disk = { storage_account_type = "Standard_LRS" }
    data_disks = {
      data = { lun = 0, disk_size_gb = 32, storage_account_type = "Standard_LRS" }
    }
  }
  dmz = {
    virtual_network = "edge"
    os_disk         = { storage_account_type = "Standard_LRS" }
    data_disks      = {}
  }
}

# Step 3: every VM is backed up to one Recovery Services vault with the
# default policy (daily at 23:00 UTC, 30 daily recovery points).
vm_backup = {
  sequence = "01"
  policies = { default = {} }
}

# Step 4: Azure SQL uses Entra ID sign-in only; PostgreSQL and MySQL take
# TF_VAR_database_admin_password. All of them are private.
azure_sql_servers = {
  sales = { sequence = "01" }
}

postgresql_servers = {
  orders = { sequence = "01" }
}

mysql_servers = {
  legacy = { sequence = "01" }
}

cosmos_db_accounts = {
  catalog = { sequence = "01" }
}
