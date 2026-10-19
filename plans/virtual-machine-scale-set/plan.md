# Implementation Plan: Azure Virtual Machine Scale Set Module

**Date**: 2026-10-18 | **Spec**: User request from 2026-10-18

## Summary

Add a reusable `virtual-machine-scale-set` Terraform module and integrate it into the lab composition. The module will support Linux and Windows Uniform VM scale sets, explicit Azure Marketplace image selection, configurable OS disk sizing, and a stable map of zero or more data-disk templates. Each configured data disk is created for every scale-set instance, matching Azure VMSS semantics.

Azure Monitor will be the single owner of runtime capacity in both fixed and autoscale modes. Terraform will own the scaling policy: fixed mode uses equal minimum, default, and maximum capacity, while autoscale mode adds CPU scale-out and scale-in rules within validated bounds.

### Requirements

| ID | Requirement | Source |
|---|---|---|
| REQ-001 | The user can select Linux or Windows, and the module creates only the matching OS-specific VMSS resource. | Requested |
| REQ-002 | The user can select the OS release and image build using an Azure Marketplace image reference. | Requested |
| REQ-003 | The user can configure OS disk size, caching, and storage account type. | Requested |
| REQ-004 | The user can configure zero, one, or multiple data disks with stable labels, unique LUNs, sizes, caching, and storage account types. | Requested; zero disks retained for module reuse |
| REQ-005 | The user can configure VM SKU, availability zones, upgrade mode, and either fixed or CPU-based autoscale capacity without Terraform drift. | Requested and derived technical requirement |
| REQ-006 | VMSS instances use private networking with no public IP and can optionally join load-balancer or Application Gateway backend pools. | Derived from repository topology |
| REQ-007 | Linux uses SSH-only authentication, Windows uses a generated password, and both variants use Trusted Launch and managed identity. | Derived from existing VM security pattern |
| REQ-008 | The lab can enable the VMSS independently or alongside the existing VM while correctly sharing the VM subnet and NAT Gateway. | Derived integration requirement |
| REQ-009 | The module and lab expose stable, non-secret outputs; generated credentials remain sensitive. | Derived module contract requirement |
| REQ-010 | Module behavior, lab wiring, examples, and operator documentation are validated and documented. | Derived quality requirement |

## Technical Context

**Language/Version**: Terraform `>= 1.10.0, < 2.0.0`; locally available Terraform 1.14.3  
**Primary Dependencies**: HashiCorp AzureRM provider `~> 4.0`; current lock file uses AzureRM 4.81.0  
**Azure Resources**: `azurerm_linux_virtual_machine_scale_set` and `azurerm_windows_virtual_machine_scale_set` with Uniform orchestration  
**Storage**: Azure-managed OS and inline VMSS data disks; each data-disk template applies to every instance  
**Testing**: Native Terraform test framework with mocked AzureRM resources, plus `terraform fmt` and `terraform validate`  
**Target Platform**: Azure, initially integrated with the `environments/lab` root module in Sweden Central  
**Performance Goals**: Deterministic plans for zero-to-many disks and no unnecessary standalone disk or NIC resources  
**Constraints**:

- Follow the repository's single-file module pattern unless the implementation becomes materially clearer when split.
- Use OS-specific VMSS resources rather than the deprecated generic VMSS resource.
- Preserve private-by-default networking and shared NAT egress.
- Do not create standalone `azurerm_managed_disk` attachments for VMSS data disks; use inline `data_disk` blocks.
- Treat map keys as stable Terraform labels only; Azure generates per-instance disk names.
- Validate values that Terraform can know, while documenting that per-SKU disk-count and disk-type support is enforced by Azure.
- Let Azure Monitor own runtime capacity in both fixed and autoscale modes; Terraform owns the capacity profile and ignores VMSS `instances` drift.

## Constitution Check

No repository `constitution.md` exists. The plan therefore applies the repository's observable conventions.

| Principle | Result | Evidence |
|---|---|---|
| Reusable modules remain independent of environment naming | PASS | Names and Azure IDs enter through module variables. |
| Environment-specific defaults remain in the root module and `.tfvars` | PASS | Lab variables provide defaults and examples; the module remains generic. |
| Private connectivity is the default | PASS | The VMSS NIC has a private IP configuration and no public IP block. |
| Linux and Windows behavior remain explicit and type-safe | PASS | Separate OS-specific resources are selected by validated `os_type`. |
| Input errors fail during validation where possible | PASS | Image fields, disk sizes, LUN uniqueness, caching, capacity, and OS type receive validation. |
| Changes receive mocked plan coverage before deployment | PASS | Module and lab Terraform tests are included in the task breakdown. |

