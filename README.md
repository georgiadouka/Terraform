# Modular Azure Terraform platform

This repository contains reusable Terraform modules and a tested ephemeral lab
composition for Azure. The lab is private by default and was deployed,
smoke-tested, and destroyed successfully in Sweden Central.

See the [execution guide](docs/execution-guide.md) for detailed setup,
deployment, validation, teardown, remote-state, and troubleshooting steps.

## Repository layout

This directory is the repository boundary. It keeps the reusable modules,
deployable environment composition, scripts, and documentation versioned
together:

```text
.
|-- environments/lab/  # General lab root module and environment configuration
|-- environments/mcaps-ha-test/ # Isolated Windows VM and database HA deployment
|-- modules/           # Reusable resource modules
|-- scripts/           # Plan, test, and teardown automation
`-- docs/              # Operator guidance
```

Keeping these parts in one repository makes interface changes atomic and lets
the lock file, example values, modules, and guide evolve together. Split a
module into its own repository only when it needs an independent release and
versioning lifecycle.

### Lab configuration structure

The lab root module keeps resource and module declarations in
[`main.tf`](environments/lab/main.tf), with locals grouped by responsibility:

| File | Responsibility |
|---|---|
| [`locals.naming.tf`](environments/lab/locals.naming.tf) | Shared naming inputs, logical-key tokens, and generated resource names |
| [`locals.network.tf`](environments/lab/locals.network.tf) | Subnet enablement and definitions, address planning, and NAT requirements |
| [`locals.private-connectivity.tf`](environments/lab/locals.private-connectivity.tf) | Private Endpoint catalog, target IDs, and shared Private DNS zones and links |
| [`locals.tags.tf`](environments/lab/locals.tags.tf) | Common tags and environment overrides |

Terraform evaluates all `.tf` files in this directory as one module. These
files share the same local namespace; their filenames do not define evaluation
order or create module boundaries. Function host storage endpoints remain
separate from service endpoints so the Function App can depend on its storage
connectivity without a dependency cycle.

### Module file structure

Every module under [`modules/`](modules) follows the standard Terraform module
layout:

| File | Responsibility |
|---|---|
| `versions.tf` | Terraform and `azurerm` provider version constraints |
| `variables.tf` | Input variables, including type constraints and validation |
| `main.tf` | Locals, data sources, and resources |
| `outputs.tf` | Output values exposed to the calling module |
| `tests/*.tftest.hcl` | Plan-time tests with a mocked `azurerm` provider, where present |

Each module declares `azurerm ~> 4.0`, matching the environment lock files, so
`terraform init`, `validate`, and `test` resolve the same provider major version
when a module is checked on its own.

## Implemented modules

| Module | Purpose | Private connectivity |
|---|---|---|
| `resource-group` | Resource group lifecycle | N/A |
| `network` | VNet and service-specific subnets | Dedicated and delegated subnets |
| `private-dns` | Central Private DNS zones and VNet links | Yes |
| `private-endpoint` | Reusable Private Endpoint and DNS zone group | Yes |
| `storage-account-private-endpoints` | A storage account's `blob`, `file`, `queue`, and `table` Private Endpoints, created one at a time because the account rejects concurrent Private Endpoint connections | Yes |
| `nat-gateway` | Shared static outbound internet egress for VM/VMSS and Container Apps subnets | Standard NAT Gateway and static public IP |
| `network-security-group` | Optional NSGs with security rules, each associated with selected subnets | Subnet-level traffic filtering |
| `route-table` | Optional route tables with user-defined routes, each associated with selected subnets | Subnet-level routing, such as forcing egress through a firewall |
| `virtual-network-peering` | One side of a VNet peering; the lab uses it for spoke-to-hub and hub-to-spoke | Private connectivity to an existing hub VNet |
| `load-balancer` | Internal Standard load balancer with one backend pool, health probes, and load-balancing rules | Private frontend IP on a dedicated subnet; no public IP |
| `virtual-machine` | Linux or Windows VM, NIC, OS disk, and configurable data disks | No VM public IP; outbound through NAT Gateway |
| `vm-backup` | Recovery Services vault (zone-redundant by default), Enhanced (V2) VM backup policies and protected VMs. Used by `environments/metlenwithnaming`, where every VM is backed up by default | Public network access disabled by default; VM backup needs no VM egress or Private Endpoint |
| `virtual-machine-scale-set` | Linux or Windows VMSS with configurable images/disks and fixed or CPU-autoscaled capacity | No instance public IP; outbound through NAT Gateway |
| `key-vault` | RBAC-enabled Key Vault | Public network disabled; Private Endpoint |
| `container-registry` | Premium Azure Container Registry | Public network disabled; Private Endpoint |
| `storage-account` | Blob containers, optional standard SMB shares, and workload data-plane RBAC | Public network disabled; blob/file endpoints |
| `premium-files` | Premium Azure Files account and shares | Public network disabled; file endpoint |
| `azure-sql` | Azure SQL logical server, database, and optional elastic pool | Entra-only auth; public network disabled; Private Endpoint |
| `sql-managed-instance` | Optional 4-vCore General Purpose SQL Managed Instance with its own NSG and route table, built from the `network-security-group` and `route-table` modules | Dedicated delegated subnet; NSG allows only client TDS (1433) from the VNet beyond the service-managed rules; Entra-only auth; no public endpoint |
| `postgresql-flexible` | PostgreSQL Flexible Server and database with optional HA | Delegated subnet and Private DNS |
| `mysql-flexible` | MySQL Flexible Server and database with optional HA | Delegated subnet and Private DNS |
| `cosmos-db` | NoSQL, MongoDB, Cassandra, Gremlin, or Table account with serverless/manual/autoscale throughput | Public network disabled; API-specific Private Endpoint and DNS |
| `container-apps` | Internal Container Apps environment with Consumption, optional dedicated workload profiles, and zero or more Container Apps | Dedicated delegated subnet, internal load balancer, and private wildcard DNS |
| `log-analytics-workspace` | Log Analytics workspace shared by every Container Apps environment, the Application Insights resource and Databricks diagnostic settings | N/A |
| `application-insights` | Workspace-based Application Insights with local authentication disabled and Monitoring Metrics Publisher for the listed identities. Used by `environments/metlenwithnaming` for every Web App, Function App and Logic App | Telemetry egress through NAT Gateway or a firewall; no Private Link (AMPLS) yet |
| `databricks-workspace` | Premium Azure Databricks workspace with VNet injection, its own NSG on both subnets, an optional Access Connector (Unity Catalog identity) with storage role assignments, and optional diagnostics to Log Analytics. Used by `environments/metlenwithnaming` | Two dedicated delegated subnets, no public IPs on clusters; `private` (default) or `backend_private` access through a `databricks_ui_api` Private Endpoint |
| `app-service-plan` | App Service Plan (Basic, Standard, Premium, Elastic Premium or Windows Workflow Standard) that one or more Web Apps, Function Apps or Logic Apps run on | N/A |
| `web-app` | Linux code, Windows code, or Linux container App Service Web App, on its own plan or an existing plan passed as `service_plan_id` | Public network disabled; Private Endpoint and outbound VNet integration |
| `function-app` | Linux or Windows Elastic Premium Function App, on its own plan or an existing Elastic Premium plan passed as `service_plan_id` | Inbound Private Endpoint and outbound VNet integration |
| `logic-app` | Logic App (Standard) on a Windows Workflow Standard (WS1-WS3) plan, its own or an existing one passed as `service_plan_id`, with private host storage over the VNet. Used by `environments/metlenwithnaming` | Public network disabled; Private Endpoint and outbound VNet integration; content share over the VNet |

SQL Managed Instance is disabled by default because it is comparatively
expensive and long-running. The optional lab profile uses General Purpose Gen5,
4 vCores, 32 GiB storage, no zone redundancy, and a dedicated delegated subnet.
Set `services.sql_managed_instance = true` only for an approved test.

The SQL Managed Instance module was applied in an MI-only test on
2026-10-22. A follow-up plan showed no drift against the NSG rules and routes
that Azure adds, and the test was then destroyed. The rest of the lab was
previously applied, smoke-tested, and destroyed.

Azure SQL servers are opt-in through the `azure_sql_servers` map. Each entry
creates one logical server with one database, standalone Basic by default. An
environment owner can enable an elastic pool per server through that entry's
`elastic_pool` object in the environment `.tfvars` file without editing the
reusable module. The
example uses the smallest Sweden Central Basic pool capability: 50 eDTUs,
5,000 MB pool storage (`max_size_gb = 4.8828125` in AzureRM), and 0-5 eDTUs per
database. Each server gets its own Private Endpoint, and all servers share the
`privatelink.database.windows.net` zone; neither changes with pooling because
connectivity is configured on the logical server.

PostgreSQL Flexible Servers are opt-in through the `postgresql_servers` map.
Each entry creates one server with one database and its own generated
administrator password (output `postgresql_administrator_passwords`,
sensitive). All servers share the delegated `postgresql` subnet, which keeps
the `Microsoft.Storage` service endpoint Azure needs for WAL archiving, and the
`privatelink.postgres.database.azure.com` zone. Azure's documented minimum for
that subnet is /28, and a high-availability server uses four addresses;
Terraform rejects a `subnet_cidrs.postgresql` range that is below /28 or too
small for the configured servers at plan time. Server details are in the
`postgresql_servers` output. Two non-HA servers on a /28 have been applied in
Azure: they took consecutive addresses (one each), each FQDN resolved to its
own private IP through the shared zone, each server accepted only its own
password over TLS from a VM in the VNet, and a re-plan showed no drift.

MySQL Flexible Servers are opt-in through the `mysql_servers` map. Each entry
creates one server with one database and its own generated administrator
password (output `mysql_administrator_passwords`, sensitive). All servers share
the delegated `mysql` subnet and the `privatelink.mysql.database.azure.com`
zone. Each server takes one subnet address, or two with high availability;
Terraform rejects a `subnet_cidrs.mysql` range that is too small at plan time.
Server details are in the `mysql_servers` output. Two servers sharing the
subnet and DNS zone have been applied in Azure: each FQDN resolved to its own
private IP, each server accepted only its own password over TLS from a VM in
the VNet, and a re-plan showed no drift.

Container Apps environments are opt-in through the `container_apps_environments`
map. Each entry creates one internal environment on its own delegated subnet,
using the `subnet_cidrs.container_apps` range with the same key (/27 or larger),
plus its own private DNS zone, Consumption plus
optional dedicated workload profiles, and the Container Apps listed in its
`apps` map. All environments send logs to one shared Log Analytics workspace
and use the shared NAT Gateway for outbound traffic. Two environments, one
with a dedicated D4 profile, have been applied in Azure with three apps, which
returned HTTP 200 from inside the VNet and showed no drift on re-plan.

Cosmos DB accounts are opt-in through the `cosmos_db_accounts` map. Each entry
creates one classic RU-based API account with its own `api_type`: NoSQL,
MongoDB, Cassandra, Gremlin, or Table, so one lab can mix APIs. Throughput can be serverless, manual RU/s, or
autoscale, with database/keyspace or container/collection/table/graph scope
where the API supports it. Public access is disabled, and the lab selects the
matching Private Endpoint group and Private DNS zone for each account
automatically. All five APIs and the three throughput modes have been Terraform
plan-validated; NoSQL and Gremlin accounts have also been applied in Azure. `MongoDB` refers to the classic RU-based Cosmos
DB API for MongoDB, not the separate Azure Cosmos DB for MongoDB vCore product.

Virtual Machine Scale Sets are opt-in through the `virtual_machine_scale_sets`
map. The module supports Linux
and Windows Marketplace images, Trusted Launch, system-assigned identity,
private instance networking, and zero or more data-disk templates. Every data
disk is created for every instance. Azure Monitor is the single owner of
runtime capacity: fixed mode uses equal minimum/default/maximum values, while
autoscale mode adds bounded CPU rules. The module and lab integration have
mocked Terraform plan coverage but have not been applied to Azure.

Storage authentication has two independent controls. `storage_use_azuread`
selects whether Terraform uses Entra ID for supported Blob and Queue data-plane
operations; each `storage_accounts` entry's `shared_access_key_enabled` setting
controls whether that account accepts access keys from any client. The secure
default is Entra-only. The Terraform identity must receive its Blob/Queue data
roles before the storage modules run. Optional per-account
`data_plane_role_assignments` create account-scoped roles for workload
identities, not bootstrap access for the Terraform runner.

AzureRM 4.x still provisions `azurerm_storage_share` with Shared Key. Until
file-share provisioning is migrated to the ARM control plane, keep
each Entra-only account's `file_shares` map empty or enable Shared Key where
tenant policy permits it. Premium FileStorage accounts and the current Function
App content share retain the same Shared Key limitation.

The standard storage module accepts LRS, GRS, RAGRS, ZRS, GZRS, and RAGZRS
replication. Container and file-share map keys must use stable lowercase
logical labels of up to 20 letters, digits, or hyphens. File-share quotas must
be positive whole GiB values, and supported Standard tiers are `Cool`, `Hot`,
and `TransactionOptimized`.

## Tested topology

The full lab configuration in `lab.tfvars.example` creates:

- one resource group and one `10.42.0.0/20` VNet;
- separate subnets for the enabled Private Endpoint consumers, VMs, each
  Container Apps environment, Web App VNet integration, Function VNet
  integration, PostgreSQL, and MySQL; SQL Managed Instance adds its dedicated
  subnet only when enabled;
- twelve approved Private Endpoints;
- centralized Private DNS zones for enabled services linked to the VNet;
- one private VM with a managed data disk;
- one private Premium Azure Container Registry;
- one shared NAT Gateway and static public IP for VM/VMSS and Container Apps
  outbound internet traffic;
- standalone or elastic-pooled Azure SQL Database, PostgreSQL, and MySQL;
- internal Container Apps environments, each with its own apps on Consumption
  or an optional dedicated profile;
- a private Linux code, Windows code, or Linux container Web App;
- a private Function App with private host storage;
- Key Vault, standard blob/file storage, and Premium Azure Files.

Environment owners can override the VNet address spaces and every subnet CIDR
through `address_space` and `subnet_cidrs` in their `.tfvars` file. All address
planning lives in `subnet_cidrs`: services never take a CIDR themselves.
`subnet_cidrs.container_apps` maps each Container Apps environment key to its
own range, and `subnet_cidrs.load_balancers` is one range shared by every load
balancer frontend:

```hcl
subnet_cidrs = {
  private_endpoints    = "10.42.0.0/24"
  virtual_machines     = "10.42.1.0/24"
  # ...other shared subnets...
  container_apps = {
    primary = "10.42.2.0/27"   # used by container_apps_environments.primary
    jobs    = "10.42.2.32/27"  # used by container_apps_environments.jobs
  }
  load_balancers = "10.42.9.0/26"
}
```

Terraform
validates the complete current and future address plan for VNet containment and
overlap, but creates only the subnets required by enabled services. Unused
ranges, such as a `container_apps` key with no environment yet, stay reserved
and are checked but not created. The shared
Private Endpoint subnet is created while at least one Key Vault, storage
account, Premium Files account, container registry, Cosmos DB account, or Azure
SQL server is configured, or Web App or Function App is enabled. Enabling a
service later adds its required subnet without changing existing subnet
addresses. Private DNS zones and VNet links are likewise created only for
enabled services; zones shared by multiple services remain while any consumer
is enabled.

All Private Endpoints are declared in one catalog,
`local.private_endpoint_catalog` in
[`locals.private-connectivity.tf`](environments/lab/locals.private-connectivity.tf). Each entry
records whether it is enabled, its target, Private Link subresource, Private
DNS zone, and name token. Endpoint names, the Private DNS zone set, and the
Private Endpoint subnet are all derived from that catalog, and one
`module.private_endpoints` call deploys every endpoint. To expose a new service
through Private Link, add its catalog entry and its resource ID to
`local.private_endpoint_target_ids`. Function host storage endpoints use a
second call, `module.function_storage_private_endpoints`, because the Function
App must wait for them before it is created.

Private DNS was validated from the VM for all eleven service hostnames. Every
hostname resolved to a `10.42.x.x` address, and the internal Container App
returned HTTP 200. The VM's observed public egress address is also checked
against the NAT Gateway public IP.

## Prerequisites

- Terraform 1.10 or newer.
- Azure CLI authenticated to the target subscription.
- Owner or equivalent deployment permissions.
- Sufficient regional quota.

The tested versions were Terraform 1.14.3 and AzureRM 4.81.0. The Azure SQL
module enforces Entra-only authentication to satisfy restrictive subscription
policies without storing SQL administrator passwords.

## Configure

Copy the example variables file:

```powershell
Copy-Item environments\lab\lab.tfvars.example environments\lab\lab.tfvars
```

Use `environments\lab\lab.tfvars` as the only environment-specific
configuration file. Terraform does not load it automatically: pass it to every
plan with `-var-file=lab.tfvars`. Each variables file is self-contained, so a
focused file such as `multi-vm-storage.tfvars` never inherits values from
`lab.tfvars`. Do not create `terraform.tfvars` or `*.auto.tfvars` in
`environments\lab`; Terraform would load them silently into every plan and
test. Set `subscription_id`, `tenant_id`, and tags, then review
the region, naming convention, network ranges, service switches, SKUs, sizes,
and database settings. Optional values have defaults, so users do not need to
understand or override every module input.

Every service is opt-in. With no service switches or resource maps set, the lab
deploys only the resource group and virtual network. Enable single-instance
services with `services.<name> = true` and add entries to `virtual_machines`,
`storage_accounts`, `premium_file_accounts`, `key_vaults`,
`container_registries`, `virtual_machine_scale_sets`, `cosmos_db_accounts`, or
`azure_sql_servers` for keyed resources. Subnets,
Private DNS zones, Private Endpoints, and the NAT Gateway are created only when
an enabled service needs them.

### Virtual Machines

`virtual_machines` is keyed by stable logical names. An empty map creates no
VMs, one entry creates one VM, and multiple entries create multiple VMs:

```hcl
virtual_machines = {
  primary = {
    os_type = "Linux"
    size    = "Standard_B2s_v2"
  }
  worker = {
    os_type = "Linux"
    size    = "Standard_D2s_v5"
  }
  admin = {
    os_type = "Windows"
    size    = "Standard_D2s_v5"
  }
}
```

Each key has its own module instance, NIC, OS disk, data disks, and generated
credentials. VM results and credentials are returned as maps using the same
keys. Keep keys stable because they are part of the Terraform resource
addresses and generated Azure names.

### Storage Accounts

`storage_accounts` and `premium_file_accounts` are keyed by stable logical
names. An empty map creates no accounts, one entry creates one account, and
multiple entries create independent accounts:

```hcl
storage_accounts = {
  application = {
    replication_type = "LRS"
    containers       = ["appdata"]
    file_shares      = {}
  }
  archive = {
    replication_type = "ZRS"
    containers       = ["audit"]
    file_shares      = {}
  }
}

premium_file_accounts = {
  content = {
    replication_type = "LRS"
    file_shares = {
      media = { quota_gb = 100 }
    }
  }
  analytics = {
    replication_type = "ZRS"
    file_shares = {
      models = { quota_gb = 200 }
    }
  }
}
```

Each general-purpose v2 account receives independent blob and file Private
Endpoints. Each premium FileStorage account receives an independent file
Private Endpoint. Account details, child resource IDs, and Private Endpoint IDs
are returned as maps using the same keys. Keep keys stable because they are part
of Terraform resource addresses and generated Azure names. All keys follow the
same naming and lifecycle rules. Remove the storage fields from `services`; map
membership now controls account creation, just as it does for
`virtual_machines`.

### Key Vaults

`key_vaults` is keyed by stable logical names. An empty map creates no vaults,
one entry creates one vault, and multiple entries create independent vaults:

```hcl
key_vaults = {
  primary = {}
  secrets = {}
}
```

Every vault uses RBAC authorization, disables public network access, and
receives its own `vault` Private Endpoint. Each entry can set `sku_name`
(default `standard`; `premium` is needed only for HSM-backed keys) and
`purge_protection_enabled` (default `false`, so the lab can be destroyed and
purged automatically). Vault details, including the private `hostname`, and
Private Endpoint IDs are returned as maps using the same keys. Key Vault names
are globally unique, so changing a key or the naming inputs replaces the vault;
enabling purge protection prevents that vault's name from being reused until
its soft-delete retention ends.

### Container Registries

`container_registries` is keyed by stable logical names. An empty map creates
no registries, and each entry creates an independent registry:

```hcl
container_registries = {
  primary = {}
  images  = {}
}
```

Every registry uses the Premium SKU, which Private Link requires, disables the
admin account and public network access, and receives its own `registry`
Private Endpoint. Registry details, including the `login_server`, and Private
Endpoint IDs are returned as maps using the same keys. Registry names are
globally unique, so changing a key or the naming inputs replaces the registry
and its stored images.

### Virtual Machine Scale Sets

Add an entry to `virtual_machine_scale_sets` for each private Linux or Windows
Uniform VMSS. Each key gets its own scale set, NIC configuration, autoscale
setting, generated credentials, and a 9-character hostname prefix that is
unique per key and within the Windows limit. All scale sets share the VM
subnet and NAT Gateway. `source_image_reference.sku` selects the OS release and
`source_image_reference.version` selects the Marketplace image build. A null
image uses Ubuntu 22.04 Gen2 or Windows Server 2022 Azure Edition.

Data disks are a map keyed by stable logical labels. The labels stabilize
Terraform configuration; Azure creates the physical disks for each instance.
For example, a two-instance scale set with two data-disk templates creates four
data disks in total.

```hcl
virtual_machine_scale_sets = {
  web = {
      os_type = "Linux"
      size    = "Standard_B2s_v2"

      source_image_reference = {
        publisher = "Canonical"
        offer     = "ubuntu-24_04-lts"
        sku       = "server"
        version   = "latest"
      }

      os_disk = {
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb         = 64
      }

      data_disks = {
        app  = { lun = 0, disk_size_gb = 128, storage_account_type = "Premium_LRS" }
        logs = { lun = 1, disk_size_gb = 256 }
      }

      scaling = {
        mode              = "autoscale"
        minimum_instances = 2
        default_instances = 2
        maximum_instances = 6
        cpu = {
          scale_out_threshold = 75
          scale_in_threshold  = 25
          scale_out_count     = 1
          scale_in_count      = 1
          time_window_minutes = 5
          cooldown_minutes    = 5
        }
      }
  }
}
```

For fixed capacity, set `scaling.mode = "fixed"` and
`default_instances` to the desired count. Azure Monitor still owns capacity
and sets the profile minimum, default, and maximum to that value. Terraform
owns the scaling policy but ignores runtime VMSS instance-count drift, avoiding
conflicts after automatic scaling. CPU autoscaling requires a minimum of one:
a zero-instance VMSS has no CPU metric with which to trigger scale-out.

Review regional VM SKU and zone availability, per-SKU data-disk limits, compute
quota, and the cost of the configured maximum before applying. `Manual` is the
default upgrade mode because health-aware rolling upgrades require an
application health signal that this workload-agnostic module cannot infer.

### Internal load balancers

Each `load_balancers` entry creates one internal Standard load balancer. All
frontend IPs share the `subnet_cidrs.load_balancers` range. VMs and scale sets
join a load balancer's single backend pool by setting `load_balancer` to the
entry's key:

```hcl
subnet_cidrs = {
  # ...
  load_balancers = "10.42.9.0/26"
}

load_balancers = {
  web = {
    probes = {
      http = { protocol = "Http", port = 80, request_path = "/" }
    }
    rules = {
      http = { probe = "http", frontend_port = 80, backend_port = 80 }
    }
  }
}

virtual_machines = {
  web1 = { load_balancer = "web" }
  web2 = { load_balancer = "web" }
}

virtual_machine_scale_sets = {
  app = { load_balancer = "web" }
}
```

- The frontend is private only: there is no public IP. Clients reach it from
  inside the VNet (or a peered or connected network).
- Every load balancer's frontend IP goes in one shared subnet,
  `snet-lb-…`, created from `subnet_cidrs.load_balancers` (/29 or larger, the
  Azure minimum) once the first load balancer exists. It holds only frontend
  IPs, so it has no delegation and no NAT Gateway association. Backends stay on
  the shared VM subnet.
- The frontend IP is dynamic by default. Set `private_ip_address` to a usable
  address in `subnet_cidrs.load_balancers` for a static IP; Azure's reserved
  addresses (the first four and the last) and duplicates across load balancers
  are rejected.
- The frontend is zone-redundant (`zones = ["1", "2", "3"]`) by default. Set
  `zones = []` in regions without availability zones. Changing zones replaces
  the load balancer.
- Probes support `Tcp`, `Http`, and `Https`; `Http` and `Https` need a
  `request_path`. Every rule must reference a probe. Rules support `Tcp`,
  `Udp`, and HA ports (`protocol = "All"` with both ports `0`), plus idle
  timeout, session persistence (`load_distribution`), floating IP, and TCP
  reset (on by default).
- The load balancer handles inbound traffic only. Outbound traffic from the
  backends still leaves through the shared NAT Gateway.
- Backend VMs must allow the probe and rule ports. NSGs allow Azure Load
  Balancer probes by default through the `AzureLoadBalancer` service tag.
- A scale set with the default `Manual` upgrade mode applies backend pool
  changes only to new instances; run `az vmss update-instances` to update
  existing ones. VMs join through their NIC and update immediately.
- `load_balancer_backend_address_pool_ids` on a scale set still accepts pools
  outside the lab; they are combined with the `load_balancer` key's pool.

Two load balancers sharing one subnet were applied in Azure: `web` (dynamic
IP, HTTP probe) with two VMs and `data` (static IP, TCP probe, port 8080 to 80)
with a one-instance scale set. Requests were spread across both VMs, the port
translation worked, stopping nginx on one VM moved all traffic to the other,
and a re-plan showed no drift. The same run placed two Container Apps
environments on their key-matched `subnet_cidrs.container_apps` ranges, with a
third range reserved but not created.

### Hub-spoke peering

Set `hub_peering` to attach the lab VNet as a spoke to an existing hub VNet:

```hcl
hub_peering = {
  hub_virtual_network_id = "/subscriptions/<hub-sub>/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
}
```

- Both sides are created by default: `peer-<stem>-to-hub` on the spoke and
  `peer-hub-to-<stem>` on the hub. The hub-side name includes the stem, so
  several spokes can peer to one hub.
- The hub side is managed through the `azurerm.hub` provider alias. Its
  subscription is read from `hub_virtual_network_id`, so the hub can live in a
  separate connectivity subscription in the same tenant. Terraform's identity
  needs Network Contributor (or `virtualNetworks/peer/action` and peering
  write) on the hub VNet. The alias skips resource provider registration.
- Set `create_hub_to_spoke_peering = false` when the platform team owns the hub
  side. The spoke side stays `Initiated` until they create theirs.
- `allow_forwarded_traffic` (default `true`) accepts traffic forwarded by a hub
  firewall or NVA. Pair it with a `route_tables` entry that sends `0.0.0.0/0`
  to the firewall to force spoke egress through the hub.
- `use_remote_gateways = true` makes the spoke use the hub's VPN or ExpressRoute
  gateway and sets `allow_gateway_transit` on the hub side. The hub must have a
  gateway. The hub side is created first so gateway transit exists when the
  spoke side requests it.
- When `address_space` changes, the hub side re-syncs automatically through
  the peering `triggers`.
- Hub and spoke address spaces must not overlap; Azure rejects the peering
  otherwise.

This was applied in an MCAPS sandbox against a separately created hub VNet:
both sides reached `Connected` / `FullyInSync`, adding a spoke address prefix
re-synced the hub side to the new range, and destroy removed both peerings.
A second run against a hub with a `VpnGw1AZ` gateway applied with
`use_remote_gateways = true` (hub `allowGatewayTransit`, spoke
`useRemoteGateways`, both `Connected`), then switched it off and back on in
place without errors.

### Container Apps environments, apps, and workload profiles

Each `container_apps_environments` entry is one environment with its own
subnet, whose range comes from the `subnet_cidrs.container_apps` entry with the
same key. Set the following in the environment variables file to create two
environments: `primary` with two Consumption apps, and `jobs` with a dedicated
general-purpose profile that hosts one app:

```hcl
subnet_cidrs = {
  # ...
  container_apps = {
    primary = "10.42.2.0/27"
    jobs    = "10.42.3.0/24"
  }
}

container_apps_environments = {
  primary = {
    apps = {
      hello = {}
      api   = { image = "mcr.microsoft.com/k8se/quickstart:latest", target_port = 80 }
    }
  }
  jobs = {
    dedicated_workload_profiles = {
      general = {
        workload_profile_type = "D4"
        minimum_count         = 0
        maximum_count         = 3
      }
    }
    apps = {
      worker = { workload_profile = "general" }
    }
  }
}
```

- Environments are matched to ranges by key, not by order, so adding or
  removing one environment never moves another to a different subnet. An
  environment without a matching range is rejected at plan time.
- Each environment needs a subnet to itself: Azure delegates it to
  `Microsoft.App/environments` and no other resource can use it. These are
  workload profiles environments, so the minimum is /27 (18 usable addresses
  after Azure's reservations, up to 90 Consumption replicas or 9 dedicated
  nodes). Subnet size can't change after creation, so size for growth. Terraform
  checks every range for overlap with the other lab subnets.
- Environment keys are 1-12 characters and app keys 1-8 characters: lowercase
  letters, digits, or hyphens, starting with a letter and ending with a letter
  or digit. App names are `<prefix>-<app key>-<environment key>-<suffix>`, for
  example `ca-hello-primary-it6hp`, which keeps the longest name within Azure's
  32-character limit.
- An empty `apps` map creates the environment without apps. Each app runs one
  container with 0.25 vCPU, 0.5 GiB, and 0-1 replicas.
- `dedicated_workload_profiles` is empty by default (Consumption-only).
  Consumption remains available when dedicated profiles are configured. Set an
  app's `workload_profile` to `"Consumption"` (the default) or a profile key in
  the same environment; profiles do not create apps.
- Profile keys are stable logical labels: 1-20 lowercase letters, digits, or
  hyphens, starting with a letter; `consumption` is reserved. Azure profile
  names are generated centrally and are scoped to their environment. Retrieve
  them with `terraform output container_apps_environments`, which also lists
  each app's FQDN and selected profile.
- Minimum/maximum counts are **compute nodes**, not app replicas. Node counts
  must be whole numbers with `0 <= minimum_count <= maximum_count` and a maximum
  of at least one.
- Check regional profile availability, quota, and dedicated billing before
  applying. A positive minimum keeps nodes allocated; zero minimum does not
  guarantee zero dedicated charges. See the
  [Microsoft workload profile documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
  and [subnet requirements](https://learn.microsoft.com/azure/container-apps/custom-virtual-networks).

Changing an environment, app, or profile key renames and replaces that
resource; adding or removing other entries does not rename existing ones.

### Multiple virtual networks (metlenwithnaming)

The [`metlenwithnaming`](environments/metlenwithnaming) environment deploys one
or more VNets from the `virtual_networks` map, which replaces `address_space`,
`subnet_cidrs` and `nat_gateway` of the `lab` environment and holds the whole
network layout: each VNet lists its subnets, and each subnet sets its range,
number, NSG, route table and NAT Gateway use. The map key is a
label that never appears in Azure names. `classification` is the METLEN network
intent, `PRV` (default) or `PUB`, and names everything that belongs to the
VNet:

| Resource | Name |
|---|---|
| VNet | `M-AZU-VNT-<BU>-<DPT>-<APP>-<PUB\|PRV>-<ENV>-<REG>` |
| Subnet | `<DPT><APP><ENV><PUB\|PRV><NN>`, for example `PPAECMDEVPUB02` |
| NAT Gateway / its Public IP | `M-AZU-NGW-…-<PUB\|PRV>-<ENV>-<REG>-<NN>` / `M-AZU-PIP-…-<PUB\|PRV>-<ENV>-<REG>-<NN>` |
| NSG / route table | `M-AZU-NSG-…` / `M-AZU-UDR-…` with the classification of the VNet whose subnets use it |
| VNet peering | `<local VNet name>-to-<remote VNet name>` |
| Private DNS zone link | The name of the linked VNet |

The standard defines no NN for VNets, so each classification can be used once:
at most one `PRV` and one `PUB` VNet. Terraform rejects a second VNet with the
same classification.

```hcl
virtual_networks = {
  main = {
    address_space = ["10.42.0.0/20"]
    subnets = {
      private_endpoints        = { cidr = "10.42.0.0/24", number = 1, network_security_group = "endpoints" }
      virtual_machines         = { cidr = "10.42.1.0/24", number = 2, network_security_group = "compute", nat_gateway = true }
      "container_apps/primary" = { cidr = "10.42.2.0/27", number = 9, nat_gateway = true }
    }
  }
  edge = {
    classification = "PUB"
    address_space  = ["10.43.0.0/22"]
    nat_gateway    = { sequence = "01" }
    subnets = {
      virtual_machines = { cidr = "10.43.1.0/24", number = 2, network_security_group = "frontend", route_table = "egress" }
      load_balancers   = { cidr = "10.43.2.0/28", number = 8 }
    }
  }
}

# Rule sets and route sets only; subnets refer to them by key.
network_security_groups = {
  compute   = { sequence = "01", security_rules = { /* ... */ } }
  endpoints = { sequence = "02", security_rules = { /* ... */ } }
  frontend  = { security_rules = { /* ... */ } } # PUB, from the edge VNet
}
route_tables = {
  egress = { routes = { /* 0.0.0.0/0 to the hub firewall */ } }
}

