# Terraform execution guide

This guide explains how to configure, plan, deploy, validate, and destroy the
modular Azure lab in this repository. The safe default is the automated
apply/smoke-test/destroy workflow.

## 1. Choose an execution mode

| Goal | Command or workflow | Creates resources |
|---|---|---|
| Validate configuration only | `invoke-ephemeral-lab.ps1 -Action Plan` | No |
| Test the complete platform | `invoke-ephemeral-lab.ps1 -Action ApplyDestroy` | Yes, then destroys them |
| Keep a test lab briefly | Add `-HoldMinutes 1..60` | Yes, then destroys them |
| Keep an environment running | Manual `terraform apply` | Yes, until manually destroyed |

The automated workflow is recommended for ephemeral test subscriptions. It:

1. formats and validates the Terraform configuration;
2. creates and saves a plan;
3. applies the exact saved plan;
4. runs private DNS and HTTPS tests from the private VM;
5. executes a destroy plan in a PowerShell `finally` block.

Terminating the PowerShell process or workstation can prevent `finally` from
running. Always use the cleanup verification in section 9.

## 2. Prerequisites

Install:

- Terraform 1.10 or newer;
- Azure CLI;
- PowerShell 7 or Windows PowerShell 5.1.

Verify the tools:

```powershell
terraform version
az version
$PSVersionTable.PSVersion
```

The successful lab test used:

- Terraform 1.14.3;
- AzureRM provider 4.81.0;
- Sweden Central.

## 3. Authenticate to Azure

Terraform uses the Azure CLI credential by default. This is separate from the
Azure account used by VS Code extensions.

Sign in to the tenant:

```powershell
az login --tenant "<tenant-id>"
```

Select the subscription:

```powershell
az account set --subscription "<subscription-id>"
```

Verify the selected context:

```powershell
az account show --query "{name:name,id:id,tenantId:tenantId,user:user.name,state:state}" --output table
```

Verify that an access token can be acquired:

```powershell
az account get-access-token `
  --subscription "<subscription-id>" `
  --query "{subscription:subscription,tenant:tenant,expiresOn:expires_on}" `
  --output table
```

The deployment identity needs permission to create resource groups, networks,
Private Endpoints, DNS zones, compute, databases, App Service, Container Apps,
Container Registry, Key Vault, and storage. Owner was used for the initial lab test. In production,
use a custom least-privilege role or approved deployment identity.

## 4. Configure the lab

Create the local variables file:

```powershell
Copy-Item `
  .\environments\lab\lab.tfvars.example `
  .\environments\lab\lab.tfvars
