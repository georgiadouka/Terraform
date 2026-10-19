# VMSS Module Design Research

**Date**: 2026-10-18

## Decision 1: Use OS-specific AzureRM resources

**Decision**: Implement `azurerm_linux_virtual_machine_scale_set` and `azurerm_windows_virtual_machine_scale_set`, selecting exactly one from a validated `os_type`.

**Rationale**:

- The resources expose the correct OS-specific authentication and configuration contracts.
- This mirrors the repository's existing standalone VM module.
- It avoids the deprecated generic VMSS resource and unsafe loosely typed branching.

**Alternatives considered**:

- Generic VMSS resource: rejected because it is legacy and provides a weaker contract.
- Linux-only first version: rejected because the repository already supports both operating systems and the user asked to select the OS.

## Decision 2: Model OS release and image build with a complete Marketplace reference

**Decision**: Expose `source_image_reference = { publisher, offer, sku, version }`, with OS-specific defaults.

**Rationale**:

- Azure Marketplace does not represent an operating system with one reliable `os_version` string.
- `publisher`, `offer`, and especially `sku` identify the OS distribution/release; `version` identifies the image build and can be pinned or set to `latest`.
- A complete reference supports Ubuntu, Windows Server, and other compatible Marketplace images without maintaining a brittle lookup table in Terraform.

**Alternatives considered**:

- Friendly `os_name` and `os_version` lookup map: rejected because it would require continuous maintenance and artificially restrict supported images.
- Free-form image URN string: rejected because a typed object supports clearer validation and matches the AzureRM schema.
- Shared Image Gallery in version one: deferred because it requires a separate image-ID contract and mutually exclusive validation.

## Decision 3: Use inline data-disk templates keyed by stable labels

**Decision**: Accept `data_disks` as a map of objects and render one dynamic `data_disk` block per entry in both OS-specific resources.

**Rationale**:

- VMSS disks are part of the instance model; every configured disk is created for every instance.
- Stable map keys make plans deterministic and let callers add multiple disks without positional list churn.
- Inline disks are the native VMSS model. Standalone managed disk attachments are appropriate for individual VMs, not a homogeneous scale set.
- An empty map keeps the reusable module valid for workloads that need only an OS disk, while one or many entries satisfy the requested deployment model.

**Alternatives considered**:

- List of disk objects: rejected because reordering can create unnecessary diffs and labels improve readability.
- Standalone `azurerm_managed_disk` resources: rejected because individual disk attachment conflicts with scale-set instance templating.
- Require at least one data disk: rejected because it would unnecessarily limit module reuse; the lab example will demonstrate multiple disks.

## Decision 4: Let Azure Monitor own capacity in every mode

**Decision**: Always create an Azure Monitor autoscale setting. Fixed mode uses equal minimum, default, and maximum capacity with no dynamic rules; autoscale mode adds CPU scale-out and scale-in rules. The VMSS seeds its initial capacity from the profile default and ignores later `instances` drift.

**Rationale**:

- Terraform and Azure Monitor must not both own scale-set capacity.
- One owner avoids plans that attempt to reverse legitimate scale-out or scale-in activity.
- Using the same owner in fixed and autoscale modes avoids conditional Terraform lifecycle behavior, which cannot be driven dynamically by a variable.
- Environment owners can switch modes without changing the VMSS resource address or recreating the scale set.

**Alternatives considered**:

- Terraform-owned fixed capacity and Azure Monitor-owned autoscale capacity: rejected because `ignore_changes` cannot be conditional and the two modes would need duplicated VMSS resources.
- Optional autoscale without ignoring `instances`: rejected because each Terraform apply could reset the capacity selected by Azure Monitor.
- Separate fixed and autoscaled VMSS modules: rejected because their large duplicated OS-specific resources would be difficult to maintain consistently.

## Decision 5: Default upgrade mode to Manual

**Decision**: Expose `upgrade_mode` but default it to `Manual`.

**Rationale**:

- Safe rolling upgrades require a health probe or application-health extension and a rolling policy.
- An application-agnostic infrastructure module cannot invent a meaningful health signal.
- `Manual` avoids claiming health-aware rollout behavior. The documentation must state that model changes require an instance upgrade action.

**Alternatives considered**:

- `Automatic`: rejected as the default because it can update instances without workload-aware health validation.
- `Rolling`: deferred until the module has an explicit health contract and rolling policy.

## Decision 6: Reuse the VM subnet and NAT Gateway

**Decision**: Place the VMSS in the existing `virtual_machines` subnet and retain the shared NAT Gateway whenever the standalone VM, VMSS, or Container Apps requires it.

**Rationale**:

- Both compute types have the same private outbound-connectivity requirement.
- A separate subnet is not required for the current security or routing model.
- One NAT association per subnet avoids conflicting resources and duplicate cost.

**Alternatives considered**:

- Dedicated VMSS subnet: deferred until the scale set needs different NSGs, routes, address planning, or lifecycle isolation.
- Public instance IPs: rejected because the repository is private by default.

## Decision 7: Build a focused local module and use AVM as a reference

**Decision**: Add a repository-native module while using Azure Verified Module `avm-res-compute-virtualmachinescaleset` 0.11.1 as a design reference.

**Rationale**:

- The repository consistently owns small, focused local modules.
- A thin contract is easier for environment owners to understand and validate.
- Directly adopting the broad AVM interface would be a larger architectural change than the requested feature.

**Alternatives considered**:

- Direct AVM dependency: not selected for this iteration; reconsider if the repository adopts AVM broadly or needs advanced VMSS features.

## References

- [AzureRM Linux Virtual Machine Scale Set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set)
- [AzureRM Windows Virtual Machine Scale Set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set)
- [AzureRM Monitor Autoscale Setting](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting)
- [Azure Verified VMSS module](https://github.com/Azure/terraform-azurerm-avm-res-compute-virtualmachinescaleset)
- [HashiCorp Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
