# METLEN incremental demo

A guided, step-by-step deployment of the [`metlenwithnaming`](..) root that
shows how a project grows one change at a time: each step adds a few blocks to
the environment's tfvars, Terraform plans only those additions, and existing
resources stay untouched. The last steps change, move and remove resources the
way day-2 work does. Databricks is not part of the demo.

Every step file describes the whole environment (the previous step plus the
blocks marked with its step number), so the difference between two step files
is exactly what a pull request to the environment would contain.

## Files

| File | Purpose |
|---|---|
| [`environment.tfvars.example`](environment.tfvars.example) | Where to deploy: subscription, tenant, region, hub VNet and tags. Copy to `environment.tfvars` (git-ignored) |
| [`hub/`](hub) | Stand-in for an existing hub VNet (resource group and VNet only), for subscriptions without one |
| [`step-1-foundation.tfvars`](step-1-foundation.tfvars) | Resource group, PRV and PUB VNets with every subnet, NSGs, route table, NAT Gateways, hub peering |
| [`step-2-security-storage.tfvars`](step-2-security-storage.tfvars) | Key Vault, container registry, Storage Account, Premium Files |
| [`step-3-compute.tfvars`](step-3-compute.tfvars) | A VM in each VNet, VM backup |
| [`step-4-databases.tfvars`](step-4-databases.tfvars) | Azure SQL, PostgreSQL, MySQL, Cosmos DB |
| [`step-5-app-platform.tfvars`](step-5-app-platform.tfvars) | App Service plans, Web App, Function App, Logic App, Application Insights, Log Analytics |
| [`step-6-container-apps.tfvars`](step-6-container-apps.tfvars) | Container Apps environment and app |
| [`step-7-day2-in-place.tfvars`](step-7-day2-in-place.tfvars) | Day 2: scale up a plan, raise the log cap, add an NSG rule, a blob container and a VNet peering |
| [`step-8-day2-move-remove.tfvars`](step-8-day2-move-remove.tfvars) | Day 2: move the Storage Account's Private Endpoints to the PUB VNet, remove the MySQL server |
| [`step-9-sql-mi-plan-only.tfvars`](step-9-sql-mi-plan-only.tfvars) | SQL Managed Instance, **plan only** |

## Prerequisites

- Terraform 1.10 or later and the Azure CLI, signed in with `az login` to the
  target subscription.
- Owner on the subscription, or Contributor plus User Access Administrator (or
  Role Based Access Control Administrator): the apps' identities get a role on
  Application Insights.
- Quota in the region for two `Standard_B2s_v2` VMs and for B1/B2, EP1 and WS1
  App Service plans.
- Free address space: the demo uses `10.70.0.0/22` (demo hub), `10.71.0.0/20`
  (PRV) and `10.72.0.0/22` (PUB). Change them in the step files (and
  `hub/variables.tf`) if they overlap your hub or on-premises ranges.

## One-time setup

Run everything from `environments\metlenwithnaming` (PowerShell shown; in bash
use `export TF_VAR_...=...` and forward slashes).

```powershell
# Where to deploy; edit subscription_id, tenant_id and owner afterwards.
Copy-Item demo\environment.tfvars.example demo\environment.tfvars

# Initial passwords for the VMs and for PostgreSQL/MySQL, never stored in a file.
$env:TF_VAR_vm_admin_password       = [Net.NetworkCredential]::new('', (Read-Host 'VM admin password' -AsSecureString)).Password
$env:TF_VAR_database_admin_password = [Net.NetworkCredential]::new('', (Read-Host 'Database admin password' -AsSecureString)).Password

# State: the demo uses the default local state of this root
# (terraform.tfstate here). `terraform state list` must be empty before step 1.
terraform init
terraform state list

# Demo hub (skip if you peer with an existing hub instead).
terraform -chdir=demo\hub init
terraform -chdir=demo\hub apply "-var-file=..\environment.tfvars"
terraform -chdir=demo\hub output -raw hub_peering   # paste this line into demo\environment.tfvars
```

Both passwords need 12 or more characters with at least three of lower case,
upper case, digits and special characters. To peer with an existing hub
instead, put its VNet resource ID in `hub_peering`; the hub-side peering then
needs Network Contributor on the hub VNet, or set
`create_hub_to_spoke_peering = false` and let the network team create it.

## The loop for every step

```powershell
# What changes compared with the previous step (the "pull request").
git diff --no-index demo\step-1-foundation.tfvars demo\step-2-security-storage.tfvars

$step = "step-2-security-storage"
terraform plan "-var-file=demo\environment.tfvars" "-var-file=demo\$step.tfvars" "-out=demo.tfplan"
terraform apply demo.tfplan
terraform plan "-var-file=demo\environment.tfvars" "-var-file=demo\$step.tfvars"   # No changes.
```

Read the plan summary before every apply: steps 1-6 must show
`0 to change, 0 to destroy`. The plan after the apply must report
`No changes`, which shows that the code and Azure agree.

## Steps and talking points

The resource counts come from planning each step file.

