# Implementation Plan: Azure Virtual Desktop (AVD) Modules

**Date**: 2026-10-26 | **Spec**: User request from 2026-10-26

## Summary

Add reusable Terraform modules for an Azure Virtual Desktop deployment and
integrate them into the `environments/lab` composition as an opt-in service.
The target design is a **pooled** host pool of **Microsoft Entra ID–joined**
Windows 11 Enterprise multi-session session hosts, published through a
**Desktop** application group and an AVD workspace. FSLogix user profiles
live on the existing private Premium Azure Files account using **Microsoft
Entra Kerberos** for cloud-only identities. A scaling plan powers hosts down
off-hours, and AVD Insights sends host pool, workspace, and session-host
telemetry to the shared Log Analytics workspace.

### Decisions

| Topic | Decision | Rationale |
|---|---|---|
| Identity | Microsoft Entra ID join | No domain controllers required; matches cloud-only identities. |
| Host pool type | Pooled (multi-session), BreadthFirst | Cost-efficient shared desktops. Personal pools are out of scope but the module keeps `type` explicit for later extension. |
| Application groups | Desktop only | Requested. RemoteApp can be added later as an extra application-group entry. |
| Session-host compute | New dedicated `avd-session-hosts` module | See "Why a dedicated session-host module" below. |
| FSLogix storage | Extend `premium-files` with optional Entra Kerberos and share RBAC | Reuses the private Premium Files account, Private Endpoint, and DNS that already exist. |
| Recommended optional features | FSLogix, scaling plan, AVD Insights: **included** | Profile roaming is mandatory for pooled hosts; scaling controls cost; Insights is the supported AVD monitoring path. |
| Deferred features | AVD Private Link, Compute Gallery custom images | Private Link needs extra feed/global endpoints, DNS zones, and client-side DNS; custom images need an image pipeline. Both remain additive later. |

### Why a dedicated session-host module

The existing `virtual-machine` module models one general-purpose Linux or
Windows VM with configurable data disks. Session hosts differ in ways that
would bloat that interface:

- Windows only, created as a **count of identical hosts** with
  15-character-safe computer names.
- They need a **system-assigned managed identity**, the
  `AADLoginForWindows` extension, and the AVD agent (DSC) extension consuming
  a sensitive host-pool registration token.
- Optional Azure Monitor Agent, data-collection-rule association, FSLogix and
  Entra Kerberos client configuration, and per-VM `Virtual Machine User Login`
  role assignments.
- Strict extension ordering (Entra join → AVD agent → monitoring) and
  `ignore_changes` on the token.

Keeping these in `avd-session-hosts` leaves the general VM module unchanged
and follows the repository rule of one cohesive responsibility per module.

### Requirements

| ID | Requirement | Source |
|---|---|---|
| REQ-001 | Create a pooled AVD host pool with configurable load balancing, max sessions, start-VM-on-connect, validation-environment flag, and Entra-join RDP properties. | Requested |
| REQ-002 | Generate a time-bounded host-pool registration token, exposed only as a sensitive output. | Derived |
| REQ-003 | Create a Desktop application group and assign `Desktop Virtualization User` to configured Entra groups. | Requested |
| REQ-004 | Create an AVD workspace and associate one or more application groups. | Requested |
| REQ-005 | Deploy N Entra-joined Windows 11 multi-session session hosts that register with the host pool, use Trusted Launch, have no public IP, and egress through NAT Gateway. | Requested |
| REQ-006 | Grant `Virtual Machine User Login` (and optionally `Virtual Machine Administrator Login`) on session hosts to configured groups. | Derived from Entra join |
| REQ-007 | Host FSLogix profiles on Premium Azure Files with Entra Kerberos, share-level RBAC, private connectivity, and session-host FSLogix configuration. | Recommended |
| REQ-008 | Create an optional scaling plan with weekday/weekend schedules and grant the AVD service principal `Desktop Virtualization Power On Off Contributor`. | Recommended |
| REQ-009 | Send AVD control-plane diagnostics and session-host performance/event data to Log Analytics (AVD Insights). | Recommended |
| REQ-010 | Integrate everything into the lab as opt-in, with central naming, a dedicated AVD subnet, NSG support, outputs, and examples. | Repository convention |
| REQ-011 | Provide mocked `terraform test` coverage for each new or changed module and the lab wiring, and update README and docs. | Repository convention |