virtual_machines = {
  app = {}                            # PRV VNet (the default)
  dmz = { virtual_network = "edge" }
}

virtual_network_peerings = {
  main-edge = { virtual_networks = ["main", "edge"] }
}
```

- Every listed subnet is created, used or not, and nothing else is. Subnets
  are independent of workloads: removing a workload (for example the last
  PostgreSQL server) leaves its subnet and the subnet's NSG, route table and
  NAT Gateway associations in place, and adding one needs its subnet listed
  first. Remove a subnet from the map once nothing uses it.
- The subnet key is its role: `private_endpoints`, `virtual_machines`,
  `web_app_integration`, `function_integration`, `logic_app_integration`,
  `postgresql`, `mysql`, `sql_managed_instance`, `load_balancers`,
  `container_apps/<environment key>` or
  `databricks/<workspace key>/<host|container>`. The role sets the
  delegation and the minimum size (/29 for every subnet, /27 for SQL Managed
  Instance and Container Apps, /28 for Databricks).
- `number` is required: it is the NN of the subnet name and must be unique
  within the VNet (every VNet can reuse the same numbers). Keep it stable;
  changing it renames, and therefore replaces, the subnet. The examples keep
  private endpoints 01 … load balancers 08, Container Apps 09, Databricks
  10-13 and Logic App integration 14.
- Every VM, scale set, load balancer, Web App, Function App, Logic App,
  database, SQL Managed Instance and Private Endpoint parent (Storage Account,
  Key Vault, Container Registry, Azure SQL, Cosmos DB, premium files) takes an
  optional `virtual_network`. It defaults to the PRV VNet, or to the only VNet
  when there is one. Terraform rejects a VNet key that does not exist or whose
  `subnets` lacks the subnet the resource needs.
- A Container Apps environment or Databricks workspace is placed in the VNet
  that lists its `container_apps/<key>` or `databricks/<key>/<host|container>`
  subnets; a key can appear in one VNet only, and a workspace's two subnets
  share it.
- A load balancer and its VMs and scale sets must share a VNet, and the apps on
  one App Service Plan must share a VNet because a plan integrates with one
  VNet.
- `nat_gateway = true` on a subnet sends its outbound traffic through the NAT
  Gateway of its VNet, which is created (with `nat_gateway` settings on the
  VNet) only when a subnet uses it; Azure attaches a NAT Gateway to subnets of
  one VNet only.
- A subnet uses an NSG or route table with `network_security_group` or
  `route_table`, so a subnet can never have two. All subnets that use one
  group or table must be in the same VNet, because its name carries that
  VNet's classification; an explicit `classification` must match it. The
  `sql_managed_instance` subnet sets none of the three options, and
  `databricks/…` subnets set no NSG, because their modules attach their own.
- `hub_peering.virtual_networks` lists the VNets to peer with the hub (default:
  every VNet). Peering names are not truncated, so Terraform rejects a hub VNet
  whose name would make them longer than 80 characters.
- `virtual_network_peerings` peers VNets of this deployment in both directions.
  Peered address spaces must not overlap.
- One set of Private DNS zones is linked to every VNet (and each Container Apps
  environment's zone too), so peered VNets resolve each other's Private
  Endpoints. Moving to central, hub-owned zones is planned separately.
- VMs and scale sets keep the legacy names until the METLEN server naming
  process is available (the register marks Virtual Machine as EXCEPTION).

### Azure Databricks workspaces (metlenwithnaming)

The [`metlenwithnaming`](environments/metlenwithnaming) environment creates
Premium Azure Databricks workspaces from the `databricks_workspaces` map. Each
entry uses the `databricks/<key>/host` and `databricks/<key>/container`
subnets of the VNet that lists them, both delegated to
`Microsoft.Databricks/workspaces` and covered by the workspace's own NSG, in
which Azure Databricks manages its required rules. Its Private Endpoints sit in
the same VNet. Clusters never get public IP addresses (secure cluster
connectivity):

```hcl
virtual_networks = {
  main = {
    address_space = ["10.42.0.0/20"]
    subnets = {
      # ...
      "databricks/analytics/host"      = { cidr = "10.42.10.0/26", number = 10, nat_gateway = true }
      "databricks/analytics/container" = { cidr = "10.42.10.64/26", number = 11, nat_gateway = true }
    }
  }
}

