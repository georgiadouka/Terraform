# Implementation Plan: Application Insights Module

**Date**: 2026-10-29 | **Spec**: User request from 2026-10-29

## Summary

Add a reusable `application-insights` Terraform module and wire one shared,
workspace-based Application Insights resource into `environments/metlenwithnaming`.
Every Function App and Web App sends telemetry to it by default and can opt out
per app. Ingestion is Microsoft Entra-only: local authentication is disabled on
the resource, each app sets `APPLICATIONINSIGHTS_AUTHENTICATION_STRING =
Authorization=AAD`, and each app's system-assigned identity receives
**Monitoring Metrics Publisher** on the resource.

Application Insights is not in the METLEN naming standard v0.2 (register or
working draft). Following the precedent of `LAW`, `NGW` and `DBR`, the code
`AIN` was agreed on 2026-10-29, giving
`M-AZU-AIN-<BU>-<DPT>-<APP>-<ENV>-<REG>-<NN>` (for example
`M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00`).

### Requirements

| ID | Requirement | Source |
|---|---|---|
| REQ-001 | A reusable module creates a workspace-based Application Insights resource with local authentication disabled by default. | Requested; Microsoft guidance |
| REQ-002 | The module grants Monitoring Metrics Publisher to a caller-supplied map of identities. | Derived from Entra-only ingestion |
| REQ-003 | One shared Application Insights resource is created when at least one Function App or Web App has telemetry enabled, named with the agreed `AIN` code. | Requested (shared topology, code AIN) |
| REQ-004 | Telemetry is on by default for every Function App and Web App and can be turned off per app. | Requested (on by default, opt out) |
| REQ-005 | Function Apps and Web Apps receive the connection string and the Entra authentication string; Web Apps in linux/windows mode also turn on the App Service agent. | Requested; Microsoft guidance |
| REQ-006 | Application Insights stores data in the shared Log Analytics workspace, whose daily cap and retention become configurable. | Requested |
| REQ-007 | Terraform warns when an app with telemetry has an integration subnet without NAT Gateway or a 0.0.0.0/0 route. | Requested (warning check, AMPLS deferred) |
| REQ-008 | Names, outputs, examples, tests and documentation are updated. | Derived quality requirement |

## Technical Context

**Language/Version**: Terraform `>= 1.10.0, < 2.0.0`; local Terraform 1.14.3
**Primary Dependencies**: HashiCorp AzureRM `~> 4.0`; lock file uses 4.81.0
**Azure Resources**: `azurerm_application_insights` (workspace-based, `application_type = "web"`), `azurerm_role_assignment`
**Testing**: Native Terraform tests with a mocked AzureRM provider; `terraform fmt` and `terraform validate`
**Target Platform**: `environments/metlenwithnaming`

**Constraints and findings**:

- Classic Application Insights is retired; the resource must use `workspace_id`.
  The shared Log Analytics workspace (`M-AZU-LAW-...`) is reused and is now
  also created when Application Insights is needed.
- The workspace's daily cap is 0.1 GB. Application Insights data counts
  against it, so ingestion stops early each day unless a deployment raises it.
  The cap and retention become `log_analytics_workspace` settings; defaults
  stay 0.1 GB and 30 days so existing plans do not change.
- Every subnet is private (`default_outbound_access_enabled = false`) and both
  app types use `vnet_route_all_enabled = true`. Telemetry to the public
  ingestion endpoint therefore needs NAT Gateway or a firewall route on
  `function_integration` / `web_app_integration`. A `check` block warns, as for
  Databricks egress. Azure Monitor Private Link Scope (AMPLS) is deferred
  because it changes Azure Monitor DNS for the whole VNet.
- Entra-only ingestion follows Microsoft Learn: *Configure monitoring for Azure
  Functions* (Require Microsoft Entra authentication) and *Microsoft Entra
  authentication for Application Insights* (App Service autoinstrumentation
  reads the same setting). The deployer needs rights to create role
  assignments, as for the Databricks Access Connector.
- App Service autoinstrumentation requires
  `ApplicationInsightsAgent_EXTENSION_VERSION` (`~3` Linux, `~2` Windows) and
  `XDT_MicrosoftApplicationInsights_Mode = recommended`. Container-mode Web
  Apps get only the connection and authentication strings; their own SDK or
  OpenTelemetry distro sends telemetry.
- Module internals are evaluated per input/output, so the role assignment map
  (app principal IDs) and the app settings (connection string) do not form a
  cycle as long as the module calls have no `depends_on` on each other.