```

Terraform does not load `lab.tfvars` automatically. Pass it to every plan with
`-var-file=lab.tfvars`. Each variables file fully describes one deployment, so
focused files such as `multi-vm-storage.tfvars` never inherit values from
another file. Do not create `terraform.tfvars` or `*.auto.tfvars` in
`environments\lab`; Terraform would load them silently into every plan and test.

Edit only `environments\lab\lab.tfvars` for environment-specific
choices. At minimum, replace the placeholder `subscription_id` and `tenant_id`
and review the service switches, region, network ranges, SKUs, sizes, and tags.
The example intentionally exposes the choices that most affect functionality,
cost, capacity, or data layout:

| Configuration | Important choices |
|---|---|
| Environment | Subscription, tenant, region, project name, environment, tags |
| Naming | Resource abbreviations and optional deterministic suffix |
| Network | VNet address space, each service subnet, and NAT idle timeout |
| Services | Enable or disable each deployable service |
| Virtual machine | Linux/Windows, Marketplace image, size, administrator username, OS disk, and named data disks |
| Virtual Machine Scale Set | Linux/Windows, Marketplace image, size, per-instance disks, zones, upgrade mode, and fixed or CPU-autoscaled capacity |
| Key Vault | SKU and purge protection |
| Storage | Terraform authentication, Shared Key policy, workload RBAC, redundancy, containers, shares, quotas, and access tiers |
| Databases | Versions, SKUs, storage, PostgreSQL/MySQL HA and zones, throughput, and API-specific schema |
| Container Apps | Environments keyed by name, each with its own subnet CIDR, dedicated workload profile map, and apps (image, port, profile placement) |
| Web App | Linux code, Windows code, or Linux container mode; plan SKU, runtime, image, port, and app settings |
| Function App | Linux/Windows OS, Elastic Premium plan SKU, language runtime and version |

Every object has defaults, so users can remove settings they do not need to
override. The `naming` object is the only naming surface; service objects do
not define resource names. Advanced module plumbing, credentials, Private
Endpoint target IDs, and DNS configuration stay out of the user file. The
complete input contract and validation rules remain in
`environments\lab\variables.tf`; do not edit that file for per-environment
values.

Important rules:

- `project_name` must be 2-12 lowercase alphanumeric or hyphen characters and
  cannot end in a hyphen or contain consecutive hyphens.
- `environment` must be 2-8 lowercase alphanumeric or hyphen characters and
  cannot end in a hyphen or contain consecutive hyphens.
- `address_space` accepts one or more IPv4 VNet CIDRs.
- `subnet_cidrs` is the complete current and future address plan for the
  shared subnets. Terraform validates every prefix, including disabled
  services, together with every Container Apps environment `subnet_cidr`, and
  rejects prefixes outside the VNet or overlapping prefixes.
- Each Container Apps environment `subnet_cidr` must be `/27` or larger. The
  planned SQL Managed Instance allocation must be `/27` or larger.
- Terraform creates only the subnets required by enabled services and nonempty
  resource collections. Adding a service or collection entry later creates its
  subnet and delegation before creating the resource.
- Terraform creates only the Private DNS zones and VNet links required by
  enabled services. Shared storage zones remain while any consumer is enabled.
- `container_registries` is a map keyed by stable logical names and defaults to
  empty. Each entry creates a Premium Azure Container Registry with public
  network access disabled and its own mandatory Private Endpoint; there is no
  `services` switch for Container Registry.
- `storage_use_azuread = true` makes Terraform use Entra ID for supported Blob
  and Queue operations. Pre-grant the deployment identity the required Storage
  data roles; role assignments declared inside `storage_accounts` entries are
  for workloads and are created too late to bootstrap Terraform itself.
- Keep an Entra-only `storage_accounts` entry's `file_shares` map empty when
  `shared_access_key_enabled = false`. AzureRM 4.x still manages Azure Files
  with Shared Key; Premium FileStorage and Function content storage have the
  same limitation until their provisioning is migrated to the ARM control
  plane.
- `storage_accounts` and `premium_file_accounts` are maps keyed by stable
  logical names. Both default to empty maps, so no accounts are created until
  entries are added; each entry creates an independent account and its Private
  Endpoints. The storage families are not controlled by `services` switches.
- `key_vaults` is a map keyed by stable logical names and defaults to empty.
  Each entry creates an RBAC-enabled Key Vault with its own Private Endpoint;
  there is no `services` switch for Key Vault.
- App Service Web App creates one app selected by `web_app.mode`: `linux`,
  `windows`, or `container`. All modes disable public access, use a Private
  Endpoint, integrate with the dedicated Web App subnet, and enable a
  system-assigned managed identity.
- all caller-defined Azure resource names are generated by the central naming
  convention.
- disabling a service also removes its dedicated subnet and related Private
  Endpoints when they are no longer needed.
- PostgreSQL and MySQL passwords, Linux VM/VMSS SSH keys, and Windows VM/VMSS
  administrator passwords are generated by Terraform;
  do not add credentials to `lab.tfvars`.
- VM OS selection, Function runtime examples, HA prerequisites, and credential
  handling are described in [the configuration reference](../README.md#vm-os-function-runtime-and-database-availability).
  Changing the VM OS replaces the VM.
- Function Apps default to Linux/Python 3.11. Select `function_app.os_type`
  (`Linux` or `Windows`) and set `runtime.name` plus `runtime.version` together.
  For example, Windows with `{ name = "dotnet-isolated", version = "8.0" }`
  creates a Windows Function App and Windows Elastic Premium plan. Python is
  Linux-only, so setting Windows without overriding the Python default is
  rejected. Use plain runtime versions; the module handles OS-specific provider
  version formats. Functions host v4 and private connectivity remain unchanged.
  Changing OS recreates the app/plan and its managed identity: review the plan,
  dependent access grants, and code redeployment. Windows Functions are covered
  by mocked Terraform plans only, not live deployment validation.
- The automated workflow selects Bash Run Command for Linux or PowerShell
  Run Command for Windows. Both check private DNS, NAT egress, and Container
  App HTTPS. It expects the full set of service hostnames, so enable those
  services explicitly in `lab.tfvars`; nothing is enabled by default.
- keep `purge_protection_enabled = false` on every `key_vaults` entry for the automated
  apply/destroy workflow. Enable it only for a persistent environment with an
  appropriate retention and recovery process.
- `azure_sql_servers` is a map keyed by stable logical names and defaults to
  empty; there is no `services` switch for Azure SQL. Each entry creates one
  Entra-only logical server with one database and its own Private Endpoint. The
  database is standalone while that entry's `elastic_pool.enabled = false`; set
  it to `true` to create a pool on that server and attach the database, and
  `database_sku_name` is then ignored.
- `container_apps_environments` is a map keyed by stable logical names and
  defaults to empty; there is no `services` switch for Container Apps. Each
  entry creates one internal environment on its own delegated subnet
  (`subnet_cidr`), its own private DNS zone, and the apps in its `apps` map.
  Every environment keeps Consumption; add dedicated profiles under that
  entry's `dedicated_workload_profiles` and set each app's `workload_profile`
  to `"Consumption"` (the default) or a profile key from the same environment.
  All environments share one Log Analytics workspace.
- `cosmos_db_accounts` is a map keyed by stable logical names and defaults to
  empty. Each entry creates one account with its own classic RU-based API
  (`api_type`) and one API-specific database/container pair, or one table for
  the Table API; there is no `services` switch for Cosmos DB.
- SQL Managed Instance is optional and disabled by default. Enabling it deploys
  the small lab profile in its dedicated subnet. Confirm quota and expected
  charges before setting `services.sql_managed_instance = true`.

Subnet creation follows the enabled service graph:

| Subnet | Created when |
|---|---|
| `private_endpoints` | Web App or Function App is enabled, or `azure_sql_servers`/`container_registries`/`cosmos_db_accounts`/`key_vaults`/`storage_accounts`/`premium_file_accounts` is nonempty |
| `virtual_machines` | `virtual_machines` or `virtual_machine_scale_sets` is non-empty |
| `container_apps/<key>` | One per `container_apps_environments` entry, using that entry's `subnet_cidr` |
| `web_app_integration` | `services.web_app` is `true` |
| `function_integration` | `services.function_app` is `true` |
| `postgresql` | `services.postgresql` is `true` |
| `mysql` | `services.mysql` is `true` |
| `sql_managed_instance` | `services.sql_managed_instance` is `true` |

Keep future CIDRs in `subnet_cidrs` even when their services are disabled. This
preserves a stable repository-level address plan and allows overlap validation
before a later rollout. Azure does not reserve an undeployed prefix, so
resources created outside this Terraform state must respect the same plan.
Disabling an existing service plans deletion of its now-unused subnet; deletion
fails safely if unmanaged resources still occupy it.

### Configure a Virtual Machine Scale Set

Scale sets are opt-in and independent of standalone VMs. Add one entry per
scale set:

```hcl
virtual_machine_scale_sets = {
  web = {}
  jobs = { os_type = "Windows", scaling = { mode = "fixed", default_instances = 1 } }
}