databricks_workspaces = {
  analytics = {
    access_connector = { storage_accounts = ["primary"] }
  }
}
```

- `network_access` is `private` by default: public access is disabled and users
  and clusters reach the workspace through one `databricks_ui_api` Private
  Endpoint in the `privatelink.azuredatabricks.net` zone. `backend_private`
  keeps the workspace UI on the internet and only clusters use the endpoint;
  `public` creates no endpoint.
- Browser sign-in to every private workspace in a region goes through a single
  `browser_authentication` Private Endpoint. Following Microsoft's guidance it
  lives on a dedicated workspace (`browser_authentication_workspace = true`,
  private) that runs no workloads and gets no `databricks_ui_api` endpoint or
  Access Connector. A `CanNotDelete` lock protects it (`delete_lock = false`
  turns it off); `terraform destroy` removes the lock first. Without such an
  entry Terraform warns, because sign-in then works only if a hub already
  provides the endpoint.
- Clusters need outbound internet access even with Private Link. Set
  `nat_gateway = true` on both subnets or route them to a hub firewall;
  Terraform warns when a workspace has neither.
- Subnets must be /28 or larger (/26 recommended), the VNet /16 to /24, and
  neither can change after creation. A second workspace in the same VNet needs
  its own subnet numbers, for example 12 and 13.
- The Access Connector is created by default; `storage_accounts` grants its
  identity Storage Blob Data Contributor on those `storage_accounts` keys for
  Unity Catalog. Diagnostics send every workspace log category (`allLogs`, the
  only category group Azure Databricks supports) to the shared Log Analytics
  workspace; list `diagnostics.categories` to send only some and limit cost.
- Only the Azure resources are managed here. Clusters, jobs, Unity Catalog
  objects and permissions belong to the `databricks/databricks` provider, using
  the `workspace_url` from `terraform output databricks_workspaces`, preferably
  in a separate configuration.
- After `terraform destroy`, check the managed resource groups
  (`M-AZU-RGP-…-<sequence>`). In the 2026-10-29 test, Azure Databricks added a
  `unity-catalog-access-connector` to them when it activated the workspaces,
  and they stayed behind with the root storage account after the workspaces
  were deleted. Once the workspace is gone they have no deny assignment, so
  `az group delete` removes them; otherwise the root storage name stays taken.

### Application Insights (metlenwithnaming)

The [`metlenwithnaming`](environments/metlenwithnaming) environment creates one
workspace-based Application Insights resource,
`M-AZU-AIN-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>`, shared by every Web App,
Function App and Logic App. It is on by default whenever at least one app
exists and stores its data in the shared Log Analytics workspace
(`M-AZU-LAW-…`), which is then created too:

```hcl
virtual_networks = {
  main = {
    address_space = ["10.42.0.0/20"]
    subnets = {
      private_endpoints    = { cidr = "10.42.0.0/24", number = 1 }
      web_app_integration  = { cidr = "10.42.8.0/26", number = 3, nat_gateway = true }
      function_integration = { cidr = "10.42.4.0/24", number = 4, nat_gateway = true }
    }
  }
}