## Applied Guidelines

- **Azure Terraform best practices**: use supported OS-specific AzureRM resources, current provider documentation, explicit variables, validation, formatting, and `terraform validate`.
- **Azure Verified Module reference**: use `avm-res-compute-virtualmachinescaleset` 0.11.1 as a design reference without importing its much broader interface into this repository.
- **HashiCorp style**: preserve predictable names, typed objects, useful descriptions, locals for derived values, and outputs limited to stable resource attributes.
- **Repository conventions**: mirror the existing `virtual-machine` module's OS defaults, authentication split, Trusted Launch settings, variable validation, test style, and lab service-toggle integration.
- No matching transformation guideline exists under the loaded `guidelines` skill.

## Implementation Steps

### Step 1: Define the reusable VMSS contract

- **Requirements**: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-007
- **Design inputs**: Existing `modules/virtual-machine/main.tf`, AzureRM Linux/Windows VMSS schemas, Azure Verified VMSS module documentation
- **Plan items**:
  - **1.1** Define strongly typed inputs for name, resource group, location, subnet, SKU, scaling mode and capacity, CPU rules, zones, OS type, administrator, image, OS disk, data disks, backend pool IDs, upgrade mode, and tags.
  - **1.2** Use an optional `source_image_reference` object with `publisher`, `offer`, `sku`, and `version`. Keep Ubuntu 22.04 Gen2 and Windows Server 2022 Azure Edition as OS-specific defaults for consistency with the existing VM module. Document that `sku` selects the OS release while `version` selects the Marketplace image build.
  - **1.3** Validate `os_type`, nonblank image fields, positive whole-number capacity and disk sizes, supported caching modes, nonblank storage types, stable data-disk labels, and unique non-negative whole-number LUNs.
  - **1.4** Keep Linux SSH public keys and Windows passwords mutually exclusive at the resource boundary; keep the module credential-generation agnostic.

### Step 2: Implement OS-specific VMSS resources and disk templates

- **Requirements**: REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-007
- **Design inputs**: AzureRM VMSS resource schemas and repository VM security defaults
- **Plan items**:
  - **2.1** Create exactly one of `azurerm_linux_virtual_machine_scale_set` or `azurerm_windows_virtual_machine_scale_set` based on `os_type`, with shared locals for the selected image and outputs.
  - **2.2** Configure the OS disk inline with caller-controlled size, caching, and storage account type. Resolve null size to 32 GiB for the default Linux image or 127 GiB for the default Windows image, and reject an undersized default Windows disk.
  - **2.3** Render a dynamic inline `data_disk` block for every entry in the `data_disks` map. Each block uses its configured LUN, size, caching, and storage account type and is reproduced on every scale-set instance.
  - **2.4** Configure one primary private NIC/IP configuration, optional load-balancer and Application Gateway backend pool IDs, system-assigned managed identity, Secure Boot, vTPM, and tags.

### Step 3: Define capacity lifecycle and outputs

- **Requirements**: REQ-005, REQ-009
- **Design inputs**: AzureRM VMSS, Azure Monitor Autoscale, and upgrade-mode contracts
- **Plan items**:
  - **3.1** Add a `scaling` object with `fixed` and `autoscale` modes. Fixed mode sets minimum, default, and maximum to the configured capacity; autoscale mode validates `minimum <= default <= maximum` and adds CPU scale-out and scale-in rules.
  - **3.2** Export the selected VMSS ID, name, unique ID, OS type, and managed-identity principal ID through OS-neutral outputs.
  - **3.3** Always let Azure Monitor own runtime capacity. Seed the VMSS with the default capacity, ignore later `instances` drift, and manage the desired fixed or automatic capacity through `azurerm_monitor_autoscale_setting`.
  - **3.4** Permit optional zones and validated `Manual` or `Automatic` upgrade modes. Default to `Manual`; defer `Rolling` until a health-probe/application-health contract is introduced.

### Step 4: Integrate the VMSS into the lab composition