| Step | New resources | Show |
|---|---|---|
| 1 Foundation | 58 | `terraform output generated_resource_names`: every name is built from the METLEN tokens (`M-AZU-VNT-IT-PPA-GEO-PRV-DEV-SWE`, subnets `PPAGEODEVPRV01` …). The whole subnet plan sits in one map keyed by role; every subnet has an NSG; only subnets that need the internet use the NAT Gateway (subnets have no default outbound access); both VNets peer with the hub in both directions. |
| 2 Security and storage | 29 | Private by default: public network access is off, each service gets Private Endpoints in the `private_endpoints` subnet and records in Private DNS zones linked to both VNets. Storage uses Entra ID only (no shared keys). The existing resources are not in the plan. |
| 3 Compute | 10 | The `dmz` VM lands in the PUB VNet with one line (`virtual_network = "edge"`). No public IPs. The Recovery Services vault, the default policy and protected items appear without per-VM wiring. |
| 4 Databases | 25 | Azure SQL with Entra-only sign-in; PostgreSQL and MySQL injected into their delegated subnets; Cosmos DB through a Private Endpoint. |
| 5 App platform | 46 | Apps are private (`sites` Private Endpoints) and send outbound traffic through their integration subnets. Application Insights and Log Analytics are created because an app needs them, with Entra-authenticated telemetry. Function and Logic Apps get their own host storage. |
| 6 Container Apps | 7 | The environment goes to the VNet that lists `container_apps/apps` and uses the shared Log Analytics workspace. |
| 7 Day 2, in place | 4, plus 2 updates | `~ update in-place` for the App Service plan (B1 → B2) and the Log Analytics cap; new NSG rule, blob container and the PRV-PUB peering. Nothing is replaced or destroyed. |
| 8 Day 2, move and remove | see plan | The Storage Account's Private Endpoints are replaced in the PUB VNet while the account and its data stay; the MySQL server is destroyed and its subnet stays. Point out that removing a block destroys exactly that resource, so the plan must always be read before applying. |
| 9 SQL MI, plan only | 9 more than step 8 | Run only `terraform plan` with this file: creating an instance takes hours and it is billed by the hour. The instance brings its own NSG and route table on its delegated subnet. |

Steps 4-6 are the slow ones (databases, App Service and Container Apps take
several minutes each). Use the wait to walk through the code: the step file,
then the matching block in [`main.tf`](../main.tf) and the module under
[`modules/`](../../../modules).

## Quality: the mocked test suite

The root and the modules ship with plan-time tests that use a mocked Azure
provider: no sign-in, no cost, nothing deployed.

```powershell
terraform test                                     # every test file of the root
terraform test "-filter=tests\naming.tftest.hcl"   # one file; Windows needs the backslash
```

The tests cover naming, the network layout, Private Endpoints, hub peering,
Application Insights, Logic Apps and VM backup, including the validation
errors Terraform raises for wrong input.

## Teardown

```powershell
# Destroy still validates the inputs: the step files with VMs and databases
# need both passwords set (any valid value works when destroying).
$env:TF_VAR_vm_admin_password       = 'Destroy-Only-1!'
$env:TF_VAR_database_admin_password = 'Destroy-Only-2!'

# The demo: review the count, then apply.
$step = "step-8-day2-move-remove"   # the last step you applied
terraform plan -destroy "-var-file=demo\environment.tfvars" "-var-file=demo\$step.tfvars" "-out=destroy.tfplan"
terraform apply destroy.tfplan
terraform state list                # must print nothing

# The demo hub, after the demo (its VNet holds the hub-side peerings until then).
terraform -chdir=demo\hub plan -destroy "-var-file=..\environment.tfvars" "-out=hub-destroy.tfplan"
terraform -chdir=demo\hub apply hub-destroy.tfplan
terraform -chdir=demo\hub state list   # must print nothing
```

- Use the file of the last step you applied; Terraform destroys what is in the
  state either way.
- If the destroy fails, fix the cause and run it again rather than deleting
  resources in the portal. If something was deleted outside Terraform anyway
  (for example the resource group), run the destroy again: the refresh finds
  it gone and drops it from the state, so the state ends up empty.
- Check that nothing is left:
  `az group list --query "[?location=='swedencentral'].name" -o tsv` must no
  longer list `M-AZU-RGP-IT-PPA-GEO-DEV-SWE` or `rg-metlen-demo-hub`.
- Deleting the Container Apps environment takes about 20 minutes (Azure shows
  `ScheduledForDelete`); it is not stuck.
- `providers.tf` deletes VM backup data and purges Key Vaults on destroy (lab
  settings, marked for production there). Azure keeps instant-restore
  snapshots in a resource group it creates itself, `AzureBackupRG_<region>_1`;
  delete it by hand only if no other VM in the subscription is backed up in
  that region.

## Suggested half-day agenda

| Time | Activity |
|---|---|
| 0:00 | Repository tour: modules, the `metlenwithnaming` root, the naming standard, one tfvars per environment |
| 0:30 | Setup, demo hub, step 1 |
| 1:00 | Steps 2 and 3 |
| 1:30 | Steps 4 and 5 (walk through the modules while they apply) |
| 2:30 | Step 6, then steps 7 and 8 (day 2) |
| 3:15 | Step 9 plan, the mocked test suite |
| 3:30 | Questions; start the teardown |

## Repeating the demo in another subscription

- The step files contain no subscription data; only `environment.tfvars`
  changes.
- Storage Accounts, Key Vaults, registries, SQL, PostgreSQL, MySQL and Cosmos
  DB servers and the apps have globally unique names. If Azure reports a name
  as taken, change that resource's `sequence` in every step file.
- `naming_tokens` values must exist in
  [`locals.naming-dictionary.tf`](../locals.naming-dictionary.tf).

## Notes for the MCAPS sandbox

- Governance automation adds its own NSG to every subnet without one, which
  then blocks deleting the resource group. Every demo subnet therefore has an
  NSG from Terraform, and the demo hub VNet has no subnets.
- Governance also deallocates VMs at night and switches their disks to
  Standard HDD. The demo VMs use Standard HDD, so the next day's plan stays
  clean; start the VMs before showing them.
