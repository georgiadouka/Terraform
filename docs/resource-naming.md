# Resource Naming

Resource names are generated centrally by the lab environment and then passed
to the individual modules. The modules generally do not invent their own Azure
resource names.

## 1. Base naming inputs

The base values are configured in
[`environments/lab/terraform.tfvars`](../environments/lab/terraform.tfvars):

```hcl
project_name = "metlen"
environment  = "lab"

naming = {
  unique_suffix = null
}
```

When `unique_suffix` is `null`, Terraform generates a five-character suffix:

```hcl
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}
```

For example, a deployment might generate:

```text
it6hp
```

An ephemeral deployment destroys this suffix with the rest of its state. A new
deployment therefore normally receives a different suffix.

## 2. Common name stem

The central naming logic is in
[`environments/lab/main.tf`](../environments/lab/main.tf):

```hcl
naming_suffix = coalesce(
  var.naming.unique_suffix,
  random_string.suffix.result
)

name_stem = "${var.project_name}-${var.environment}-${local.naming_suffix}"
```

Using the example suffix:

```text
project     = metlen
environment = lab
suffix      = it6hp

name_stem   = metlen-lab-it6hp
```

Most names are then formed as:

```text
<prefix>-<name_stem>
```

## 3. Prefixes

Prefixes are configured in
[`environments/lab/terraform.tfvars`](../environments/lab/terraform.tfvars):

| Resource | Prefix |
|---|---:|
| Resource group | `rg` |
| Virtual network | `vnet` |
| Subnet | `snet` |
| Virtual machine | `vm` |
| VM scale set | `vmss` |
| Network interface | `nic` |
| Storage account | `st` |
| Premium Files account | `stpf` |
| Function storage | `stfn` |
| Key Vault | `kv` |
| Container registry | `cr` |
| Container Apps Environment | `cae` |
| Container App | `ca` |
| Container | `ctr` |
| Workload profile | `wp` |
| Log Analytics workspace | `log` |
| Private endpoint | `pe` |

## 4. Standard resource names

The most common formula is:

```text
<prefix>-<project>-<environment>-<suffix>
```

Examples using the example suffix:

| Resource | Formula | Result |
|---|---|---|
| Resource group | `rg` + stem | `rg-metlen-lab-it6hp` |
| Virtual network | `vnet` + stem | `vnet-metlen-lab-it6hp` |
| Virtual machine | `vm` + logical key + stem | `vm-primary-metlen-lab-it6hp` |
| VM scale set | `vmss` + stem | `vmss-metlen-lab-it6hp` |
| NAT Gateway | `nat` + stem | `nat-metlen-lab-it6hp` |
| Container Apps Environment | `cae` + stem | `cae-metlen-lab-it6hp` |
| Container App | `ca` + stem | `ca-metlen-lab-it6hp` |
| Log Analytics workspace | `log` + stem | `log-metlen-lab-it6hp` |
| Function App | `func` + stem | `func-metlen-lab-it6hp` |
| Web App | `app` + stem | `app-metlen-lab-it6hp` |

Standalone VM, NIC, OS disk, and data disk names include the stable key from
the `virtual_machines` map so that multiple independently configured VMs have
distinct Azure names.

For example, the Container Apps Environment name is calculated as:

```hcl
container_apps_environment = (
  "${local.naming_prefixes.container_apps_environment}-${local.name_stem}"
)
```

This becomes:

```text
cae-metlen-lab-it6hp
```

The environment passes that name to the module:

```hcl
module "container_apps" {
  environment_name = local.resource_names.container_apps_environment
}
```

The module then uses it directly:

```hcl
resource "azurerm_container_app_environment" "this" {
  name = var.environment_name
}
```

## 5. Names with a role or logical label

Some resources include an additional role:

```text
<prefix>-<role>-<project>-<environment>-<suffix>
```

Examples:

| Resource | Result |
|---|---|
| Private Endpoints subnet | `snet-pe-metlen-lab-it6hp` |
| VM subnet | `snet-vm-metlen-lab-it6hp` |
| Container Apps subnet | `snet-aca-metlen-lab-it6hp` |
| Web App integration subnet | `snet-app-metlen-lab-it6hp` |
| Function integration subnet | `snet-func-metlen-lab-it6hp` |
| PostgreSQL subnet | `snet-psql-metlen-lab-it6hp` |
| MySQL subnet | `snet-mysql-metlen-lab-it6hp` |
| SQL Managed Instance subnet | `snet-sqlmi-metlen-lab-it6hp` |
| NAT public IP | `pip-nat-metlen-lab-it6hp` |
| VMSS network interface | `nic-vmss-metlen-lab-it6hp` |
| Data disk labelled `data` | `disk-data-metlen-lab-it6hp` |
| Data disk labelled `logs` | `disk-logs-metlen-lab-it6hp` |