virtual_machines = {}
```

The commented `app` template in `lab.tfvars.example` demonstrates a Marketplace
image, a sized OS disk, two data-disk templates, and CPU autoscaling. Every
data-disk template is reproduced on every instance; choose the VM SKU and
maximum capacity with total disk count and cost in mind.

Azure Monitor owns runtime capacity in both modes:

- `mode = "fixed"` sets minimum/default/maximum to `default_instances`;
- `mode = "autoscale"` uses the configured bounds and CPU scale-out/scale-in
  rules.

Terraform owns the profile and ignores the VMSS `instances` drift created by
Azure Monitor. Do not manage capacity manually in another Terraform resource or
automation system. Manual portal/CLI changes may be corrected by the next
Azure Monitor evaluation.

Before applying:

1. Confirm the VM SKU and optional zones are available in the target region.
2. Confirm vCPU quota supports `maximum_instances`.
3. Confirm the image is Generation 2 and supports Secure Boot/vTPM.
4. Confirm the SKU supports the selected disk types and number of data disks.
5. Estimate cost using the autoscale maximum, because Azure can reach and hold
   that capacity.

Use `Manual` upgrade mode unless the workload has a separate health-aware
upgrade process. `Automatic` is available, but can update instances without an
application-specific health gate. Rolling upgrades and automatic repairs are
deferred until a load-balancer probe or Application Health extension is
available.

### Configure outbound internet egress

Virtual machines, VMSS instances, and Container Apps require outbound
connectivity for operating system updates, image pulls, package retrieval,
Azure platform dependencies, and application calls to public APIs. An internal Container Apps environment
restricts inbound access; it does not remove the need for outbound traffic.

When `virtual_machines` is non-empty, or
`virtual_machine_scale_sets` or `container_apps_environments` is non-empty,
Terraform creates one shared Standard NAT Gateway and one Standard static
public IPv4 address. It associates that gateway with the `virtual_machines`
subnet when active and with every Container Apps environment subnet. All of
them share the same predictable public egress address. Neither the
VM NIC nor an internal Container Apps environment receives a directly
reachable public ingress address.

Configure the TCP idle timeout in `lab.tfvars`:

```hcl
nat_gateway = {
  idle_timeout_in_minutes = 4
}
```

Valid values are whole minutes from 4 through 120. NAT Gateway and Standard
public IP resources incur charges while provisioned. If workloads require
separate egress identities or policies, use separate gateways instead of this
shared lab pattern. Terraform ignores Public IP `ip_tags` because Azure or
organizational policy may manage them outside this configuration; this avoids
replacing the stable outbound IP solely because of externally managed IP tags.

### Configure resource naming

The standard convention is:

```text
<resource-prefix>-<project_name>-<environment>-<unique_suffix>
```

All resource abbreviations are configured once:

```hcl
naming = {
  # null generates a stable five-character suffix in Terraform state.
  unique_suffix = null

  prefixes = {
    resource_group        = "rg"
    virtual_network       = "vnet"
    subnet                = "snet"
    virtual_machine       = "vm"
    sql_managed_instance  = "sqlmi"
    network_security_group = "nsg"
    route_table           = "rt"
    private_endpoint      = "pe"
  }
}
```

Attributes omitted from `prefixes` use the defaults shown in
`lab.tfvars.example`. To produce repeatable names across independent
state files, set a 3-5 character lowercase alphanumeric suffix:

```hcl
naming = {
  unique_suffix = "001"
}
```

For example, with `project_name = "metlen"`, `environment = "lab"`, and
`unique_suffix = "001"`:

- SQL Managed Instance: `sqlmi-metlen-lab-001`
- SQL MI NSG: `nsg-sql-managed-instance-metlen-lab-001`
- SQL MI route table: `rt-sql-managed-instance-metlen-lab-001`
- SQL MI subnet: `snet-sqlmi-metlen-lab-001`

The same convention supplies names to module-internal Azure resources,
including NICs, OS/data disks, Log Analytics, DNS links, Private Link
connections, databases, containers, and shares. Storage accounts use compact
lowercase names without hyphens; Key Vault names are compacted to 24
characters while preserving the suffix and a logical-key token; Cosmos DB account names keep a
logical-key token within 44 characters; Cosmos database/container names are
compact alphanumeric values for compatibility with all five supported APIs.
With the default prefix, map-based Container Apps workload profiles use
`<prefix>-<logical key>01`, such as `wp-general01`. A deterministic hash form
is used only when a custom prefix or key would exceed Azure's 15-character
limit. Container App names use `<prefix>-<app key>-<environment key>-<suffix>`,
such as `ca-hello-primary-001`, to fit Azure's 32-character limit.

Only Azure-owned or protocol-defined names are exempt: service Private DNS zone
FQDNs, the `@` and `*` DNS records, and the required Container Apps
`Consumption` profile. The backend example also references pre-existing state
infrastructure and is not created by this composition.

Changing any naming token changes Azure resource names and usually forces
replacement. Always review the plan. After apply, inspect the complete map:

```powershell
terraform -chdir=environments\lab output generated_resource_names
```

### Configure multiple VM disks

Data disks are keyed by a stable logical name, and every disk needs a unique
LUN. For a 256 GiB OS disk and three 512 GiB Premium SSD data disks, set the
following in `lab.tfvars`:

```hcl
virtual_machines = {
  primary = {
    size           = "Standard_D4s_v5"
    admin_username = "azureadmin"

    os_disk = {
      storage_account_type = "StandardSSD_LRS"
      disk_size_gb         = 256
      caching              = "ReadWrite"
    }

    data_disks = {
      application = {
        lun                  = 0
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 512
        caching              = "ReadWrite"
      }
      data = {
        lun                  = 1
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 512
        caching              = "ReadWrite"
      }
      logs = {
        lun                  = 2
        storage_account_type = "Premium_LRS"
        disk_size_gb         = 512
        caching              = "ReadWrite"
      }
    }
  }
}
```

Choose a VM size that supports Premium SSDs and at least three data disks.
Terraform creates and attaches the disks, but the guest operating system must
still partition, format, and mount new data disks. Azure managed disks can only
be expanded; reducing a configured disk size requires replacement and data
migration.

The example elastic pool values are supported in Sweden Central and represent
the smallest Basic pool capability available there: `BasicPool`, Basic tier,
50 eDTUs, 5,000 MB maximum pool size (`max_size_gb = 4.8828125` in AzureRM),
and 0-5 eDTUs per database. Check the target region's Azure SQL capabilities
before changing the SKU, capacity, or storage values. `license_type` and
`sku.family` can also be set for pool tiers that support them.

Private connectivity does not require any pool-specific resources. Each
server's Private Endpoint and the shared `privatelink.database.windows.net` DNS
zone are associated with the logical server and work for both standalone and
pooled databases.

Configure Container Apps environments, their apps, and optional dedicated
workload profiles in the environment variables file. Each environment needs its
own `/27` or larger subnet that doesn't overlap any other lab subnet:

```hcl
container_apps_environments = {
  primary = {
    subnet_cidr = "10.42.2.0/27"
    apps        = { hello = {} }
  }
  jobs = {
    subnet_cidr = "10.42.3.0/24"
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
    apps = {
      worker = { workload_profile = "general" }
      cache  = { workload_profile = "memory" }
    }
  }
}
```

These counts are dedicated **nodes**, not Container App replicas. A zero
minimum permits node scale-to-zero; a positive minimum keeps nodes allocated.
Dedicated management and other resource charges can still apply with zero
nodes. Verify profile availability and quota in the target region before
deployment:

```powershell
az containerapp env workload-profile list-supported `
  --location swedencentral `
  --output table
