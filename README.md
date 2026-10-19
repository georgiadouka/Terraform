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

## Implemented modules

| Module | Purpose | Private connectivity |
|---|---|---|
| `resource-group` | Resource group lifecycle | N/A |
| `network` | VNet and service-specific subnets | Dedicated and delegated subnets |
| `private-dns` | Central Private DNS zones and VNet links | Yes |
| `private-endpoint` | Reusable Private Endpoint and DNS zone group | Yes |
| `nat-gateway` | Shared static outbound internet egress for VM/VMSS and Container Apps subnets | Standard NAT Gateway and static public IP |
| `virtual-machine` | Linux or Windows VM, NIC, OS disk, and configurable data disks | No VM public IP; outbound through NAT Gateway |
| `virtual-machine-scale-set` | Linux or Windows VMSS with configurable images/disks and fixed or CPU-autoscaled capacity | No instance public IP; outbound through NAT Gateway |
| `key-vault` | RBAC-enabled Key Vault | Public network disabled; Private Endpoint |
| `container-registry` | Premium Azure Container Registry | Public network disabled; Private Endpoint |
| `storage-account` | Blob containers, optional standard SMB shares, and workload data-plane RBAC | Public network disabled; blob/file endpoints |
| `premium-files` | Premium Azure Files account and shares | Public network disabled; file endpoint |
| `azure-sql` | Azure SQL logical server, database, and optional elastic pool | Entra-only auth; public network disabled; Private Endpoint |
| `sql-managed-instance` | Optional 4-vCore General Purpose SQL Managed Instance | Dedicated delegated subnet; Entra-only auth; no public endpoint |
| `postgresql-flexible` | PostgreSQL Flexible Server and database with optional HA | Delegated subnet and Private DNS |
| `mysql-flexible` | MySQL Flexible Server and database with optional HA | Delegated subnet and Private DNS |
| `cosmos-db` | NoSQL, MongoDB, Cassandra, Gremlin, or Table account with serverless/manual/autoscale throughput | Public network disabled; API-specific Private Endpoint and DNS |
| `container-apps` | Internal Container Apps environment with Consumption and optional dedicated workload profiles | Internal load balancer and private wildcard DNS |
| `web-app` | Linux code, Windows code, or Linux container App Service Web App | Public network disabled; Private Endpoint and outbound VNet integration |
| `function-app` | Linux or Windows Elastic Premium Function App | Inbound Private Endpoint and outbound VNet integration |

SQL Managed Instance is disabled by default because it is comparatively
expensive and long-running. The optional lab profile uses General Purpose Gen5,
4 vCores, 32 GiB storage, no zone redundancy, and a dedicated delegated subnet.
Set `services.sql_managed_instance = true` only for an approved test.

The SQL Managed Instance module has been schema-validated and included in a
successful Terraform plan, but it has not been applied. The rest of the lab was
previously applied, smoke-tested, and destroyed.

Azure SQL uses a standalone Basic database by default. An environment owner can
enable an elastic pool through the centralized `azure_sql.elastic_pool` object
in the environment `.tfvars` file without editing the reusable module. The
example uses the smallest Sweden Central Basic pool capability: 50 eDTUs,
5,000 MB pool storage (`max_size_gb = 4.8828125` in AzureRM), and 0-5 eDTUs per
database. The SQL Private Endpoint and Private DNS configuration do not change
because connectivity is configured on the logical server.

Container Apps retains Consumption by default. Environment owners can add one
or more dedicated profiles through `container_apps.dedicated_workload_profiles`
and select app placement with `container_apps.app_workload_profile`. The map is
empty by default to avoid dedicated-profile charges. The multi-profile path has
mocked Terraform plan coverage; it has not been deployed to Azure.

Cosmos DB is also disabled by default. One module instance creates one classic
RU-based API account selected with `cosmos_db.api_type`: NoSQL, MongoDB,
Cassandra, Gremlin, or Table. Throughput can be serverless, manual RU/s, or
autoscale, with database/keyspace or container/collection/table/graph scope
where the API supports it. Public access is disabled, and the lab selects the
matching Private Endpoint group and Private DNS zone automatically. All five
APIs and the three throughput modes have been Terraform plan-validated, but
Cosmos DB has not been applied. `MongoDB` refers to the classic RU-based Cosmos
DB API for MongoDB, not the separate Azure Cosmos DB for MongoDB vCore product.

Virtual Machine Scale Sets are disabled by default. The module supports Linux
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
- separate subnets for the enabled Private Endpoint consumers, VMs, Container
  Apps, Web App VNet integration, Function VNet integration, PostgreSQL, and
  MySQL; SQL Managed Instance adds its dedicated subnet only when enabled;
- twelve approved Private Endpoints;
- centralized Private DNS zones for enabled services linked to the VNet;
- one private VM with a managed data disk;
- one private Premium Azure Container Registry;
- one shared NAT Gateway and static public IP for VM/VMSS and Container Apps
  outbound internet traffic;
- standalone or elastic-pooled Azure SQL Database, PostgreSQL, and MySQL;
- an internal Container App on Consumption or an optional dedicated profile;
- a private Linux code, Windows code, or Linux container Web App;
- a private Function App with private host storage;
- Key Vault, standard blob/file storage, and Premium Azure Files.