## Technical Context

**Language/Version**: Terraform `>= 1.10.0, < 2.0.0`  
**Primary Dependencies**: `hashicorp/azurerm ~> 4.0` (lab lock 4.81.0), `hashicorp/random`, plus `hashicorp/time ~> 0.12` for token rotation (new lab dependency)  
**Azure Resources**:

- `azurerm_virtual_desktop_host_pool`, `azurerm_virtual_desktop_host_pool_registration_info`
- `azurerm_virtual_desktop_application_group`, `azurerm_virtual_desktop_workspace`, `azurerm_virtual_desktop_workspace_application_group_association`
- `azurerm_virtual_desktop_scaling_plan`, `azurerm_virtual_desktop_scaling_plan_host_pool_association`
- `azurerm_windows_virtual_machine`, `azurerm_network_interface`, `azurerm_virtual_machine_extension` (AADLoginForWindows, DSC AVD agent, AzureMonitorWindowsAgent), `azurerm_virtual_machine_run_command` (FSLogix/Kerberos registry)
- `azurerm_monitor_diagnostic_setting`, `azurerm_monitor_data_collection_rule`, `azurerm_monitor_data_collection_rule_association`
- `azurerm_role_assignment`
- `azurerm_storage_account.azure_files_authentication { directory_type = "AADKERB" }`

**Default image**: `MicrosoftWindowsDesktop` / `office-365` / Windows 11 24H2-or-later AVD M365 SKU, `latest`. The exact SKU is verified with `az vm image list-skus` during implementation. Entra Kerberos for cloud-only users requires Windows 11 24H2 build 26100.8116 or later.  
**Testing**: `terraform fmt -check`, `terraform validate`, and `terraform test` with `mock_provider "azurerm"`  
**Constraints**:

- Modules receive names from the environment and do not generate Azure names.
- Private by default: no public IPs; storage stays behind its Private Endpoint.
- Secrets (local admin password, registration token) are sensitive and generated in the root module or provider; they remain in state, as already documented for other secrets.
- Avoid adding the `azuread` provider. Entra group object IDs and the AVD service principal object ID are inputs.

## Module Design

### 1. `modules/avd-host-pool` (new)

Host pool, registration token, Desktop application group, and diagnostics.

| Input | Notes |
|---|---|
| `name`, `friendly_name`, `resource_group_name`, `location` | Names come from the lab. |
| `load_balancer_type` | `BreadthFirst` (default) or `DepthFirst`; validated. |
| `maximum_sessions_allowed` | Whole number ≥ 1. |
| `start_vm_on_connect`, `validate_environment` | Booleans. |
| `custom_rdp_properties` | Defaults to `targetisaadjoined:i:1;enablerdsaadauth:i:1;` plus sensible redirection settings. |
| `registration_expiration_date` | RFC 3339 timestamp, 1 hour–30 days in the future, supplied by `time_rotating` in the lab. |
| `desktop_application_group_name`, `desktop_friendly_name` | Desktop app group. |
| `user_group_object_ids` | `map(string)` with stable keys → `Desktop Virtualization User` on the app group. |
| `log_analytics_workspace_id` | Nullable; enables diagnostic settings (Checkpoint, Error, Management, Connection, HostRegistration, AgentHealthStatus, …). |
| `tags` | |

Outputs: `id`, `name`, `desktop_application_group_id`, `registration_token` (sensitive).

### 2. `modules/avd-workspace` (new)

Workspace, application-group associations, and diagnostics.

Inputs: `name`, `friendly_name`, `description`, `resource_group_name`,
`location`, `application_group_ids` (`map(string)` keyed by stable labels so
`for_each` is known at plan time), `public_network_access_enabled` (default
`true` until Private Link is added), `log_analytics_workspace_id`, `tags`.  
Outputs: `id`, `name`.

### 3. `modules/avd-scaling-plan` (new)

Scaling plan, host-pool associations, and the AVD service principal role.