```

After editing the variables file, validate and review a plan:

```powershell
terraform -chdir=environments\lab validate
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -out="container-apps-dedicated.tfplan"
```

An app's `workload_profile` defaults to `"Consumption"`. Any other value must
match a logical profile key in the same environment, not the generated Azure
profile name. Profiles do not create apps; each app keeps a replica range of
0-1.

Inspect `terraform output container_apps_environments` for each environment's
label-to-Azure profile name map and each app's FQDN and selected profile.
Profile keys must start with a lowercase letter, contain only lowercase
letters, digits, and hyphens, and be at most 20 characters; `consumption` is
reserved. Environment keys are at most 12 characters and app keys at most 8.

Renaming an environment, app, or profile key replaces that resource: review
removal/addition and app placement before applying. Subnet size can't change
after an environment is created.

Multi-profile behavior is covered by mocked Terraform plans, not a live Azure
deployment. Review expected charges before applying. See
[Microsoft's workload profile guidance](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview).

### Cosmos DB API and throughput modes

Each `cosmos_db_accounts` entry is one Cosmos DB account with one API. Accounts
in the same lab can use different APIs; the lab creates each API's Private DNS
zone once and gives every account its own Private Endpoint:

| `api_type` | Data-plane resources | Private Endpoint group | Private DNS zone |
|---|---|---|---|
| `NoSQL` | SQL database and container | `Sql` | `privatelink.documents.azure.com` |
| `MongoDB` | Mongo database and collection | `MongoDB` | `privatelink.mongo.cosmos.azure.com` |
| `Cassandra` | Keyspace and table | `Cassandra` | `privatelink.cassandra.cosmos.azure.com` |
| `Gremlin` | Database and graph | `Gremlin` | `privatelink.gremlin.cosmos.azure.com` |
| `Table` | Table | `Table` | `privatelink.table.cosmos.azure.com` |

`MongoDB` in this module is the classic RU-based Azure Cosmos DB API for
MongoDB. Azure Cosmos DB for MongoDB vCore uses different Azure resources,
capacity units, networking, and Terraform configuration and is outside this
module's scope.

The throughput object supports:

| Mode | Configuration | Billing/capacity behavior |
|---|---|---|
| `serverless` | No RU/s value is provisioned | Pay for consumed RUs and storage; single-region account |
| `manual` | `manual_ru`, minimum 400 in increments of 100 | Fixed provisioned RU/s |
| `autoscale` | `autoscale_max_ru`, minimum 1,000 in increments of 1,000 | Scales from 10% of the configured maximum |

For NoSQL, MongoDB, Cassandra, and Gremlin, `scope = "database"` shares
throughput across child containers, while `scope = "container"` assigns it to
the container, collection, table, or graph. The Table API requires container
scope. Serverless mode ignores the RU values and does not emit any throughput
arguments.

Partitioning remains workload-specific:

- NoSQL accepts one to three `nosql_partition_key_paths`; multiple paths create
  a hierarchical partition key.
- MongoDB uses `mongodb.shard_key`.
- Cassandra uses the configurable columns, partition keys, and cluster keys in
  `cassandra_schema`.
- Gremlin uses `gremlin_partition_key_path`.

Choose keys with high cardinality and align them with frequent query filters to
avoid hot partitions and cross-partition queries. Throughput mode and scope are
creation-time decisions in the AzureRM resources; switching between manual and
autoscale later can require an out-of-band migration or resource recreation.

Plan the default NoSQL serverless profile without editing `lab.tfvars`:

```powershell
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -var="cosmos_db_accounts={primary={}}" `
  -out=cosmos-nosql-serverless.tfplan
```