- **Requirements**: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009
- **Design inputs**: Existing lab naming, subnet gating, NAT Gateway, credential generation, and output patterns
- **Plan items**:
  - **4.1** Add `virtual_machine_scale_set` naming and service-toggle entries plus a typed lab configuration object matching the module's supported inputs.
  - **4.2** Generate a dedicated VMSS SSH key or Windows password only when the service and matching OS are selected; do not reuse the standalone VM credential resources.
  - **4.3** Instantiate the module conditionally, reuse the `virtual_machines` subnet, and update subnet/NAT conditions so either a VM or VMSS keeps the shared subnet and NAT association active.
  - **4.4** Add lab outputs for VMSS ID, name, OS type, principal ID, SSH public key, and sensitive Windows password.
  - **4.5** Add disabled-by-default Linux and Windows examples showing custom image selection, OS disk size, and multiple data disks in `terraform.tfvars.example`; keep the real lab `.tfvars` disabled unless deployment is explicitly requested.

### Step 5: Validate behavior and document operation

- **Requirements**: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009, REQ-010
- **Design inputs**: Existing Terraform test files, README module inventory, and execution guide
- **Plan items**:
  - **5.1** Add mocked module plans for Linux defaults, Windows defaults, custom images, custom OS disks, zero/one/multiple data disks, private networking, identity, fixed scaling, CPU autoscaling, outputs, and invalid inputs.
  - **5.2** Extend lab mocked plans to verify service toggles, credential selection, shared subnet/NAT behavior, generated names, fixed/autoscale configuration, module outputs, and coexistence with the standalone VM.
  - **5.3** Update the README and execution guide with input examples, image semantics, per-instance disk behavior, replacement/upgrade implications, capacity ownership, cost, quota, and regional/SKU compatibility notes.
  - **5.4** Run `terraform fmt -check -recursive`, targeted module tests, targeted lab tests, and `terraform validate`; resolve only failures caused by this feature.

## Project Structure

```text
modules/
`-- virtual-machine-scale-set/
    |-- main.tf
    `-- tests/
        `-- operating-system-and-disks.tftest.hcl

environments/
`-- lab/
    |-- main.tf
    |-- outputs.tf
    |-- terraform.tfvars.example
    |-- variables.tf
    `-- tests/
        `-- configuration.tftest.hcl

docs/
`-- execution-guide.md

README.md
plans/
`-- virtual-machine-scale-set/
    |-- plan.md
    |-- research.md
    `-- checkpoints/
        |-- plan-to-tasks.yaml
        `-- spec-to-plan.yaml
```

## Testing Strategy

- **Module contract tests**: Mock Linux and Windows VMSS resources and assert that only the selected resource exists.
- **Image tests**: Assert OS-specific defaults and complete caller-provided Marketplace references.
- **Disk tests**: Assert default/custom OS disk sizes and zero, one, and multiple inline data-disk blocks with stable LUNs.
- **Scaling tests**: Assert fixed mode produces equal capacity bounds with no rules and autoscale mode produces validated CPU scale-out/scale-in rules.
- **Validation tests**: Reject invalid OS type, blank image fields, nonpositive or fractional sizes, duplicate/invalid LUNs, unsupported caching, invalid capacity ordering, overlapping CPU thresholds, missing Linux key, and missing Windows password.
- **Security/network tests**: Assert no public IP block, system-assigned identity, Secure Boot, vTPM, subnet assignment, and optional backend pool propagation.
- **Composition tests**: Assert subnet and NAT retention for VM-only, VMSS-only, both, and neither; assert OS-specific credentials and outputs.
- **Acceptance criteria**: Formatting, targeted tests, and validation pass with no unplanned resource changes outside the VMSS integration surfaces.

## Task Breakdown

### Phase 1: Module setup and contract

- [ ] T001 [Plan:1.1,1.3] Create the typed VMSS input contract, validation rules, image locals, and OS-neutral locals in `modules/virtual-machine-scale-set/main.tf`.
- [ ] T002 [Plan:1.2,1.4,2.1] Add mutually exclusive Linux and Windows VMSS resource skeletons, OS-specific image defaults, and authentication blocks in `modules/virtual-machine-scale-set/main.tf`.

### Phase 2: VMSS storage, networking, and lifecycle

- [ ] T003 [Plan:2.2] Add configurable inline OS disk blocks and default-image disk-size validation in `modules/virtual-machine-scale-set/main.tf`.
- [ ] T004 [Plan:2.3] Add map-driven dynamic inline data-disk blocks for both OS resources in `modules/virtual-machine-scale-set/main.tf`.
- [ ] T005 [Plan:2.4] Add private NIC/IP configuration, optional backend pool IDs, managed identity, Secure Boot, vTPM, and tags in `modules/virtual-machine-scale-set/main.tf`.
- [ ] T006 [Plan:3.1,3.3,3.4] Add Azure Monitor-owned fixed/autoscale capacity, CPU rules, VMSS capacity drift suppression, zones, and validated upgrade-mode behavior in `modules/virtual-machine-scale-set/main.tf`.
- [ ] T007 [Plan:3.2] Add OS-neutral VMSS identity and metadata outputs in `modules/virtual-machine-scale-set/main.tf`.