log_analytics_workspace = {
  daily_quota_gb = 1 # default 0.1; -1 removes the cap
}

application_insights = {
  sequence = "00" # enabled = false turns telemetry off for every app
}

function_apps = {
  jobs = { service_plan = "functions", storage_sequence = "05", application_insights = false }
}
```

- Ingestion is Microsoft Entra-only. Local (instrumentation key)
  authentication is disabled, each app sets
  `APPLICATIONINSIGHTS_AUTHENTICATION_STRING = Authorization=AAD`, and its
  system-assigned identity gets Monitoring Metrics Publisher on the resource.
  The deployer therefore needs rights to create role assignments (Owner, User
  Access Administrator or Role Based Access Control Administrator); set
  `application_insights.enabled = false` otherwise.
- Web Apps in `linux` and `windows` mode also turn on the App Service agent
  (`ApplicationInsightsAgent_EXTENSION_VERSION` `~3`/`~2`). `container` mode
  gets only the connection settings; the image needs its own Application
  Insights SDK or OpenTelemetry distro.
- Telemetry goes to the public Azure Monitor ingestion endpoint. Subnets are
  private and the apps route all outbound traffic through the VNet, so set
  `nat_gateway = true` on the `web_app_integration`, `function_integration`
  and `logic_app_integration` subnets of the apps' VNet or route them to a hub
  firewall; Terraform warns when an app has neither.
  Azure Monitor Private Link Scope is not implemented yet.
- Application Insights data counts against the Log Analytics daily cap
  (0.1 GB by default). Once the cap is reached, ingestion stops until the next
  day; raise `log_analytics_workspace.daily_quota_gb` for real workloads.
- Set `application_insights = false` on a `web_apps`, `function_apps` or
  `logic_apps` entry to opt that app out. When no app uses it, neither
  resource is created.
- Azure adds a "Failure Anomalies" smart detector alert rule to every new
  Application Insights resource. The provider setting
  `application_insights { disable_generated_rule = true }` in `providers.tf`
  disables it on create and deletes it on destroy; without it the leftover
  rule blocked `terraform destroy` of the resource group in the live test.

### Logic Apps (Standard) (metlenwithnaming)

The [`metlenwithnaming`](environments/metlenwithnaming) environment creates
private Logic Apps (Standard) from the `logic_apps` map (default: none). They
follow the Function App pattern: each app runs on a plan from
`app_service_plans`, has its own host storage account and joins an integration
subnet, and nothing is reachable from the internet.

```hcl
virtual_networks = {
  main = {
    address_space = ["10.42.0.0/20"]
    subnets = {
      private_endpoints     = { cidr = "10.42.0.0/24", number = 1 }
      logic_app_integration = { cidr = "10.42.11.0/26", number = 14, nat_gateway = true }
    }
  }
}