Plan MongoDB with 400 RU/s assigned to the collection:

```powershell
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -var='cosmos_db_accounts={primary={api_type="MongoDB",throughput={mode="manual",scope="container",manual_ru=400}}}' `
  -out=cosmos-mongodb-manual.tfplan
```

The account has a system-assigned identity and public network access disabled.
Key-based authentication remains enabled by default for compatibility across
all APIs; set `local_authentication_disabled = true` only after confirming that
the selected API and clients use Microsoft Entra authentication. Keys and
connection strings are not exposed as Terraform outputs.

All five API types, serverless mode, manual RU/s, autoscale, database scope,
and container scope have been Terraform plan-validated in Sweden Central.
Serverless NoSQL and Gremlin accounts have also been applied.

To plan the elastic-pool mode without editing `lab.tfvars` or creating
resources:

```powershell
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -var="azure_sql_servers={primary={elastic_pool={enabled=true}}}" `
  -out=sql-elastic-pool.tfplan
```

To plan SQL Managed Instance without modifying `lab.tfvars` or creating
resources:

```powershell
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -var="services={sql_managed_instance=true}" `
  -out=sql-mi.tfplan
```

The tested plan uses General Purpose Gen5, 4 vCores, 32 GiB storage,
`LicenseIncluded`, no zone redundancy, no public endpoint, and Entra-only
authentication. SQL Managed Instance is currently plan-validated only; it has
not been applied.

Local `.tfvars` files such as `lab.tfvars` are ignored by Git. Do not commit environment-specific
variables, credentials, state, or plan files.

## 5. Validate and plan without deploying

Use the tested wrapper:

```powershell
.\scripts\invoke-ephemeral-lab.ps1 -Action Plan
```

The wrapper runs:

```powershell
terraform fmt -check -recursive .
terraform -chdir=environments\lab init -input=false
terraform -chdir=environments\lab validate -no-color
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -out=ephemeral.tfplan `
  -no-color
```