### Phase 3: Lab integration

- [ ] T008 [Plan:4.1] Add VMSS naming, service toggle, and typed VMSS configuration variables in `environments/lab/variables.tf`.
- [ ] T009 [Plan:4.2,4.3] Add VMSS credentials, names, conditional module call, subnet gating, and NAT conditions in `environments/lab/main.tf`.
- [ ] T010 [P] [Plan:4.4] Add non-secret and sensitive VMSS outputs in `environments/lab/outputs.tf`.
- [ ] T011 [P] [Plan:4.5] Add disabled-by-default Linux and Windows VMSS examples with multiple data disks in `environments/lab/terraform.tfvars.example`.

### Phase 4: Validation

- [ ] T012 [P] [Plan:5.1] Add mocked Linux/Windows, image, OS disk, multiple data disk, network, identity, fixed/autoscale capacity, output, and invalid-input plans in `modules/virtual-machine-scale-set/tests/operating-system-and-disks.tftest.hcl`.
- [ ] T013 [P] [Plan:5.2] Extend service-toggle, credential, shared subnet/NAT, naming, fixed/autoscale capacity, coexistence, and output plans in `environments/lab/tests/configuration.tftest.hcl`.

### Phase 5: Documentation and final quality gates

- [ ] T014 [P] [Plan:5.3] Add the VMSS module, topology behavior, image semantics, and per-instance data-disk behavior to `README.md`.
- [ ] T015 [P] [Plan:5.3] Add VMSS configuration, cost/quota, upgrade, capacity ownership, and deployment guidance to `docs/execution-guide.md`.
- [ ] T016 [Plan:5.4] Run recursive formatting checks, targeted module and lab Terraform tests, and lab validation; fix feature-related failures.

## Requirement Mapping

| REQ ID | Description | Plan Items | Implementation Evidence |
|---|---|---|---|
| REQ-001 | Select Linux or Windows VMSS | 1.1, 1.2, 2.1, 4.1, 4.5, 5.1 | `modules/virtual-machine-scale-set/main.tf`, module and lab tests |
| REQ-002 | Select OS release and image build | 1.1, 1.2, 1.3, 2.1, 4.5, 5.1 | Image variables/locals, example values, image assertions |
| REQ-003 | Configure OS disk | 1.1, 1.3, 2.2, 4.5, 5.1 | OS disk blocks, validation, examples, disk assertions |
| REQ-004 | Configure zero-to-many data disks | 1.1, 1.3, 2.3, 4.5, 5.1 | `data_disks` map, dynamic blocks, multiple-disk tests |
| REQ-005 | Configure fixed/autoscale capacity, SKU, zones, and upgrades | 1.1, 1.3, 3.1, 3.3, 3.4, 4.1, 5.1 | Capacity policy, Azure Monitor rules, lifecycle ownership, validation, tests |
| REQ-006 | Use private networking and optional backend pools | 1.1, 2.4, 4.3, 5.1, 5.2 | VMSS NIC blocks, subnet/NAT wiring, network assertions |
| REQ-007 | Apply secure OS-specific authentication and identity | 1.4, 2.1, 2.4, 4.2, 5.1, 5.2 | SSH/password resources, Trusted Launch, identity assertions |
| REQ-008 | Integrate independently with the lab | 4.1, 4.2, 4.3, 4.5, 5.2 | Lab variables, locals, module call, toggles, composition tests |
| REQ-009 | Expose stable outputs and protect credentials | 3.2, 4.4, 5.1, 5.2 | Module/lab outputs and sensitive password output |
| REQ-010 | Validate and document the feature | 5.1, 5.2, 5.3, 5.4 | Terraform tests, README, execution guide, quality-gate results |

## Deferred Scope

- Rolling upgrade health probes or Application Health extension
- VMSS extensions and application bootstrap
- Custom images from Shared Image Gallery or managed image IDs
- Ephemeral OS disks
- Disk Encryption Sets and customer-managed keys
- Automatic repair policies

These can be added without changing the core OS/image/disk contract, but each requires its own lifecycle, health, or platform-capability design.