- Found in the live test: on Function Apps the provider reads the
  `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting back into
  `site_config.application_insights_connection_string`, so the module sets the
  connection string there (the Entra string stays in `app_settings`); otherwise
  every plan shows a change. Web Apps have no such field.

## Live test (2026-10-29)

Deployed in the ME-MngEnvMCAP377803-georgiadouka-1 sandbox (Sweden Central,
workspace `appinsights-test`, tokens IT/PPA/GEO/UAT, NN 08): one Linux EP1
Python Function App, one Linux B1 Node Web App, NAT Gateway on both
integration subnets, `M-AZU-LAW-IT-PPA-GEO-UAT-SWE-08` and
`M-AZU-AIN-IT-PPA-GEO-UAT-SWE-08`.

- Application Insights: local authentication disabled, workspace-based.
- Both apps: `APPLICATIONINSIGHTS_AUTHENTICATION_STRING = Authorization=AAD`
  and the connection string; Web App agent `~3`; each identity holds
  Monitoring Metrics Publisher.
- Telemetry arrived within minutes: Function App traces, metrics and
  performance counters; Web App performance counters and the Always On
  request.
- A plan without NAT showed the `application_insights_egress` warning for both
  apps.
- After the site_config fix, a plan against the deployment reported no
  changes.
- `terraform destroy` removed every resource but failed on the resource group:
  Azure's auto-created "Failure Anomalies - M-AZU-AIN-…" smart detector alert
  rule was left inside it. Fixed with the provider setting
  `features { application_insights { disable_generated_rule = true } }`
  (disables the rule on create, deletes it on destroy); a separate
  apply/destroy of a resource group, Log Analytics and this module with the
  setting completed cleanly.

## Constitution Check

No repository `constitution.md` exists; the plan applies the repository's
observable conventions.

| Principle | Result | Evidence |
|---|---|---|
| Modules stay independent of environment naming | PASS | Name, workspace ID and principals are module inputs. |
| Modules use `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and `tests/` | PASS | Same layout as `log-analytics-workspace` and `function-app`. |
| METLEN names come only from the controlled dictionary | PASS | `AIN` added to `locals.naming-dictionary.tf` with its approval note. |
| Private by default | PASS | Apps stay private; only telemetry egress is required and is warned about. |
| Input errors fail at plan time | PASS | Sequence, cap and retention validations. |
| Mocked plan coverage before deployment | PASS | Module and environment tests in the task list. |

## Applied Guidelines

- Microsoft Learn: Azure Functions monitoring, Application Insights Entra
  authentication, App Service autoinstrumentation, App Service NAT Gateway
  integration.
- Repository conventions: shared Log Analytics pattern, `check` warnings for
  missing egress, role assignments inside the owning module
  (`databricks-workspace`), "Agreed <date>, not in register v0.2 yet" codes.

## Implementation Steps

### Step 1: Application Insights module

- **Requirements**: REQ-001, REQ-002
- **Plan items**:
  - **1.1** Create `modules/application-insights` with inputs `name`,
    `resource_group_name`, `location`, `workspace_id`, `application_type`
    (default `web`), `local_authentication_enabled` (default `false`; the
    provider deprecated `local_authentication_disabled` in 4.x),
    `metrics_publisher_principal_ids` (map, default `{}`) and `tags`.
  - **1.2** Create `azurerm_application_insights` and one
    `azurerm_role_assignment` (Monitoring Metrics Publisher,
    `principal_type = "ServicePrincipal"`) per map entry.
  - **1.3** Output `id`, `name`, `app_id`, the sensitive `connection_string`
    and `role_assignment_ids` (keyed like the input map).

### Step 2: App modules accept Application Insights

- **Requirements**: REQ-005
- **Plan items**:
  - **2.1** Add an optional sensitive `application_insights` object
    (`connection_string`, `entra_authentication` default `true`) to
    `function-app`; set `site_config.application_insights_connection_string`
    and, when Entra is on, merge `APPLICATIONINSIGHTS_AUTHENTICATION_STRING`.
  - **2.2** Add the same input to `web-app`; for linux/windows mode also set
    the agent extension version and collection mode. Telemetry settings take
    precedence over `app_settings`.

### Step 3: Log Analytics settings

- **Requirements**: REQ-006
- **Plan items**:
  - **3.1** Add `daily_quota_gb` (default 0.1, `-1` = no cap) and
    `retention_in_days` (default 30, 30-730) to `var.log_analytics_workspace`
    and pass them to the module.
  - **3.2** Create the workspace when Application Insights is needed.

### Step 4: Environment wiring

- **Requirements**: REQ-003, REQ-004, REQ-007
- **Plan items**:
  - **4.1** Add `application_insights = "AIN"` to the naming dictionary and
    `resource_names.application_insights`.
  - **4.2** Add `var.application_insights` (`enabled`, default `true`, a
    global off switch for deployers without role-assignment rights;
    `sequence`, default `00`) and a per-app `application_insights` flag
    (default `true`) on `function_apps` and `web_apps`.
  - **4.3** Add the module call (count 0/1), pass the connection string to
    every opted-in app, and pass the app principal IDs for the role
    assignments.
  - **4.4** Add the `application_insights_egress` warning check.
  - **4.5** Add an `application_insights` output and a per-app flag in the
    `function_apps` and `web_apps` outputs.