The wrapper uses `environments\lab\lab.tfvars` by default. Select another
variables file with `-VarFile`, for example
`.\scripts\invoke-ephemeral-lab.ps1 -Action Plan -VarFile multi-vm-storage.tfvars`.
The same file is used for the destroy plan.

The planned resource count depends on the enabled services. Every service is
opt-in, and subnets such as the SQL MI subnet are created only for enabled
services. Private DNS zones and links are included only for enabled
services. Review the plan before applying:

```powershell
terraform -chdir=environments\lab show ephemeral.tfplan
```

## 6. Run the complete ephemeral test

Apply, test private connectivity, and destroy immediately:

```powershell
.\scripts\invoke-ephemeral-lab.ps1 -Action ApplyDestroy
```

Keep the successfully tested lab available for up to 60 minutes before
destroying it:

```powershell
.\scripts\invoke-ephemeral-lab.ps1 `
  -Action ApplyDestroy `
  -HoldMinutes 30
```

`HoldMinutes` starts after deployment and smoke testing. Provisioning and
deletion time are additional billable time.

The connectivity script runs through Azure VM Run Command, so the VM needs no
public IP. It verifies private DNS resolution for:

- Azure SQL (select the server with `-SmokeTestAzureSqlServerKey`, default
  `primary`);