Environment owners can override the VNet address spaces and every subnet CIDR
through `address_space` and `subnet_cidrs` in their `.tfvars` file. Terraform
validates the complete current and future address plan for VNet containment and
overlap, but creates only the subnets required by enabled services. The shared
Private Endpoint subnet is created while at least one of Key Vault, storage,
Premium Files, Azure Container Registry, Azure SQL, Cosmos DB, Web App, or Function App is enabled. Enabling a
service later adds its required subnet without changing existing subnet
addresses. Private DNS zones and VNet links are likewise created only for
enabled services; zones shared by multiple services remain while any consumer
is enabled.

All Private Endpoints are declared in one catalog,
`local.private_endpoint_catalog` in `environments/lab/main.tf`. Each entry
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
`storage_accounts`, `premium_file_accounts`, or `key_vaults` for keyed
resources. Subnets,
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

### Virtual Machine Scale Sets

Set `services.virtual_machine_scale_set = true` to add a private Linux or
Windows Uniform VMSS. `source_image_reference.sku` selects the OS release and
`source_image_reference.version` selects the Marketplace image build. A null
image uses Ubuntu 22.04 Gen2 or Windows Server 2022 Azure Edition.

Data disks are a map keyed by stable logical labels. The labels stabilize
Terraform configuration; Azure creates the physical disks for each instance.
For example, a two-instance scale set with two data-disk templates creates four
data disks in total.

```hcl
virtual_machine_scale_set = {
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

### Container Apps workload profiles

Set the following in the environment variables file to create two dedicated
profiles and place the single sample Container App on the general-purpose one:

```hcl
container_apps = {
  dedicated_workload_profiles = {
    general = {
      workload_profile_type = "D4"
      minimum_count         = 0
      maximum_count         = 3
    }
    memory = {
      workload_profile_type = "E4"
      minimum_count         = 0
      maximum_count         = 2
    }
  }
  app_workload_profile = "general"
}
```

- An empty map means Consumption-only. Consumption remains available even
  when dedicated profiles are configured.
- Set `app_workload_profile` to `"Consumption"` or a configured map key.
  Omission/null defaults to Consumption with the new interface. The composition
  still creates **one app**, placed on one profile; profiles do not create apps.
- Keys are stable logical labels: 1-20 lowercase letters, digits, or hyphens,
  starting with a letter; `consumption` is reserved. Azure profile names are
  generated centrally. Retrieve the label-to-name map with
  `terraform output container_app_dedicated_workload_profile_names`; the selected
  Azure name is `container_app_workload_profile_name`.
- Minimum/maximum counts are **compute nodes**, not app replicas. Node counts
  must be whole numbers with `0 <= minimum_count <= maximum_count` and a maximum
  of at least one. App replica limits remain unchanged (0-1).
- Check regional profile availability, quota, and dedicated billing before
  applying. A positive minimum keeps nodes allocated; zero minimum does not
  guarantee zero dedicated charges. See the
  [Microsoft workload profile documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview).

Changing a map key renames that profile; changing counts or adding another key
does not rename existing entries.

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
runtime-version allowlists are temporarily disabled, so verify the selected
version against current Azure App Service support before deployment.
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
| `python` | `3.7`, `3.8`, `3.9`, `3.10`, `3.11`, `3.12`, `3.13`, `3.14` | Not supported | Python Function Apps require Linux. Python 3.11 is this composition's default. |
| `node` | `12`, `14`, `16`, `18`, `20`, `22`, `24` | `12`, `14`, `16`, `18`, `20`, `22`, `24` | Supply the plain major version, such as `22`. |
| `dotnet-isolated` | `6.0`, `7.0`, `8.0`, `9.0` | `6.0`, `7.0`, `8.0`, `9.0`, `10.0` | Preferred .NET execution model. |
| `dotnet` | `8.0` only | `8.0` only | Legacy in-process model. The module also sets `FUNCTIONS_INPROC_NET8_ENABLED=1`. In-process support ends November 10, 2026. |
| `java` | `8`, `11`, `17`, `21`, `25` | `8`, `11`, `17`, `21`, `25` | Supply `8`; the module maps it to the Windows provider value `1.8`. |
| `powershell` | `7`, `7.2`, `7.4` | `7`, `7.2`, `7.4`, `7.6` | Select a version supported by Azure in the target region. |

These reference values include legacy versions and **do not guarantee that a
version is still supported by Azure**. Before deployment, select a currently
supported version from Microsoft's
[Azure Functions language support table](https://learn.microsoft.com/azure/azure-functions/supported-languages)
and verify regional availability.

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

- Both `postgresql.high_availability` and `mysql.high_availability` accept
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
terraform -chdir=modules\postgresql-flexible test
terraform -chdir=modules\mysql-flexible test
terraform -chdir=modules\container-apps test
.\scripts\tests\private-connectivity-smoke.Tests.ps1
```

The tests use mocked Azure providers and plan-only runs; they do not deploy
resources or exercise real database failover. The environment tests override
network/storage plumbing to focus on configuration, credential selection, Web
App mode selection, and Container Apps profile naming/placement. Workload
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
Azure Container Registry names contain no hyphens, and Key Vault names keep
the suffix and a logical-key token within 24 characters; Cosmos DB
database/container names are compact alphanumeric identifiers compatible with
all supported APIs. Map-based Container Apps workload profile names use
`<prefix up to 3 characters>-<4-character SHA-1 of logical key>-<suffix>`, staying
within Azure's 15-character limit. The key hash makes names independent of map
ordering; conflicting shortened hashes are rejected. Azure-owned or
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
- connect the VNet to the customer hub, DNS forwarding, firewall, and CI runner;
- enable higher availability, backups, and replication according to workload
  recovery objectives;
- use approved production SKUs and Azure Policy checks in CI.
