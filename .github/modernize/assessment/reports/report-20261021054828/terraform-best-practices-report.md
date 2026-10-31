# Terraform Best-Practices Assessment

| Field | Value |
|---|---|
| Report ID | `20261021054828` |
| Generated (UTC) | 2026-10-21 05:48:28 |
| Scope | `environments/lab` (root module) and the 23 reusable modules under `modules/` |
| Out of scope | `environments/mcaps-ha-test` (scheduled for removal) |
| Assessment type | Azure Terraform / AzureRM provider best practices (structure, versioning, configuration, reusability, operability) |
| Commit | `04001a5` (working tree clean) |
| Terraform CLI | 1.14.3 (latest 1.16.x) |
| Provider lock | `azurerm` 4.81.0, `random` 3.9.1, `tls` 4.4.1 |
| References | [HashiCorp style guide](https://developer.hashicorp.com/terraform/language/style), [AzureRM provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) |

> AppCAT does not support Terraform-only repositories, so this report is a manual review of the code
> against Azure Terraform best practices. `terraform validate`, `terraform test`, security scanning and the
> Well-Architected Framework review were not part of this assessment.

## Executive summary

The codebase is in good shape. It follows the standard module layout, every module and root variable and output has a description, it has a lot of input validation (148 `validation` blocks plus lifecycle preconditions), `terraform fmt` reports no changes, and most modules have native `terraform test` suites with mocked providers. Security defaults are strong: public network access is disabled, TLS 1.2 is the minimum, Entra-only SQL auth is used, Key Vault uses RBAC, the ACR admin account is off, VMs use Trusted Launch, and secrets are generated rather than hard-coded.

The main gaps are **state and secret handling**, **no way to use the customer's central Private DNS zones**, **missing day-2 operations features (diagnostics, VM operations)** and **settings hard-coded in reusable modules**. None of them blocks the lab, but they should be fixed before the modules are used for production.

| Severity | Count |
|---|---|
| 🔴 High | 3 |
| 🟠 Medium | 6 |
| 🟡 Low | 5 |

## Strengths

- **Layout**: each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and `tests/`. Root locals are split by responsibility (`locals.naming.tf`, `locals.network.tf`, and so on).
- **Interface quality**: 100% of variables and outputs have descriptions. Variables use typed objects with `optional()` defaults. Sensitive inputs and outputs (`admin_password`, DB passwords, storage keys) are marked `sensitive`.
- **Validation**: `network` checks address-space containment and subnet overlap with preconditions. Root variables have 44 validations, including guards against attaching NSGs or route tables to the SQL MI subnet.
- **Testing**: 17 of 23 modules plus the lab root have `.tftest.hcl` suites that use `mock_provider`.
- **Secure defaults**: `public_network_access_enabled = false` on PaaS resources, private endpoints and Private DNS, `minimum_tls_version = "1.2"`, `https_only`, `ftps_state = "Disabled"`, `azuread_authentication_only_enabled = true`, `rbac_authorization_enabled = true`, `admin_enabled = false` on ACR, `allow_nested_items_to_be_public = false`, Trusted Launch (`secure_boot_enabled`, `vtpm_enabled`), and system-assigned identities on App Service, Functions, Cosmos DB, SQL MI and VMSS.
- **Version hygiene**: `required_version = ">= 1.10.0, < 2.0.0"`, pessimistic provider constraints, and a committed multi-platform `.terraform.lock.hcl`.
- **Consistent naming and tags** through generated `local.resource_names` and `local.common_tags`.
- **Git hygiene**: `.gitignore` and `.terraformignore` exclude state, `*.tfvars` (but keep `*.tfvars.example`), plans, keys and `backend.hcl`.

## Findings

### 🔴 High

#### H1 — Local state files with secrets are in a OneDrive-synced folder

- **Where**: `environments/lab/terraform.tfstate`, `environments/lab/terraform.tfstate.backup`
- **Issue**: The lab uses the default local backend. The remote `azurerm` backend exists only as `backend.tf.example`. The state files contain generated DB, VM and VMSS admin passwords, the `tls_private_key` private keys and storage account keys in plaintext. The repo is under `OneDrive - Microsoft`, so these files are synced to the cloud outside of git. Local state also has no locking and no versioning, and syncing can corrupt it.
- **Recommendation**: Make the remote backend the default: commit `backend.tf` with `backend "azurerm" {}` and pass `-backend-config=backend.hcl`, with `use_azuread_auth = true` (already in the example). Migrate the existing state with `terraform init -migrate-state`, then delete the local state files. Alternatively, move the working copy out of the OneDrive folder.

#### H2 — Generated credentials are stored in state instead of using write-only or ephemeral patterns

- **Where**: `environments/lab/main.tf` (`random_password.postgresql`, `random_password.mysql`, `random_password.vm_windows`, `random_password.vmss_windows`, `tls_private_key.vm`, `tls_private_key.vmss`). Root outputs expose the passwords (as `sensitive`). The Linux private keys are in state but are never output, so state is the only way to retrieve them.
- **Issue**: Terraform 1.11+ and recent AzureRM 4.x releases support **ephemeral resources** and **write-only arguments** (for example `administrator_password_wo` / `administrator_password_wo_version` on PostgreSQL and MySQL Flexible Server). These keep secrets out of state completely. The repo already has a `key-vault` module, but secrets are not written to it.
- **Recommendation**: Raise `required_version` to `>= 1.11` and switch DB admin passwords to `ephemeral "random_password"` with `*_wo` arguments. Store any credential an operator needs in Key Vault (`azurerm_key_vault_secret` with `value_wo`) instead of in outputs. For Linux VMs, prefer Entra ID login (`AADSSHLoginForLinux`) or a user-supplied public key over a key generated in state.

#### H3 — The lab always creates its own Private DNS zones and cannot use the customer's central zones

- **Context**: The customer has centrally deployed Private DNS zones that must be used for all resources. The zones created in this repo are only meant as a starting point.
- **Where**:
  - `module "private_dns"` in `environments/lab/main.tf`, which always creates every `privatelink.*` zone in `local.private_dns_zones` and links it to the lab VNet;
  - the root wiring `module.private_dns.zone_ids[...]` used by `module.private_endpoints`, `module.function_storage_private_endpoints`, `module.postgresql` and `module.mysql`;
  - `modules/container-apps/main.tf`, which always creates a zone for the environment's default domain, its VNet link and two A records.
- **What is already ready**: The modules accept zone IDs as inputs: `private-endpoint` takes `private_dns_zone_ids` and skips the DNS zone group when the list is empty, and `postgresql-flexible` / `mysql-flexible` take `private_dns_zone_id`. Only the lab root wiring and `container-apps` need to change.
- **Issue**: In a Cloud Adoption Framework / ALZ landing zone, workload spokes are often blocked from creating `privatelink.*` zones (the built-in `Deny-Private-DNS-Zones` policy). As written, the lab would either fail with `RequestDisallowedByPolicy` or create duplicate zones that clients outside the spoke cannot resolve.
- **Recommendation**:
  1. Add a root input such as `private_dns = { create_zones = bool, zone_ids = map(string) }`, where `zone_ids` maps each zone name to the ID of the customer's central zone. Create `module.private_dns` only when `create_zones = true`. Use one local map of zone name to zone ID for all consumers, and add a validation that every required zone has an ID.
  2. Decide who creates the Private Endpoint DNS records:
     - **Terraform**: pass the central zone IDs to `private_dns_zone_ids`. The deployment identity then needs `Private DNS Zone Contributor` on the central zones, or a custom role that includes `privateDnsZones/join/action`.
     - **Azure Policy** (DeployIfNotExists on private endpoints, common in ALZ): pass an empty list so Terraform does not manage the zone group. Without that, Terraform and Policy will both change it on every apply.
  3. PostgreSQL and MySQL Flexible Server (VNet-integrated) need the central zone ID and permission to create its VNet link. Check with the platform team that a link from the spoke VNet is allowed, or that the platform team creates it.
  4. `container-apps`: add a `create_private_dns_zone` flag. The internal environment's domain is generated by Azure and only known after the environment is created, so the central DNS team cannot create its zone in advance. Agree one approach: keep the zone in the workload and forward the domain to it, have the platform team create the zone and records after deployment (the module outputs the domain and static IP), or move to Container Apps Private Endpoint access, which uses a fixed `privatelink` zone that can be central.
  5. If the central zones are in a different subscription, a provider alias is only needed for resources Terraform creates there (VNet links or records). Referencing zone IDs does not need one.

### 🟠 Medium

#### M1 — No diagnostic settings or central logging

- **Where**: all modules. There is no `azurerm_monitor_diagnostic_setting` in the repo, and `log-analytics-workspace` is created only when Container Apps are enabled.
- **Recommendation**: Add an optional `diagnostic_settings` input (workspace ID plus log categories) to every PaaS module (Key Vault, SQL, PostgreSQL, MySQL, Cosmos DB, Storage, ACR, App Service, Functions, Load Balancer, NSG). Always create the workspace in the lab, or accept one as input.

#### M2 — Settings hard-coded inside reusable modules

| Module | Hard-coded value |
|---|---|
| `postgresql-flexible`, `mysql-flexible` | `backup_retention_days = 7`, `geo_redundant_backup_enabled = false` |
| `cosmos-db` | `zone_redundant = false`, single `geo_location`, `automatic_failover_enabled = false`, consistency bounds |
| `sql-managed-instance` | `zone_redundant_enabled = false`, `storage_account_type = "LRS"`, `proxy_override` |
| `azure-sql` | database `zone_redundant = false` |
| `key-vault` | `soft_delete_retention_days = 7` |
| `container-registry` | `sku = "Premium"` |
| `nat-gateway`, `load-balancer` | `sku = "Standard"` (acceptable) |

- **Recommendation**: Expose these as variables with defaults suited to the lab, so the same modules can be used for production-grade configurations without editing them.

#### M3 — `virtual-machine` module is missing operational features

- **Where**: `modules/virtual-machine/main.tf`
- **Issue**: There is no `zone` input, so VMs and data disks are not placed in availability zones. It also has no `identity` (VMSS has one), no `boot_diagnostics`, no `patch_mode` / `patch_assessment_mode`, and no `encryption_at_host_enabled` option.
- **Recommendation**: Add optional inputs for these, with secure defaults: managed boot diagnostics, `AutomaticByPlatform` patching, and a system-assigned identity.

#### M4 — Function App uses a storage account key and a connection string in app settings

- **Where**: `modules/function-app/main.tf` (`storage_account_access_key`, `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING`), and `module.function_storage` in `environments/lab/main.tf` with `shared_access_key_enabled = true`
- **Issue**: The account key is stored in state and in plain app settings. A content share on Azure Files still needs a key for Elastic Premium and Consumption plans, but the host storage (`AzureWebJobsStorage`) does not.
- **Recommendation**: Use `storage_uses_managed_identity = true` and grant `Storage Blob Data Owner`, `Storage Queue Data Contributor` and `Storage Table Data Contributor` to the app identity. Where a key is still needed, reference it from Key Vault (`@Microsoft.KeyVault(...)`). Consider a Flex Consumption or dedicated plan, which can run without a content share.

#### M5 — No CI pipeline or static-analysis tooling

- **Where**: repository root. There is no `.github/workflows`, `.tflint.hcl`, `.pre-commit-config.yaml` or Checkov/Trivy config. Validation currently relies on `scripts/invoke-ephemeral-lab.ps1` being run by hand.
- **Recommendation**: Add a PR pipeline that runs `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate` and `terraform test` for every module and the lab root, `tflint` with the `azurerm` ruleset, and an IaC scanner (Checkov or Trivy). Add `pre-commit-terraform` hooks for local runs.

#### M6 — Provider lower bounds don't match the features used

- **Where**: every `versions.tf` uses `azurerm ~> 4.0`.
- **Issue**: The modules use attributes added in later 4.x releases (for example `rbac_authorization_enabled` on Key Vault). With the current constraint, a consumer without this lock file could resolve an older 4.x release and fail. Azure guidance also recommends at least 4.2.
- **Recommendation**: Set the lower bound to the oldest version you actually test, for example `">= 4.x, < 5.0"`, consistently in the modules and the lab root.

### 🟡 Low

| # | Finding | Where | Recommendation |
|---|---|---|---|
| L1 | No per-module `README.md`. All documentation is in the root README (45 KB) and `docs/`. | `modules/*` | Generate module READMEs with `terraform-docs` (inputs, outputs, examples) and wire it into pre-commit. |
| L2 | 6 modules have no tests: `log-analytics-workspace`, `network-security-group`, `private-dns`, `private-endpoint`, `resource-group`, `route-table`. | `modules/*/tests` | Add `mock_provider` plan tests, at least for the NSG and route-table validations. |
| L3 | `features.key_vault.purge_soft_delete_on_destroy = true` is fixed in the provider block. A comment says to change it for production. | `environments/lab/providers.tf` | Drive it from a variable so persistent environments don't purge vaults on destroy. |
| L4 | The `lifecycle = "ephemeral"` tag is hard-coded in `common_tags`. | `environments/lab/locals.tags.tf` | Make it a variable so persistent environments are tagged correctly. |
| L5 | VM and VMSS default images use `version = "latest"`, and the default Linux image is Ubuntu 22.04. | `modules/virtual-machine*/main.tf` | Pin versions where builds must be reproducible, and consider Ubuntu 24.04 LTS (`ubuntu-24_04-lts`) as the default. Upgrade the local Terraform CLI (1.14.3 → 1.16.x). |

## Recommended remediation order

1. **H1**: Move to the remote backend and remove the local and OneDrive state copies.
2. **H3**: Add the option to use the central Private DNS zones (required before deploying into the customer landing zone).
3. **H2**: Use ephemeral or write-only secrets and Key Vault for credentials (requires Terraform ≥ 1.11).
4. **M5**: Add CI (fmt, validate, test, tflint, Checkov) so later changes are checked automatically.
5. **M1–M4**: Close the module reusability and operability gaps.
6. **M6, Low items**: Housekeeping.

## Inventory

| Area | Count |
|---|---|
| Root modules in scope | 1 (`lab`) |
| Reusable modules | 23 |
| `.tf` files (excluding `mcaps-ha-test`) | 101 |
| `terraform test` files | 21 (18 module + 3 lab) |
| Variables without description | 0 |
| Outputs without description | 0 |
| `validation` blocks (modules + lab root) | 148 (104 + 44) |
| `terraform fmt -check -recursive` | Pass |