Logical labels such as `data`, `logs`, `general`, and `memory` come from map
keys in the configuration. Subnet roles use concise, fixed abbreviations while
retaining the project, environment, and deployment suffix:

| Subnet key | Role abbreviation |
|---|---|
| `private_endpoints` | `pe` |
| `virtual_machines` | `vm` |
| `container_apps` | `aca` |
| `web_app_integration` | `app` |
| `function_integration` | `func` |
| `postgresql` | `psql` |
| `mysql` | `mysql` |
| `sql_managed_instance` | `sqlmi` |

## 6. Globally constrained names

Some Azure services do not permit hyphens or have short maximum lengths. For
those, the project and environment are compacted:

```hcl
compact_project     = replace(var.project_name, "-", "")
compact_environment = replace(var.environment, "-", "")
```

For this lab:

```text
compact_project     = metlen
compact_environment = lab
```

### Storage accounts

The formula is:

```text
<prefix><project><environment><suffix>
```

Examples:

| Resource | Result |
|---|---|
| Standard Storage | `stmetlenlabit6hp` |
| Premium Files | `stpfmetlenlabit6hp` |
| Function Storage | `stfnmetlenlabit6hp` |

The expression is truncated if necessary to remain within Azure's
24-character storage-account limit.

### Container Registry

The formula is:

```text
cr + metlen + lab + it6hp
```

Result:

```text
crmetlenlabit6hp
```

### Key Vault

Key Vault permits hyphens but has a 24-character limit, so the expression uses
compact project and environment tokens and truncates as necessary:

```text
kv-metlenlab-it6hp
```

## 7. Child-resource names

Storage containers and file shares use their logical labels:

```text
<prefix>-<logical-label>-<name-stem>
```

Examples:

| Child resource | Result |
|---|---|
| Blob container `appdata` | `blob-appdata-metlen-lab-it6hp` |
| Blob container `archive` | `blob-archive-metlen-lab-it6hp` |
| Premium share `premium` | `share-premium-metlen-lab-it6hp` |
| Function content share | `share-function-content-metlen-lab-it6hp` |

## 8. Private endpoint names

Three related resources are generated for each private connection:

| Component | Prefix |
|---|---|
| Private endpoint | `pe` |
| Private service connection | `psc` |
| Private DNS zone group | `pdnszg` |

For Standard Storage Blob:

```text
pe-st-blob-metlen-lab-it6hp
psc-st-blob-metlen-lab-it6hp
pdnszg-st-blob-metlen-lab-it6hp
```

For Function Storage File:

```text
pe-stfn-file-metlen-lab-it6hp
psc-stfn-file-metlen-lab-it6hp
pdnszg-stfn-file-metlen-lab-it6hp
```

This keeps related resources visibly associated.

## 9. Container Apps workload-profile names

Workload-profile names are fully known during planning. With the default
prefix, a short logical key uses:

```text
<prefix>-<logical key>01
```

The configured logical keys are:

```hcl
dedicated_workload_profiles = {
  general = { ... }
  memory  = { ... }
}
```

Current results:

| Logical key | Generated name |
|---|---|
| `general` | `wp-general01` |
| `memory` | `wp-memory01` |

The deprecated single-profile input uses `wp-legacy01`.

If a custom prefix or logical key would make the direct name longer than
Azure's 15-character limit, the name falls back to:

```text
<first three prefix characters>-<first eight SHA-1 characters of logical key>01
```

For example, the `longprefix` prefix and `general` key produce a deterministic
short name such as `lon-dfe2169801`.

Both forms use only input values that Terraform knows during planning. The
random deployment suffix is intentionally excluded because AzureRM models
workload profiles as a set and must correlate the same complete names between
plan and apply. The Container Apps Environment and globally named resources
continue to use the random suffix.

## 10. Random versus deterministic behavior

Within one Terraform state, the random suffix remains stable:

```text
First apply:       it6hp
Subsequent plan:   it6hp
Subsequent apply:  it6hp
```

It changes when:

- The random resource is destroyed.
- Terraform state is removed.
- The random resource is replaced.
- A different explicit `unique_suffix` is supplied.

Because the lab is ephemeral and destroys everything after testing, every
complete test run normally gets a new suffix.

All names can be made repeatable by configuring:

```hcl
naming = {
  unique_suffix = "test1"
}
```

The resource group would then always be:

```text
rg-metlen-lab-test1
```

Fixed suffixes increase the chance of collisions for globally unique services
such as Storage Accounts and Container Registries. That is why general
resources use a random suffix, while Container Apps workload profiles should
use deterministic names scoped to their environment.