Inputs: `name`, `resource_group_name`, `location`, `time_zone`,
`schedules` (list of objects mirroring the provider: days, ramp-up, peak,
ramp-down, off-peak times, load-balancing algorithms, capacity thresholds,
`ramp_down_force_logoff_users`, `ramp_down_wait_time_minutes`,
`ramp_down_notification_message`, `ramp_down_stop_hosts_when`),
`host_pool_ids` (`map(string)`), `avd_service_principal_object_id`,
`power_role_scope` (defaults to the resource group ID), `tags`.  
Validation covers HH:MM times, percentages from 0 to 100, and unique day sets.  
Outputs: `id`, `name`.

### 4. `modules/avd-session-hosts` (new)

Session-host VMs registered to a host pool.

| Input | Notes |
|---|---|
| `host_count` | Whole number ≥ 0. |
| `vm_names`, `nic_names`, `os_disk_names`, `computer_names` | Lists sized to `host_count`, generated by the lab; computer names validated to 1–15 characters. |
| `resource_group_name`, `location`, `subnet_id`, `zones` | Optional zone spreading. |
| `size` | Default `Standard_D4ads_v5`. |
| `admin_username`, `admin_password` (sensitive) | Local break-glass admin; the password is generated in the lab. |
| `source_image_reference` | Defaults to Windows 11 multi-session + M365. |
| `os_disk` | Caching, type (default `Premium_LRS`), size. |
| `license_type` | `Windows_Client` (AVD multi-session entitlement). |
| `host_pool_name`, `registration_token` (sensitive) | For the DSC AVD agent extension. |
| `avd_agent_configuration_url` | DSC package URL, with the current Microsoft gallery artifact as the default. |
| `intune_enrollment` | Bool; sets `mdmId` on AADLoginForWindows. |
| `user_login_principal_ids`, `admin_login_principal_ids` | `map(string)`, assigned per VM. |
| `fslogix` | Nullable object `{ vhd_location = "\\\\<account>.file.core.windows.net\\<share>", size_mb, … }`; when set, a run command configures FSLogix and Entra Kerberos (`CloudKerberosTicketRetrievalEnabled`, `LoadCredKeyFromProfile`). |
| `data_collection_rule_id` | Nullable; when set, installs the Azure Monitor Agent and associates the DCR. |
| `tags` | |

Design rules: system-assigned identity, Trusted Launch (Secure Boot and vTPM),
`patch_mode = "AutomaticByPlatform"`, no public IP, `encryption_at_host`
optional, and extension order enforced with `depends_on`. The DSC extension
`ignore_changes` its protected settings so token rotation does not redeploy
existing hosts.  
Outputs: `ids`, `names`, `private_ip_addresses`, `principal_ids`.

### 5. `modules/premium-files` (change, backward-compatible)

- Add `entra_kerberos` (nullable object; optional `domain_name` and
  `domain_guid` for hybrid use later). When set, render
  `azure_files_authentication { directory_type = "AADKERB" }`.
- Add `share_role_assignments`
  (`map(object({ share_key, principal_id, role_definition_name }))`) for
  `Storage File Data SMB Share Contributor` and
  `Storage File Data SMB Share Elevated Contributor`, scoped to the share.
- Existing callers keep the same behavior (both inputs default to off/empty).

### 6. AVD Insights data-collection rule

Insights requires a DCR in the `Microsoft-AVD` performance-counter and
Windows-event profile. It is created once per lab in a small
`modules/avd-insights-dcr` module, or inline in `avd-session-hosts` if review
shows a shared module adds no value. The DCR name must start with
`microsoft-avdi-` for the Insights workbook to discover it.

## Lab Integration (`environments/lab`)

- **Variables**: add `avd_host_pools` (map keyed by a stable label, 1–8
  characters), each entry containing host-pool settings, `session_hosts`
  (count, size, image, zones), `user_group_object_ids`,
  `admin_group_object_ids`, `fslogix` (premium account key and share key),
  and `scaling_plan` (nullable). Add `avd_workspace` (friendly name) and
  `avd_service_principal_object_id`. Add `subnet_cidrs.avd` (nullable,
  validated, non-overlapping).
- **Naming** (`locals.naming.tf` and `docs/resource-naming.md`): prefixes
  `vdpool`, `vdag`, `vdws`, and `vdscaling`; session hosts use
  `vm-avd<key>-<n>-<stem>`, `nic-…`, and `osdisk-…`; computer names use
  `avd<key><nn>` (≤ 15 characters); the subnet is `snet-avd-<stem>`.
