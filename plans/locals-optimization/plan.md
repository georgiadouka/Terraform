# Locals optimization plan: `environments/metlenwithnaming`

Status: **deferred**. Do this after the pending changes listed under
[Prerequisites](#prerequisites). Recorded 2026-10-28 from a review of the
`locals.*.tf` files.

## Context

The root module splits its locals by concern:

| File | Holds |
|---|---|
| [locals.naming-dictionary.tf](../../environments/metlenwithnaming/locals.naming-dictionary.tf) | Approved METLEN tokens, region codes and resource codes (the controlled dictionary) |
| [locals.naming.tf](../../environments/metlenwithnaming/locals.naming.tf) | Every generated name in one `resource_names` object |
| [locals.network.tf](../../environments/metlenwithnaming/locals.network.tf) | Subnet enablement and definitions, address plan, NAT, hub VNet parsing |
| [locals.private-connectivity.tf](../../environments/metlenwithnaming/locals.private-connectivity.tf) | Private Endpoint catalog, grouping, target IDs, Private DNS zones |
| [locals.tags.tf](../../environments/metlenwithnaming/locals.tags.tf) | Common tags |

The split is sound and should stay. The plan-time-only Private Endpoint
catalog and the name-free `deployed_subnet_keys` exist to avoid dependency
cycles, and every change below must preserve that. The weaknesses are mostly
inside `locals.naming.tf`.

## The legacy naming scheme is being eliminated

The legacy sample naming (`<prefix>-<project>-<environment>-<suffix>`) will be
removed shortly. This plan assumes that removal is done first, because it
deletes roughly half of `resource_names` and changes the scope of items 2
and 3 below.

What disappears with it:

- Inputs: `var.project_name`, `var.environment`, `var.naming` (`unique_suffix`
  and `prefixes`), and their validations in `variables.tf`.
- Resources and locals: `random_string.suffix`, `local.naming_suffix`,
  `local.name_stem` and `local.naming_prefixes`.
- Every name built from them: VMs, scale sets and their NICs, disks and
  autoscale settings; VNet peerings;
  subnet delegations; Container Apps
  environment DNS links, containers and workload profiles;
  Private DNS zone links; the VM `computer_name` suffix.

Hidden dependency to handle in that change: `locals.tags.tf` sets the
`environment` and `project` tags from `var.environment` and
`var.project_name`. Those tags need a new source, for example
`naming_tokens.environment` and `naming_tokens.application`, before the
variables can be removed.

Every legacy name needs either a METLEN code from the token owners or an
agreed derived pattern. Open register decisions D-02, D-03 and D-04 affect
the codes as well.

## Prerequisites

1. Remove the legacy naming scheme (above), including the tag change.
2. Findings 4-6 from the 2026-10-28 review: private registry pulls, central
   Private DNS for hub-and-spoke, and Always On on Elastic Premium. The live
   test showed Always On on Elastic Premium causes no drift and the Functions
   host runs, so that finding is low priority.

Done on 2026-10-28: Web Apps and Function Apps converted to maps, App Service
Plans split into `app_service_plans`, the boolean `services` switches removed
(SQL Managed Instance is now the `sql_managed_instances` map like every other
resource, `{}` meaning none, limited to at most one entry), SQL Managed
Instance moved to the METLEN standard with code `SMI`
(`m-azu-smi-<bu>-<dpt>-<app>-<env>-<reg>-<NN>`, lowercase because the name is
global DNS), SQL elastic pools moved to the METLEN standard with code `SEL`
(`M-AZU-SEL-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>` with the server's NN, like the
database), the NAT Gateway and its Public IP moved to the METLEN standard with
codes `NGW` and `PIP` (`M-AZU-NGW-…-<NN>` and `M-AZU-PIP-…-<NN>`, sharing
`nat_gateway.sequence`, default `00`), finding 3 fixed by removing
`create_before_destroy` from the NAT Public IP (with a fixed name, a
replacement would collide with the existing IP), the Log Analytics workspace
moved to the METLEN standard with code `LAW` (`M-AZU-LAW-…-<NN>`, NN from
`log_analytics_workspace.sequence`, default `00`), blob containers, file
shares and the databases inside SQL, PostgreSQL, MySQL and Cosmos DB taken out
of any naming convention (the application chooses the name; databases and
Cosmos DB containers default to the entry key; Azure's rules are checked at
plan time), the internal Function App content share renamed to the fixed
`function-content`, and the Defender for Storage
drift fix (`ignore_changes` on
`network_rules[0].private_link_access` in the `storage-account` and
`premium-files` modules). `SMI`, `SEL`, `NGW`, `PIP` and `LAW` still need
adding to the METLEN naming register.

If more than one SQL Managed Instance is ever needed, lifting the one-entry
limit requires deciding between one subnet (with its own NSG and route table)
per instance and a shared subnet; each instance already has its own NN.

## Operational notes from the 2026-10-28 live test

### App Service capacity error (`409 Conflict`, extended code `03029`)

A live apply of a Windows EP1 App Service Plan in Sweden Central failed with:

> No available instances to satisfy this request. App Service is attempting
> to increase capacity. Please retry your request later or consider enabling
> Async Scaling on your app service plan: aka.ms/async-scaling. If urgent,
> this can be mitigated by deploying this to a new resource group.

- **Cause:** a temporary regional capacity shortage on the scale unit that
  hosts the resource group's App Service Plans. It is not a configuration
  error, and the same plan deployed fine in the same region the day before.
- **Terraform does not retry it.** The AzureRM provider retries some
  throttling and transient responses, but treats this `409` as final and
  stops the run. Everything created before the error stays in state.
- **Recovery:** run the same `terraform apply` again later. It resumes from
  state and creates only the missing resources. In the live test a manual
  re-run a few minutes later succeeded.
- **If it persists:** wait 30-60 minutes; try another SKU size (for example
  EP2); or, as Azure suggests, deploy into a new resource group, which may
  land on a scale unit with capacity but means recreating what exists.
- **For CI/CD:** add a retry step that re-runs `terraform apply` after a delay
  when it fails with this error (`03029` / "No available instances"), with a
  bounded number of attempts, rather than failing the pipeline outright.

### Defender for Storage drift (fixed)

Microsoft Defender for Storage adds a resource instance rule
(`Microsoft.Security/datascanners/StorageDataScanner`) to storage account
network rules. Without the fix, every plan proposed removing it from each
storage account. Both storage modules now ignore `private_link_access`, and
the live re-plan reports no changes.

### Subnet NSGs added by subscription automation (open)

Within minutes of a subnet being created, an automation outside this tenant's
directory (service principal `da847d8c-ee71-44de-b462-6775e7d649a7`) adds an
NSG named `<VNET>-<SUBNET>-nsg-<region>` without custom rules and attaches it
to subnets that have none. The same pattern exists in other resource groups of
the subscription, so it is most likely the subscription's security baseline
("every subnet has an NSG"). Observed in the live test: NSGs for the Private
Endpoint, Web App and Function App integration subnets, two of them attached.

- **Plan/apply:** no drift, because the root module does not manage NSGs on
  those subnets.
- **Destroy:** AzureRM 4.x refuses to delete a resource group that still
  contains resources Terraform does not manage
  (`prevent_deletion_if_contains_resources` defaults to true). Confirmed on
  2026-10-28: `terraform destroy` of the live test removed everything else and
  then failed at the resource group, listing the three automation NSGs.
  Deleting them (`az network nsg delete`) and re-running `terraform destroy`
  completed the teardown.
- **Tags:** the NSGs inherit the resource group tags, including the
  misleading `managedBy = terraform`.
- **Own NSGs later:** an association from `network_security_groups` replaces
  the automation's NSG on that subnet and leaves the automation's NSG orphaned.

Options, decision pending:

1. Recommended: Terraform owns a default METLEN-named NSG on every deployed
   subnet that has no `network_security_groups` entry, so the automation finds
   every subnet compliant and creates nothing. Every subnet type in this root
   supports an NSG; SQL Managed Instance already has its own.
2. Lab only: set `features { resource_group { prevent_deletion_if_contains_resources = false } }`
   so destroy removes the resource group anyway. Hides the drift; not for
   production.
3. Ask the subscription owners to exclude these resource groups from the
   automation.

## Items

### 1. One helper per name family

`locals.naming.tf` repeats the same name assembly about 25 times:

- Full family, about 17 times:
  `join("-", ["M-AZU", <code>, local.metlen_scope, local.metlen_placement, <NN>])`
- Compact family, about 8 times:
  `"mazu${lower(<code>)}${local.metlen_compact_tokens}${<NN>}"`
- Lowercase variant, for SQL, PostgreSQL, MySQL, Cosmos DB and Container
  Apps: `lower(join(...))` of the full family.

Compute each family prefix once per resource code and reuse it:

```hcl
metlen_full = {
  for type, code in local.metlen_codes :
  type => "M-AZU-${code}-${local.metlen_scope}-${local.metlen_placement}"
}
metlen_lower   = { for type, prefix in local.metlen_full : type => lower(prefix) }
metlen_compact = {
  for type, code in local.metlen_codes :
  type => "mazu${lower(code)}${local.metlen_compact_tokens}"
}

# Usage
app_service_plans = {
  for key, plan in var.app_service_plans :
  key => "${local.metlen_full.app_service_plan}-${plan.sequence}"
}
key_vaults = {
  for key, vault in var.key_vaults :
  key => "${local.metlen_compact.key_vault}${vault.sequence}"
}
```

Names with an optional NN keep `join("-", compact([...]))`. The network family
(with PUB/PRV) and the subnet pattern stay separate because their grammar
differs. A change to the standard's grammar then touches two or three lines
instead of about 25.

### 2. Group `resource_names` by area

After the legacy names are gone, order `resource_names` the same way as
`main.tf` and the README (network, compute, storage, data, app platform,
monitoring), with one comment header per group. Today the order follows
neither, and legacy and METLEN names are interleaved.

### 3. One home for every name

Private Endpoint names (`<PARENTNAME>-<SERVICE>`) and Private DNS link names
are built in `locals.private-connectivity.tf`; everything else is in
`locals.naming.tf`.

- Private Endpoint names: keep them next to the catalog they are derived
  from (a deliberate exception), and say so in the header comment of
  `locals.naming.tf`.
- Private DNS link names: these are legacy today. Move them to
  `locals.naming.tf` with their new convention, or drop the item if the
  legacy removal already relocates them.

### 4. Single source for subnet roles (optional)

Adding a subnet type means editing `subnet_numbers` (naming),
`subnet_enabled` and `subnet_definitions` (network) and the `subnet_cidrs`
variable, and nothing checks they stay in sync. A single `subnet_roles` map
(number, enablement condition, delegation, extra settings per role) would
remove that risk.

Constraint: `deployed_subnet_keys` is used by variable validations and must not
depend on any name, or Terraform reports a dependency cycle. Split
`subnet_roles` into a name-free part (number, enablement, delegation service)
and add the names only in `subnet_definitions`.

### 5. Move the `unused_app_service_plans` local out of `main.tf`

The `locals` block added with `app_service_plans` (used by the
`unused_app_service_plans` check) is the only `locals` block in `main.tf`.
Move it to a new `locals.app-platform.tf`. This is independent of everything
else and can ship with any change.

### 6. Small content fixes

- The comment on `metlen_compact_tokens` lists the SQL logical server, which
  actually uses the lowercase hyphenated family. Correct the comment.
- `locals.tags.tf` hard-codes `lifecycle = "ephemeral"`. Make it an input (or
  derive it from `naming_tokens.environment`) before any UAT or PRD use.

## Verification

Items 1-3, 5 and 6 are pure refactors and must not change any generated name
or resource address.

1. Before starting, capture the generated names for every variable file:
   `lab.tfvars.example`, `lab.tfvars`, `multi-vm-storage.tfvars` and
   `demos/*.tfvars`. For each, run `terraform plan -out=<file>` and save
   `terraform show -json <file>` filtered to
   `planned_values.outputs.generated_resource_names`.
2. Repeat after the refactor and require identical output, plus identical
   resource addresses and counts in every plan.
3. `terraform fmt -check -recursive`, `terraform validate`, and
   `terraform test` in `environments/metlenwithnaming` (the naming tests pin
   every family) and in `environments/lab`.
4. Item 4 changes internal structure only; the same checks apply.

## Out of scope

- Changes to the naming standard itself (codes, grammar, decisions
  D-02/D-03/D-04).
- `environments/lab`, which keeps its own locals.