app_service_plans = {
  workflows = { sequence = "02", os_type = "Windows", sku_name = "WS1" }
}

logic_apps = {
  orders = {
    service_plan     = "workflows"
    sequence         = "00"
    storage_sequence = "06"
    app_settings     = { "Workflows.RuntimeConfiguration.RetentionInDays" = "30" }
  }
}
```

| Resource | Name | Notes |
|---|---|---|
| Logic App | `M-AZU-LAP-<BU>-<DPT>-<APP>-<ENV>-<REG>-<sequence>` | Global (`<name>.azurewebsites.net`); `sequence` must be unique per app |
| Host storage account | `mazusoa…<storage_sequence>` | Unique across every storage account; content share `logic-app-content` |
| Private Endpoints | `<app name>-sites`, `<storage name>-blob`/`-file`/`-queue`/`-table` | In the `private_endpoints` subnet of the app's VNet |

- **Plans.** Logic Apps run only on Windows Workflow Standard plans (`WS1`,
  `WS2`, `WS3`), which host nothing else: Web Apps need Basic, Standard or
  Premium plans and Function Apps Elastic Premium plans. Several Logic Apps can
  share one plan and then scale together. Terraform rejects a Linux `WS` plan.
- **Networking.** Each app joins the `logic_app_integration` subnet of its
  `virtual_network` (default: the PRV VNet), delegated to
  `Microsoft.Web/serverFarms`, and routes all outbound traffic through it.
  Microsoft recommends a /26 subnet because the subnet size cannot change
  after assignment; /26 is required when apps on more than one plan share it.
  Inbound traffic uses the app's `sites` Private Endpoint only.
- **Storage.** Workflow state, run history and app content live in the app's
  own storage account, reached only through its four Private Endpoints;
  `WEBSITE_CONTENTOVERVNET` (`vnet_content_share_enabled`) keeps the content
  share on the VNet. Logic Apps (Standard) still need the account key, so
  shared key access is enabled on this account only.
- **Runtime.** Functions host `~4` with the Workflows extension bundle, the
  `dotnet` worker runtime and .NET 8, 64-bit, TLS 1.2, FTP and basic
  publishing authentication off. `node_version` (default `22`) sets
  `WEBSITE_NODE_DEFAULT_VERSION` for Inline Code actions; Microsoft reports
  XSLT map issues on Node.js 24, so test before moving. `app_settings` adds
  workflow settings; settings the module or the provider manage (runtime,
  storage, networking, Application Insights) are rejected.
- **Telemetry.** On by default through the shared Application Insights
  resource (see above), with Entra authentication; the integration subnet
  needs NAT or a firewall route.
- **Connectors and deployment.** Built-in connectors run inside the app and
  use the VNet. Azure-hosted managed connectors need outbound access to the
  managed API service, and managed webhook (push) triggers such as Event Grid
  cannot call a private app. Deploy workflows from inside the VNet (or a
  peered network) or from a pipeline agent with access to the `sites` Private
  Endpoint, using Microsoft Entra authentication.

Logic Apps (Standard) have mocked plan tests and a plan against the real
provider; they have not been deployed in the live test yet.

### VM backup (metlenwithnaming)

The [`metlenwithnaming`](environments/metlenwithnaming) environment backs up
every `virtual_machines` entry with Azure Backup to one Recovery Services
vault, `M-AZU-RSV-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>`, built by the
[`vm-backup`](modules/vm-backup) module. The vault is created whenever at
least one VM is backed up:

```hcl
vm_backup = {
  sequence          = "00"
  storage_mode_type = "ZoneRedundant" # or GeoRedundant / LocallyRedundant
  policies = {
    # Daily at 23:00 UTC, 7 days of instant-restore snapshots, 30 daily points.
    default = {}
    critical = {
      frequency                      = "Hourly"
      hour_interval                  = 4
      hour_duration                  = 24
      instant_restore_retention_days = 14
      retention_daily                = 90
      retention_monthly              = { count = 12, days = [1] }
    }
  }
}