- PostgreSQL;
- MySQL;
- Key Vault;
- standard blob storage;
- Premium Azure Files;
- Function host storage;
- Function App;
- Container App (select it with `-SmokeTestContainerAppsEnvironmentKey`,
  default `primary`, and `-SmokeTestContainerAppKey`, default `hello`).
- SQL Managed Instance, when enabled.
- Cosmos DB, when `cosmos_db_accounts` is nonempty (select the account with
  `-SmokeTestCosmosDbAccountKey`, default `primary`).

Each hostname must resolve to the VNet address range. The Container App HTTPS
endpoint must return HTTP 200.

## 7. Manual deployment

Use this workflow only when the environment should remain deployed.

Initialize and validate:

```powershell
terraform fmt -check -recursive .
terraform -chdir=environments\lab init -input=false
terraform -chdir=environments\lab validate
```

Create and review a saved plan:

```powershell
terraform -chdir=environments\lab plan `
  -input=false `
  -var-file=lab.tfvars `
  -out=lab.tfplan

terraform -chdir=environments\lab show lab.tfplan
```

Apply exactly that plan:

```powershell
terraform -chdir=environments\lab apply `
  -input=false `
  -auto-approve `
  lab.tfplan
```

Inspect outputs:

```powershell
terraform -chdir=environments\lab output
terraform -chdir=environments\lab output -json
```

List resources in the generated resource group:

```powershell
$resourceGroup = terraform -chdir=environments\lab output -raw resource_group_name
az resource list --resource-group $resourceGroup --output table
```

Check Private Endpoint approval:

```powershell
az network private-endpoint list `
  --resource-group $resourceGroup `
  --query "[].{name:name,state:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" `
  --output table
```

## 8. Manual destroy

Always create and apply a saved destroy plan:

```powershell
terraform -chdir=environments\lab plan `
  -destroy `
  -input=false `
  -var-file=lab.tfvars `
  -out=destroy.tfplan

terraform -chdir=environments\lab apply `
  -input=false `
  -auto-approve `
  destroy.tfplan
```

Do not delete the local state before destroying resources. Terraform needs the
state to identify all resource instances and dependencies.

## 9. Verify cleanup

Terraform state must be empty:

```powershell
terraform -chdir=environments\lab state list
```

The command should print no resource addresses.

If the resource group name is still available from logs or earlier output:

```powershell
az group exists `
  --name "<resource-group-name>" `
  --subscription "<subscription-id>"
```

The expected result is `false`.

Also query any matching resources:

```powershell
az resource list `
  --subscription "<subscription-id>" `
  --resource-group "<resource-group-name>" `
  --output table
```

## 10. Configure remote state for production

The ephemeral lab uses local state so the entire test can be removed. A
persistent environment should use an Azure Storage backend.

Create a dedicated state resource group, storage account, and private blob
container outside the workload configuration. Protect that storage account
with:

- blob versioning and soft delete;
- data-plane RBAC;
- resource locks where appropriate;
- Private Endpoint access from the CI runner network;
- diagnostic logging;
- a lifecycle independent from application environments.

Enable the backend examples:

```powershell
Copy-Item `
  .\environments\lab\backend.tf.example `
  .\environments\lab\backend.tf