- **Network**: enable a dedicated `avd` subnet only when host pools exist;
  add it to the NAT Gateway subnets (AVD agent and Entra endpoints need
  outbound access); allow optional NSG association through the existing
  `network_security_groups` map. No inbound rules are required because AVD
  uses reverse connect.
- **Log Analytics**: extend the `log_analytics` module `count` to cover AVD.
- **Secrets and tokens**: `random_password.avd_windows` per pool and
  `time_rotating.avd_registration` (for example, 7 days) feeding
  `registration_expiration_date`.
- **FSLogix**: the selected `premium_file_accounts` entry gets
  `entra_kerberos = {}` and share RBAC for user and admin groups; the
  session-host `fslogix.vhd_location` derives from that account and share.
- **Outputs**: host-pool IDs and names, workspace ID, session-host names and
  IPs, and the sensitive local admin passwords.
- **Examples**: AVD sections in `lab.tfvars.example`, disabled by default.

## Manual Prerequisites (documented, not automated)

1. Register the `Microsoft.DesktopVirtualization` resource provider.
2. Create Entra groups for AVD users and admins, and supply their object IDs.
3. Look up the object ID of the **Azure Virtual Desktop** service principal
   (app ID `9cdead84-a844-4324-93f2-b2e6bb768d07`) for the scaling plan.
4. After the storage account is created with Entra Kerberos, **grant admin
   consent** to its Entra application and **exclude it from MFA Conditional
   Access**, as required by Azure Files.
5. Configure NTFS ACLs on the profile share, or rely on FSLogix defaults
   with share RBAC.
6. Make sure users have eligible Windows Enterprise and M365 licenses.
   Users sign in with Entra credentials; Conditional Access policies apply.

## Implementation Steps

### Step 1: `premium-files` Entra Kerberos and share RBAC (REQ-007)

- 1.1 Add `entra_kerberos` and `share_role_assignments` variables with validation.
- 1.2 Add the conditional `azure_files_authentication` block and share-scoped role assignments.
- 1.3 Extend `tests/validation.tftest.hcl` for the off, on, and invalid-share-key cases.

### Step 2: `avd-host-pool` (REQ-001, 002, 003, 009)

- 2.1 Write `versions.tf`, `variables.tf` with validation, `main.tf`, and `outputs.tf`.
- 2.2 Add `tests/host-pool.tftest.hcl` covering defaults, Entra RDP properties, diagnostics on and off, and role assignments.

### Step 3: `avd-workspace` (REQ-004, 009)

- 3.1 Add the module files.
- 3.2 Add tests for associations and diagnostics.

### Step 4: `avd-scaling-plan` (REQ-008)

- 4.1 Add the module files with schedule validation.
- 4.2 Add tests for schedules, the association, the power role, and invalid times.

### Step 5: `avd-session-hosts` and the Insights DCR (REQ-005, 006, 007, 009)

- 5.1 Add the module files with ordered extensions, FSLogix run command, AMA, and DCR association.
- 5.2 Add tests for zero hosts, N hosts, name-length validation, FSLogix on and off, and AMA on and off.

### Step 6: Lab integration (REQ-010)

- 6.1 Variables, naming locals, subnet, NAT, Log Analytics, `time` provider, and lock file update (`terraform init -upgrade` limited to adding `time`).
- 6.2 Module blocks, outputs, and `lab.tfvars.example`.
- 6.3 Add `tests/avd.tftest.hcl`, and confirm the existing lab tests still pass when AVD is disabled.

### Step 7: Documentation (REQ-011)

- 7.1 README module table and an "Azure Virtual Desktop" configuration section.
- 7.2 `docs/resource-naming.md` prefixes and examples; `docs/execution-guide.md` prerequisites, post-deploy consent step, and troubleshooting (registration and Kerberos).

### Step 8: Validation

- `terraform fmt -recursive -check`
- `terraform init -backend=false` and `terraform validate` per module and in the lab
- `terraform test` per module and in the lab
- Optional: run `terraform plan` against the lab with a minimal AVD tfvars (one pool, one host), and apply only with approval.

## Out of Scope / Future

- Personal host pools and RemoteApp application groups
- AVD Private Link (`privatelink.wvd.microsoft.com`, global feed workspace)
- Azure Compute Gallery images and image builder pipeline
- AD DS or hybrid join
- MSIX app attach / App Attach packages