### Step 5: Validation and documentation

- **Requirements**: REQ-008
- **Plan items**:
  - **5.1** Module tests for defaults, role assignments and inputs; app module
    tests for the new settings.
  - **5.2** Environment tests for naming, creation/opt-out, Log Analytics
    creation, role assignments and the egress warning. Existing test files
    set `application_insights = { enabled = false }` at file level, because
    their apps have no NAT Gateway and `terraform test` treats a failed
    `check` as an error.
  - **5.3** Update `lab.tfvars.example` (including NAT on both integration
    subnets), `README.md`, `docs/metlen-naming-locals.md` and
    `docs/naming-standard-v0.2-implementation.md`. `docs/execution-guide.md`
    describes `environments/lab`, which is unchanged.

## Project Structure

```text
modules/
|-- application-insights/        (new)
|   |-- main.tf
|   |-- variables.tf
|   |-- outputs.tf
|   |-- versions.tf
|   `-- tests/
|       `-- application-insights.tftest.hcl
|-- function-app/                (application_insights input, tests)
|-- web-app/                     (application_insights input, tests)
`-- log-analytics-workspace/     (unchanged)

environments/metlenwithnaming/
|-- locals.naming-dictionary.tf  (AIN)
|-- locals.naming.tf             (resource name)
|-- variables.tf                 (application_insights, per-app flags, LAW settings)
|-- main.tf                      (module call, app wiring, egress check)
|-- outputs.tf
|-- lab.tfvars.example
`-- tests/
    |-- application-insights.tftest.hcl (new)
    `-- naming.tftest.hcl

plans/application-insights/plan.md
```

## Testing Strategy

- **Module**: workspace ID, `web` type and local authentication disabled by
  default; one role assignment per principal with the right role and scope;
  no assignments for an empty map; invalid `application_type` rejected.
- **App modules**: no telemetry settings without the input; connection and
  authentication strings with it; Entra string omitted when turned off; Web App
  agent `~3` on Linux, `~2` on Windows, none in container mode.
- **Environment**: `M-AZU-AIN-IT-PPA-ECM-DEV-SWE-00` and custom sequence;
  one shared resource and Log Analytics when an app exists; per-app opt-out;
  no resource when every app opts out or `enabled = false`; role assignment
  keys; egress warning without NAT; Log Analytics cap and retention accepted
  and validated. App settings are covered by the app module tests.

## Task Breakdown

### Phase 1: Modules

- [x] T001 [Plan:1.1-1.3] Create `modules/application-insights` and its tests.
- [x] T002 [P] [Plan:2.1] Extend `modules/function-app` and its tests.
- [x] T003 [P] [Plan:2.2] Extend `modules/web-app` and its tests.

### Phase 2: Environment

- [x] T004 [Plan:3.1,3.2] Log Analytics settings and creation condition.
- [x] T005 [Plan:4.1,4.2] Naming code, resource name and variables.
- [x] T006 [Plan:4.3-4.5] Module call, app wiring, egress check and outputs.
- [x] T007 [P] [Plan:5.3] `lab.tfvars.example`.

### Phase 3: Validation and documentation

- [x] T008 [Plan:5.1,5.2] Environment tests; run `terraform fmt`, `validate`
  and the module and environment tests.
- [x] T009 [P] [Plan:5.3] README and docs.

## Requirement Mapping

| REQ ID | Description | Plan Items | Implementation Evidence |
|---|---|---|---|
| REQ-001 | Workspace-based module, local auth disabled | 1.1, 1.2, 5.1 | `modules/application-insights`, module tests |
| REQ-002 | Monitoring Metrics Publisher assignments | 1.2, 4.3, 5.1, 5.2 | Role assignment resource, tests |
| REQ-003 | One shared `AIN` resource | 4.1, 4.3, 5.2 | Naming dictionary, module call, naming tests |
| REQ-004 | On by default, opt out per app | 4.2, 4.3, 5.2 | Per-app flag, environment tests |
| REQ-005 | App settings for Functions and Web Apps | 2.1, 2.2, 4.3, 5.1 | App modules, tests |
| REQ-006 | Log Analytics workspace reuse and settings | 3.1, 3.2, 5.2 | Variables, module call, tests |
| REQ-007 | Egress warning | 4.4, 5.2 | `check "application_insights_egress"`, tests |
| REQ-008 | Outputs, examples, docs | 4.5, 5.3 | Outputs, `lab.tfvars.example`, docs |

## Deferred Scope

- Azure Monitor Private Link Scope with a private endpoint and the
  `privatelink.monitor.azure.com` family of DNS zones (changes Azure Monitor
  name resolution for the whole VNet; needs a hub-level decision).
- One Application Insights resource per app.
- Application Insights daily cap, sampling and availability tests.
- Diagnostic settings for Function Apps and Web Apps (platform logs to Log
  Analytics).
- Adding `AIN` to the METLEN register (owner: naming standard governance).