Copy-Item `
  .\environments\lab\backend.hcl.example `
  .\environments\lab\backend.hcl
```

Edit `backend.hcl`, then initialize or migrate:

```powershell
terraform -chdir=environments\lab init `
  -backend-config=backend.hcl `
  -migrate-state
```

The example uses Microsoft Entra authentication. Grant the deployment identity
`Storage Blob Data Contributor` at the state container or approved scope.

## 11. State and secret handling

Terraform state contains sensitive values even when outputs are marked
`sensitive`. This lab generates:

- PostgreSQL and MySQL administrator passwords;
- an ephemeral VM private key;
- storage account access keys used by the Function App.

For production:

- use an encrypted remote backend with tightly scoped RBAC;
- use a pre-existing SSH public key instead of generating a private key;
- prefer managed identities and Entra database authentication;
- populate Key Vault from a runner with private network access;
- never send state or plan files to source control or ticket systems.

## 12. Troubleshooting

### Azure CLI and Terraform use different accounts

Run `az account show` and `az account get-access-token`. Reauthenticate with the
target tenant and subscription. A successful sign-in in VS Code does not prove
that the Azure CLI credential used by Terraform is valid.

### `RequestDisallowedByPolicy` for Azure SQL

Some subscription policies require Entra-only Azure SQL authentication. The
SQL module already configures an Entra administrator and
`azuread_authentication_only = true`. Do not add SQL administrator passwords
unless the target subscription policy explicitly permits them.

Inspect a policy denial:

```powershell
az monitor activity-log list `
  --resource-id "<failed-resource-id>" `
  --offset 2h `
  --query "[].{operation:operationName.localizedValue,policies:properties.policies,status:properties.statusMessage}" `
  --output json
```

### PostgreSQL reports `RegionalAllocationFailed`

The requested compute family has no capacity in the selected region. The lab
uses `GP_Standard_D2ds_v5` in Sweden Central because burstable B1ms capacity was
unavailable during testing. Select another approved SKU or region, confirm
quota, and re-plan.

### Container Apps subnet delegation error

Each Container Apps environment subnet must remain delegated to
`Microsoft.App/environments` and belong to that environment only. Do not reuse
it for another environment, other resources, or Private Endpoints.

### Function App content-share error

The Function App requires the pre-created `content` file share when
`WEBSITE_CONTENTOVERVNET=1`. Keep the file Private Endpoint, Private DNS zone,
VNet integration, and content share enabled together.

### Storage reports `KeyBasedAuthenticationNotPermitted`

The account rejects Shared Key authentication. Set `storage_use_azuread = true`
so AzureRM uses Entra ID for supported Blob and Queue operations, set the
affected `storage_accounts` entry's `shared_access_key_enabled = false`, and
pre-grant the Terraform identity the required Storage Blob/Queue data roles.
Owner or Contributor management-plane access does not guarantee data-plane
access.

For Entra-only general-purpose v2 storage, keep that account entry's
`file_shares = {}` because AzureRM 4.x still provisions
`azurerm_storage_share` with Shared Key. The Terraform runner must also have
private network and DNS connectivity because the module disables public
storage access.

### Partial apply

Do not remove the state. Fix the configuration and re-run `terraform plan`, or
destroy the partial deployment:

```powershell
terraform -chdir=environments\lab plan -destroy -var-file=lab.tfvars -out=destroy.tfplan
terraform -chdir=environments\lab apply -auto-approve destroy.tfplan
```

### State lock

Confirm that no other Terraform process or pipeline is running. For a remote
backend, inspect the blob lease. Use `terraform force-unlock` only after
confirming the lock is stale and recording the lock ID.

## 13. CI/CD execution sequence

A production pipeline should use these gates:

1. `terraform fmt -check -recursive`;
2. `terraform init -backend-config=...`;
3. `terraform validate`;
4. security and organization policy checks;
5. `terraform plan -out=<immutable plan>`;
6. human approval for production;
7. `terraform apply <immutable plan>`;
8. smoke and Private Endpoint checks;
9. publish plan/apply metadata without publishing secrets or state.

Use separate backend keys and variable files for each environment. Do not use
Terraform workspaces as the only isolation boundary for unrelated production
environments.