virtual_machines = {
  app  = {}                            # backup_policy = "default"
  db   = { backup_policy = "critical" }
  temp = { backup = false }            # not backed up
}
```

- Policies are Enhanced (V2) policies, the only type that protects Trusted
  Launch VMs; the `virtual-machine` module always enables secure boot and
  vTPM. Policy names are scoped to the vault, so each policy is named after
  its key. `vm_backup.enabled = false` turns backup off for every VM.
- Azure VM backup runs over the Azure backbone, so the VM subnets need no NAT
  Gateway, Private Endpoint or DNS zone for it. The vault's public network
  access is disabled by default: backup and full-VM or disk restore still
  work, but file-level restore needs `public_network_access_enabled = true`
  (a vault Private Endpoint is not implemented).
- Choose `storage_mode_type` before the first VM is protected: Azure rejects
  a change afterwards. `cross_region_restore_enabled` needs `GeoRedundant`.
- Azure keeps instant-restore snapshots in a resource group it creates and
  names itself (`AzureBackupRG_<region>_1`), outside Terraform and the
  environment's resource group.
- Soft delete is always on for Recovery Services vaults (Azure secure by
  default; the provider rejects turning it off), so deleted backup data stays
  recoverable for 14 days. For lab teardown, `providers.tf` deletes a VM's
  backup data when its protection is destroyed and purges any remaining items
  when the vault is destroyed; flip both settings (see the comments there) for
  production. Re-enabling backup of a VM within the soft delete period
  resumes the soft-deleted item.
- Not yet live-tested: vault deletion relies on Azure's vault soft delete
  (preview) once its items are soft-deleted, and the leftover
  `AzureBackupRG_<region>_1` group must be deleted by hand after a lab
  teardown.

### App Service Web App modes

`web_app.mode` creates exactly one App Service Web App:

- `linux` (default) supports Node.js, Python, or .NET code stacks;
- `windows` supports Node.js or .NET code stacks;
- `container` creates a Linux custom-container Web App and defaults to
  `mcr.microsoft.com/appsvc/staticsite:latest`.

All modes use a dedicated VNet integration subnet, disable public network
access and basic publishing authentication, create a Private Endpoint, enforce
HTTPS/TLS 1.2, and enable a system-assigned managed identity. The default B1
plan can be replaced with a supported Basic, Standard, or Premium SKU. Set the
plain runtime version for code modes (for example Node.js `22`, Python `3.11`,
or .NET `8.0`); the module converts it to the provider-specific format. Exact
runtime-version allowlists are temporarily disabled, so the module does not
reject other versions. Use these versions, which `az webapp list-runtimes`
reports as supported and the pinned provider (azurerm 4.81) accepts, checked on
2026-10-31:

| Runtime name | Linux versions | Windows versions |
|---|---|---|
| `node` | `22`, `24` | `22` |
| `python` | `3.11`, `3.12`, `3.13`, `3.14` | Not supported |
| `dotnet` | `8.0`, `9.0`, `10.0` | `8.0`, `9.0`, `10.0` |

Azure also supports Node.js 24 on Windows and Node.js 26, Python 3.15, and
.NET 11 on Linux, but azurerm 4.81 rejects them. Run
`az webapp list-runtimes --os linux` (or `--os windows`) to see the current
Azure list; see
[Language runtime support policy](https://learn.microsoft.com/azure/app-service/language-support-policy).
Container mode accepts a registry URL, image name, and listening port. Private
registry role assignments and image publication remain the caller's
responsibility.

### VM OS, Function runtime, and database availability

- Each `virtual_machines` entry's `os_type` selects `Linux` (default) or
  `Windows`. A null
  `source_image_reference` selects Ubuntu 22.04 Gen2 or Windows Server 2022
  Azure Edition respectively; provide publisher, offer, SKU, and version to
  select another compatible Marketplace image. A null OS disk size selects
  32 GiB for Linux or 127 GiB for Windows. Custom images can require larger disks.
  Switching OS replaces the VM; data disks remain managed separately.
- Windows administrator passwords are generated, not placed in the variables
  file. Retrieve the sensitive `vm_windows_admin_passwords` output map from the
  environment directory and select the required VM key. Passwords are stored in
  Terraform state;
  protect state and avoid printing credentials in shared logs. Windows uses a
  separate computer name of at most 15 characters, derived from environment
  and suffix. No public IP or public RDP access is added.

#### Function App OS and runtime compatibility

`function_app.os_type` selects `Linux` (default) or `Windows` for both the
Function App and its Elastic Premium service plan. Set `runtime.name` and
`runtime.version` together. Exact runtime-version allowlists are temporarily
disabled. The module still validates OS/language compatibility and requires
.NET in-process to use version 8.0. The following versions are retained as a
reference for the pinned provider schema:

| Runtime name | Linux versions | Windows versions | Guidance |
|---|---|---|---|
| `python` | `3.11`, `3.12`, `3.13`, `3.14` | Not supported | Python Function Apps require Linux. Python 3.11 is this composition's default. Python 3.15 is in preview on Azure and not accepted by the pinned provider. |
| `node` | `22`, `24` | `22`, `24` | Supply the plain major version, such as `22`. |
| `dotnet-isolated` | `8.0`, `9.0`, `10.0` | `8.0`, `9.0`, `10.0` | Preferred .NET execution model. |
| `dotnet` | `8.0` only | `8.0` only | Legacy in-process model. The module also sets `FUNCTIONS_INPROC_NET8_ENABLED=1`. In-process support ends November 10, 2026. |
| `java` | `8`, `11`, `17`, `21`, `25` | `8`, `11`, `17`, `21`, `25` | Supply `8`; the module maps it to the Windows provider value `1.8`. |
| `powershell` | `7.4` | `7.4`, `7.6` | PowerShell 7.6 is also GA on Linux Premium plans, but the pinned provider accepts only `7`, `7.2`, and `7.4` for Linux Function Apps. |

These are the versions Microsoft lists as generally available for Functions
host v4 that the pinned provider (azurerm 4.81) also accepts, checked against
the [Azure Functions language support table](https://learn.microsoft.com/azure/azure-functions/supported-languages)
on 2026-10-31. Retired versions (Python 3.7-3.10, Node.js 12-20, .NET 6 and 7
isolated, PowerShell 7 and 7.2) are not listed. The module does not enforce the
list, so Azure lifecycle changes do not block a plan; check the table and
regional availability before deployment.

Use plain version values in tfvars (`22`, `8.0`, or `8`), without provider
prefixes such as `~` or `v`. The module performs the required Windows mappings,
for example Node `22` to `~22` and .NET `8.0` to `v8.0`.

The default is valid only as a pair:

```hcl
function_app = {
  os_type = "Linux"
  runtime = {
    name    = "python"
    version = "3.11"
  }
}
```

When selecting Windows, explicitly choose a Windows-compatible runtime:

```hcl
function_app = {
  os_type = "Windows"
  runtime = {
    name    = "dotnet-isolated"
    version = "8.0"
  }
}
```

Hosting remains Elastic Premium (`EP1`, `EP2`, or `EP3`) on Functions host v4.
Deploy matching application code separately. **Changing OS recreates the
Function App and service plan**, creates a new managed identity, and requires
code redeployment plus review of dependent access grants. Private Endpoint and
outbound VNet integration are retained for either OS. Inspect
`function_app_os_type` to confirm the selected OS.

- Each `postgresql_servers` entry's and each `mysql_servers` entry's
  `high_availability` accept
  `enabled`, `mode` (`SameZone` or `ZoneRedundant`), and optional
  `standby_availability_zone`. `zone` selects the primary zone. HA is disabled
  by default and requires General Purpose or Memory Optimized compute.
  **The example MySQL Burstable SKU must be changed before enabling HA.**
  Leave zones null for Azure placement, or use equal zones for SameZone and
  distinct zones for ZoneRedundant. Zones configure initial placement; subsequent
  primary/standby zone changes are ignored to preserve Azure failover placement.
  HA provisions a billed standby and depends
  on regional support, capacity, and quota. MySQL zone-redundant HA has
  existing-server enablement limitations; plan it at creation and review the
  service documentation before changing an existing server.

For example, select Windows with .NET isolated in the environment variables file:

```hcl
function_app = {
  os_type               = "Windows"
  service_plan_sku_name = "EP1"
  runtime = {
    name    = "dotnet-isolated"
    version = "8.0"
  }
}
```

The implementation follows the AzureRM
[Windows Function App stack schema](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/windows_function_app#application_stack)
and Microsoft's [Functions language guidance](https://learn.microsoft.com/azure/azure-functions/supported-languages)
and [.NET in-process configuration](https://learn.microsoft.com/azure/azure-functions/functions-dotnet-class-library#updating-to-target-net-8).
Windows Function Apps have mocked plan coverage, not a live deployment test.

These options have mocked Terraform plan tests. The isolated MCAPS profile
below has also been deployed in Sweden Central with Windows Server 2022,
PostgreSQL 16, and MySQL 8.0.21. Both databases reported healthy zone-redundant
HA, and private DNS and TCP connectivity were verified from Windows. A
post-deployment Terraform plan reported no changes. Forced failover and other
image/runtime/HA variants have not been live-tested.

Run the offline configuration tests after initializing the environment and
each tested module with `terraform init -backend=false`:

```powershell
terraform -chdir=environments\lab validate
terraform -chdir=environments\lab test
terraform -chdir=modules\virtual-machine test
terraform -chdir=modules\container-registry test
terraform -chdir=modules\web-app test
terraform -chdir=modules\function-app test
terraform -chdir=modules\application-insights test
terraform -chdir=modules\vm-backup test
terraform -chdir=modules\postgresql-flexible test
terraform -chdir=modules\mysql-flexible test
terraform -chdir=modules\container-apps test
terraform -chdir=modules\load-balancer test
.\scripts\tests\private-connectivity-smoke.Tests.ps1
```

The tests use mocked Azure providers and plan-only runs; they do not deploy
resources or exercise real database failover. The environment tests override
network/storage plumbing to focus on configuration, credential selection, Web
App mode selection, and Container Apps environment, app, and profile
naming/placement. Workload
profile tests cover defaults, multiple profiles, and invalid inputs. Separate
lab tests confirm that every service is opt-in and lock in Private Endpoint
targets, subresources, DNS zones, and names.

References: [Functions language support](https://learn.microsoft.com/azure/azure-functions/supported-languages),
[PostgreSQL HA](https://learn.microsoft.com/azure/postgresql/high-availability/how-to-configure-high-availability),
and [MySQL HA](https://learn.microsoft.com/azure/mysql/flexible-server/concepts-high-availability).

### Isolated Windows and database HA test

`environments/mcaps-ha-test` reuses the lab composition but enables only a
Windows VM, PostgreSQL, MySQL, and their required private network, DNS, and VM
NAT egress. It has its own local Terraform state, `hatest` resource names, and
`10.43.0.0/20` address space. It does not modify resources in the original lab
state.

Copy that environment's example to its local `terraform.tfvars`, set the
approved sandbox subscription/tenant, and review the image and database SKUs.
Both databases enable billed zone-redundant HA by default, with primary zone 1
and standby zone 2. This profile stays deployed until explicitly destroyed:

```powershell
terraform -chdir=environments\mcaps-ha-test init
terraform -chdir=environments\mcaps-ha-test validate
terraform -chdir=environments\mcaps-ha-test plan -out="windows-ha.tfplan"
terraform -chdir=environments\mcaps-ha-test apply "windows-ha.tfplan"
# After testing, review and confirm cleanup of this isolated environment only:
terraform -chdir=environments\mcaps-ha-test destroy
```

Do not run the full-platform ephemeral smoke workflow against this reduced
profile: that workflow expects the other service hostnames too. Verify Windows
through Azure VM Run Command and inspect both database HA states separately.
Passwords remain generated and sensitive; protect this environment's state as
carefully as the original lab state.

## Naming convention

Every caller-defined Azure resource name is generated centrally from:

```text
<resource-prefix>-<project_name>-<environment>-<unique_suffix>
```

Set all abbreviations and the optional deterministic suffix in the single
`naming` object in `lab.tfvars`. Leaving `naming.unique_suffix = null`
uses a generated five-character suffix that is persisted in Terraform state.
Resource modules receive completed names and do not invent their own names.
This includes SQL Managed Instance, its NSG and route table, subnets,
delegations, NICs, disks, databases, storage data resources, Private Endpoints,
Private Link child names, DNS links, Container Apps resources, Web App
resources, and Function App resources.

Names with stricter Azure rules use the same convention in a valid compact
form. Storage account names contain no hyphens and stay within 24 characters;
Azure Container Registry names contain no hyphens and include a logical-key token, and Key Vault names keep
the suffix and a logical-key token within 24 characters; Cosmos DB account
names keep a logical-key token within 44 characters, and database/container names are compact alphanumeric identifiers compatible with
all supported APIs. Container App names use
`<prefix>-<app key>-<environment key>-<suffix>` within Azure's 32-character
limit; the project and environment labels are left out because App names only
need to be unique within the resource group. Map-based Container Apps workload
profile names use `<prefix>-<logical key>01`, such as `wp-general01`; when that
exceeds Azure's 15-character limit they fall back to
`<prefix up to 3 characters>-<8-character SHA-1 of logical key>01`. Profile
names are scoped to their environment, so every environment reuses them.
Azure-owned or
protocol-defined names cannot be changed, including Private DNS zone FQDNs, `@`/`*` DNS records,
and the Container Apps `Consumption` profile.

Changing a naming prefix, `project_name`, `environment`, or `unique_suffix`
changes resource names and usually forces replacement. Review the plan before
applying. Inspect all computed names with:

```powershell
terraform -chdir=environments\lab output generated_resource_names
```

The checked-in `lab.tfvars.example` contains no secrets. PostgreSQL and
MySQL passwords and the ephemeral VM/VMSS keys are generated by Terraform and
remain only in state; therefore, Terraform state must be treated as sensitive. The
local `lab.tfvars` is ignored by Git, while the dependency lock file is
committed for repeatable provider selection.

## Plan only

```powershell
.\scripts\invoke-ephemeral-lab.ps1 -Action Plan
```

The wrapper reads `environments\lab\lab.tfvars` by default; pass
`-VarFile <file>` to use another variables file from `environments\lab`.

## Apply, smoke-test, and always destroy

The following command applies the lab, executes the private connectivity test
from the VM, and destroys all resources in a `finally` block:

```powershell
.\scripts\invoke-ephemeral-lab.ps1 -Action ApplyDestroy
```

To keep the lab available briefly after the smoke test, use a value from 1 to
60 minutes:

```powershell
.\scripts\invoke-ephemeral-lab.ps1 -Action ApplyDestroy -HoldMinutes 30
```

If PowerShell or the workstation terminates unexpectedly, run:

```powershell
terraform -chdir=environments\lab plan -destroy -var-file=lab.tfvars -out=destroy.tfplan
terraform -chdir=environments\lab apply -auto-approve destroy.tfplan
```

## Production state

The lab currently uses local state to make complete teardown easy. For
production:

1. create a dedicated, persistent state resource group and storage account;
2. enable blob versioning and soft delete;
3. assign least-privilege data-plane RBAC to the deployment identity;
4. run Terraform from a private network path if public storage access is
   disabled;
5. copy `backend.tf.example` to `backend.tf`, populate a backend configuration,
   and run `terraform init -migrate-state`.

Never commit `terraform.tfstate`, `.tfvars`, plan files, credentials, or private
keys.

## Production hardening

Before using the modules outside a lab:

- replace generated VM and VMSS keys with centrally managed SSH public keys;
- prefer workload identities and Entra authentication over database passwords;
- enable Key Vault purge protection;
- add RBAC assignments for application identities;
- add diagnostic settings and organization-standard retention;
- connect the VNet to the customer hub with `hub_peering`, then add DNS
  forwarding, firewall routing, and the CI runner;
- enable higher availability, backups, and replication according to workload
  recovery objectives;
- use approved production SKUs and Azure Policy checks in CI.
